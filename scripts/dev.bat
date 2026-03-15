@echo off
:: ============================================
:: Script de lancement - Environnement de dev
:: TriDechet - Backend + Flutter
:: ============================================

echo.
echo    TriDechet - Demarrage du serveur
echo    ================================
echo.

:: Ouvre le backend dans une nouvelle fenetre
start "API Backend" cmd /k "cd /d %~dp0..\backend && venv\Scripts\activate && python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000"

:: Pause de 3 secondes pour laisser le backend demarrer
echo    [1/2] Backend en cours de demarrage...
timeout /t 3 /nobreak > nul

:: Lance l'application Flutter
echo    [2/2] Lancement de l'application Flutter...
echo.
echo    Choisissez votre cible:
echo    1 - Chrome (web)
echo    2 - Android (emulateur ou appareil connecte)
echo    3 - Lister les appareils disponibles
echo.
set /p choice="    Votre choix (1/2/3): "

cd /d %~dp0..

if "%choice%"=="1" (
    flutter run -d chrome
) else if "%choice%"=="2" (
    flutter run
) else if "%choice%"=="3" (
    flutter devices
    echo.
    set /p device_id="    Entrez l'ID de l'appareil: "
    flutter run -d %device_id%
) else (
    echo    Choix invalide. Lancement sur Chrome par defaut.
    flutter run -d chrome
)

echo.
echo    Fermeture complete.
pause
