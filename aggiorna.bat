@echo off
chcp 65001 > nul
title Aggiorna Gestionale Auto

echo.
echo ============================================
echo   AGGIORNAMENTO GESTIONALE AUTO
echo ============================================
echo.

:: Vai nella cartella del repo (modifica questo percorso se necessario)
cd /d "%~dp0"

:: Verifica che sia un repo git
if not exist ".git" (
    echo ERRORE: Questa cartella non e' un repository Git.
    echo Sposta questo file nella cartella principale del progetto.
    pause
    exit /b 1
)

:: Mostra file modificati
echo File modificati:
git status --short
echo.

:: Chiedi conferma
set /p MSG="Messaggio commit (invio = 'Aggiornamento automatico'): "
if "%MSG%"=="" set MSG=Aggiornamento automatico

:: Aggiorna
echo.
echo [1/3] Aggiungo tutti i file...
git add .

echo [2/3] Creo il commit...
git commit -m "%MSG%"

echo [3/3] Invio a GitHub...
git push origin main

echo.
if %ERRORLEVEL%==0 (
    echo ============================================
    echo   Fatto! Il sito si aggiornera' in ~30sec
    echo   https://pegghiu.github.io/gestionale-auto/
    echo ============================================
) else (
    echo ERRORE durante il push. Controlla la connessione.
)

echo.
pause
