@echo off
chcp 65001 >nul
title EcoRewind - Lancer App + Miroir

set SCRCPY_DIR=%~dp0scrcpy\scrcpy-win64-v3.3.4
set ADB=%SCRCPY_DIR%\adb.exe
set SCRCPY=%SCRCPY_DIR%\scrcpy.exe
set APK=%~dp0build\app\outputs\flutter-apk\app-debug.apk
set PACKAGE=com.example.eco_rewind

echo.
echo  ============================================================
echo    EcoRewind - Lancement App Android + Miroir scrcpy
echo  ============================================================
echo.

:: ── 1. Vérifier qu'un téléphone est connecté ──────────────────────────────
echo [1/5] Vérification du téléphone connecté...
"%ADB%" devices | findstr /v "List of devices" | findstr "device" >nul
if errorlevel 1 (
    echo.
    echo  ╔══════════════════════════════════════════════════════╗
    echo  ║  ERREUR : Aucun téléphone détecté !                  ║
    echo  ║                                                       ║
    echo  ║  Vérifiez que :                                       ║
    echo  ║   1. Le câble USB est bien branché                    ║
    echo  ║   2. Le débogage USB est activé                       ║
    echo  ║   3. Vous avez accepté "Autoriser le débogage USB"    ║
    echo  ╚══════════════════════════════════════════════════════╝
    echo.
    pause
    exit /b 1
)
echo     OK - Téléphone détecté.

:: ── 1b. ADB Reverse : tunneliser le port 8000 vers le PC ─────────────────
echo.
echo [1b] Configuration du tunnel USB (adb reverse)...
"%ADB%" reverse tcp:8000 tcp:8000
echo     OK - Tunnel actif : telephone:127.0.0.1:8000 → PC:8000

:: ── 2. Démarrer le backend FastAPI ────────────────────────────────────────
echo.
echo [2/5] Démarrage du backend FastAPI...
start "EcoRewind Backend" cmd /k "cd /d "%~dp0backend" && python -m uvicorn main:app --reload --reload-exclude uploads --host 0.0.0.0 --port 8000"
timeout /t 3 /nobreak >nul
echo     OK - Backend démarré sur port 8000.

:: ── 3. Installer l'APK sur le téléphone ──────────────────────────────────
echo.
echo [3/5] Installation de l'APK sur le téléphone...
if not exist "%APK%" (
    echo     APK introuvable. Construction en cours...
    call flutter build apk --debug
    if errorlevel 1 (
        echo  ERREUR: Impossible de builder l'APK. Vérifiez Flutter.
        pause
        exit /b 1
    )
)
"%ADB%" install -r "%APK%"
if errorlevel 1 (
    echo.
    echo  ERREUR: Installation de l'APK échouée.
    echo  Essayez de désinstaller l'app manuellement sur le téléphone.
    pause
    exit /b 1
)
echo     OK - APK installé.

:: ── 4. Lancer l'application sur le téléphone ─────────────────────────────
echo.
echo [4/5] Lancement de l'application...
"%ADB%" shell monkey -p %PACKAGE% -c android.intent.category.LAUNCHER 1 >nul 2>&1
timeout /t 2 /nobreak >nul
echo     OK - Application lancée.

:: ── 5. Lancer scrcpy (miroir de l'écran) ─────────────────────────────────
echo.
echo [5/5] Ouverture du miroir scrcpy...
echo.
echo  ============================================================
echo    Miroir actif - Fermez cette fenêtre pour arrêter
echo  ============================================================
echo.
"%SCRCPY%" --window-title "EcoRewind - Miroir" --stay-awake --turn-screen-off --max-fps 60 --video-bit-rate 8M
