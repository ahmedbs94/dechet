@echo off
setlocal enabledelayedexpansion
title EcoRewind - Lancement Complet

set "ADB=C:\Users\lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe"
set "SCRCPY=%~dp0scrcpy-win64-v3.3.4\scrcpy.exe"
set "PROJECT=C:\Users\lenovo\Desktop\EcoRewind"

echo.
echo =====================================================
echo   ECOREWIND - LANCEMENT COMPLET
echo   Backend + Tunnel ADB + Flutter + Miroir
echo =====================================================
echo.

REM === Etape 1 : Detection du telephone ===
echo [1/5] Recherche du telephone USB...
"%ADB%" start-server >nul 2>&1
timeout /t 2 /nobreak >nul

set "DEVICE="
for /f "skip=1 tokens=1" %%d in ('"%ADB%" devices 2^>nul') do (
    set "LINE=%%d"
    if not "!LINE!"=="" (
        echo !LINE! | findstr /i "emulator" >nul
        if errorlevel 1 (
            set "DEVICE=!LINE!"
        )
    )
)

if "!DEVICE!"=="" (
    echo.
    echo  ERREUR : Aucun telephone detecte.
    echo    1. Verifiez le cable USB
    echo    2. Activez le debogage USB
    echo    3. Acceptez l autorisation sur le telephone
    echo.
    pause
    exit /b 1
)
echo  OK - Telephone : !DEVICE!
echo.

REM === Etape 2 : Lancer le backend si pas actif ===
echo [2/5] Verification du backend...
python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/posts?limit=1',timeout=3)" >nul 2>&1
if errorlevel 1 (
    echo  Backend non actif - lancement automatique...
    start "Backend EcoRewind" cmd /k "cd /d %PROJECT%\backend & .\venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000"
    echo  Attente du demarrage du backend...
    
    set "READY=0"
    for /L %%i in (1,1,15) do (
        if !READY!==0 (
            timeout /t 3 /nobreak >nul
            python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/posts?limit=1',timeout=2)" >nul 2>&1
            if not errorlevel 1 set "READY=1"
        )
    )
    
    if !READY!==0 (
        echo  Le backend met du temps a demarrer.
        echo  Appuyez sur une touche quand il affiche Application startup complete
        pause >nul
    ) else (
        echo  OK - Backend demarre
    )
) else (
    echo  OK - Backend deja actif
)
echo.

REM === Etape 3 : Tunnel ADB Reverse ===
echo [3/5] Activation tunnel USB...
"%ADB%" -s !DEVICE! reverse tcp:8000 tcp:8000
if errorlevel 1 (
    echo  ERREUR : Tunnel ADB echoue. Rebranchez le cable et relancez.
    pause
    exit /b 1
)
echo  OK - Tunnel actif
echo.

REM === Etape 4 : Lancer Flutter ===
echo [4/5] Lancement de EcoRewind sur le telephone...
start "Flutter EcoRewind" cmd /k "cd /d %PROJECT% & flutter run -d !DEVICE!"
timeout /t 20 /nobreak >nul

REM === Etape 5 : Miroir scrcpy ===
echo [5/5] Lancement du miroir...
echo.
echo =====================================================
echo   TOUT EST LANCE
echo   Fermez cette fenetre pour arreter le miroir
echo =====================================================
echo.
"%SCRCPY%" -s !DEVICE! --window-title "EcoRewind" --max-size 1080 --stay-awake

echo.
echo Miroir ferme.
pause
endlocal
