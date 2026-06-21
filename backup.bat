@echo off
setlocal EnableExtensions
color 0A
title BACKUP MYSQL AUTOMATICO

:: ==========================================================
:: CONFIGURACOES
:: ==========================================================

set "SERVIDOR=localhost"
set "USUARIO=root"
set "BANCO=seu_schema"
set "SENHA="

set "EMPRESA=MATRIZ"
set "CAIXA=99"

set "BACKUP=C:\DATABASE\BACKUP\ON\"
set "COPIA=\\LOCALHOST\BACKUP\COPIA\"
set "DIAS=7"
set "HORABACKUP=18:00"

:: ==========================================================
:: DATA/HORA
:: ==========================================================

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmm"') do set "DATAHORA=%%i"

set "ARQUIVO=%EMPRESA%-%CAIXA%_%DATAHORA%"
set "SQLFILE=%BACKUP%%ARQUIVO%.sql"
set "RARFILE=%BACKUP%%ARQUIVO%.7z"

:: ==========================================================
:: LOG
:: ==========================================================

set "LOG=%~dp0backup.log"

echo.>>"%LOG%"
echo ==========================================================>>"%LOG%"
echo INICIO DO BACKUP - %DATE% %TIME%>>"%LOG%"
echo ==========================================================>>"%LOG%"

call :Log Banco............... %BANCO%
call :Log Servidor............ %SERVIDOR%
call :Log Destino Backup...... %BACKUP%
call :Log Destino Copia....... %COPIA%

:: ==========================================================
:: VALIDA PASTA BACKUP
:: ==========================================================

call :Titulo VALIDA PASTA BACKUP

call :VerificaPasta "%BACKUP%"

:: ==========================================================
:: VALIDA MYSQLDUMP
:: ==========================================================

call :Titulo VALIDANDO MYSQLDUMP

where mysqldump >nul 2>&1

if errorlevel 1 (
    call :Log ERRO: mysqldump.exe nao encontrado no PATH.
    goto FIM_ERRO
)

call :Log mysqldump localizado.

:: ==========================================================
:: EXECUTA DUMP
:: ==========================================================

call :Titulo EXTRAINDO BACKUP

set "TMPERR=%TEMP%\mysqldump_%RANDOM%.log"

call :Log Iniciando dump...

if "%SENHA%"=="" (
    mysqldump -u %USUARIO% -h %SERVIDOR% %BANCO% --routines --triggers --events > "%SQLFILE%" 2>"%TMPERR%"
) else (
    mysqldump -u %USUARIO% -p%SENHA% -h %SERVIDOR% %BANCO% --routines --triggers --events > "%SQLFILE%" 2>"%TMPERR%"
)

set "RET=%ERRORLEVEL%"

if not "%RET%"=="0" (
    call :Log ERRO NO MYSQLDUMP:
    type "%TMPERR%" >> "%LOG%"
    goto FIM_ERRO
)

if not exist "%SQLFILE%" (
    call :Log ERRO: Arquivo SQL nao foi criado.
    goto FIM_ERRO
)

for %%A in ("%SQLFILE%") do set "SQLSIZE=%%~zA"

if "%SQLSIZE%"=="0" (
    call :Log ERRO: Arquivo SQL vazio.
    goto FIM_ERRO
)

call :Log Arquivo SQL criado.
call :Log Tamanho SQL......... %SQLSIZE% bytes

:: ==========================================================
:: COMPACTACAO
:: ==========================================================

call :Titulo COMPACTANDO ARQUIVO

where 7z >nul 2>&1

if errorlevel 1 (
    call :Log ERRO: 7z.exe nao encontrado.
    goto FIM_ERRO
)

7z a -t7z "%RARFILE%" "%SQLFILE%" -sdel >nul 2>&1

if not exist "%RARFILE%" (
    call :Log ERRO: Falha ao compactar.
    goto FIM_ERRO
)

for %%A in ("%RARFILE%") do set "RARSIZE=%%~zA"

call :Log Compactacao concluida.
call :Log Tamanho Compactado.. %RARSIZE% bytes

:: ==========================================================
:: COPIA PARA REDE
:: ==========================================================

call :Titulo VALIDANDO DESTINO DE COPIA

call :VerificaPasta "%COPIA%"

call :Titulo COPIANDO PARA REDE

copy "%RARFILE%" "%COPIA%" /Y >nul

if errorlevel 1 (
    call :Log AVISO: Falha ao copiar para rede.
) else (
    call :Log Copia realizada com sucesso.
)

:: ==========================================================
:: LIMPEZA
:: ==========================================================

call :Titulo REMOVENDO BACKUPS ANTIGOS

forfiles /P "%BACKUP%" /M *.7z /D -%DIAS% /C "cmd /c del /q @path" >nul 2>&1

if exist "%COPIA%" (
    forfiles /P "%COPIA%" /M *.7z /D -%DIAS% /C "cmd /c del /q @path" >nul 2>&1
)

call :Log Limpeza concluida.

:: ==========================================================
:: CRIA TAREFA AGENDADA SE NAO EXISTIR
:: ==========================================================

call :Titulo VALIDANDO AGENDAMENTO

set "NOME_TAREFA=%~n0"

schtasks /Query /TN "%NOME_TAREFA%" >nul 2>&1

if errorlevel 1 (
    call :Log Tarefa nao encontrada. Criando agendamento...

    schtasks /Create ^
        /TN "%NOME_TAREFA%" ^
        /TR "\"%~f0\"" ^
        /SC DAILY ^
        /ST %HORABACKUP% ^
        /RL HIGHEST ^
        /F >nul 2>&1

    if errorlevel 1 (
        call :Log ERRO: Falha ao criar tarefa agendada.
    ) else (
        call :Log Tarefa criada com sucesso.
        call :Log Nome............... %NOME_TAREFA%
        call :Log Horario............ 17:30
    )
) else (
    call :Log Tarefa ja existente: %NOME_TAREFA%
)

goto FIM_OK

:: ==========================================================
:: FUNCOES
:: ==========================================================

:Titulo
color 0A
timeout /t 3 >nul
cls


echo.
echo ==========================================================
echo %*
echo ==========================================================
echo.

call :Log ==========================================================
call :Log %*
call :Log ==========================================================

goto :eof

:VerificaPasta

if exist "%~1" (
    call :Log Pasta encontrada: %~1
) else (
    call :Log Pasta inexistente: %~1
    call :Log Tentando criar...

    mkdir "%~1" >> "%LOG%" 2>&1

    if exist "%~1" (
        call :Log Pasta criada com sucesso.
    ) else (
        call :Log ERRO: Nao foi possivel criar a pasta.
    )
)

goto :eof

:Log
echo [%DATE% %TIME%] %*>>"%LOG%"
goto :eof

:FIM_OK

call :Titulo BACKUP FINALIZADO COM SUCESSO

echo Arquivo Gerado:
echo.
echo %RARFILE%
echo.
echo Backup concluido com sucesso.
echo.

call :Log BACKUP FINALIZADO COM SUCESSO.
call :Log ==========================================================

timeout /t 5 >nul
exit /b 0

:FIM_ERRO

cls
color 0C

echo.
echo ==========================================================
echo BACKUP FINALIZADO COM ERRO
echo ==========================================================
echo.
echo Consulte o arquivo de log:
echo %LOG%
echo.

call :Log BACKUP FINALIZADO COM ERRO.
call :Log ==========================================================

if exist "%TMPERR%" del "%TMPERR%" >nul 2>&1

pause
exit /b 1
