@echo off
echo ================================================
echo    INSTALLATION DE FLUTTER POUR TRIDECHET
echo ================================================
echo.
echo Ce script va installer Flutter SDK automatiquement.
echo.
echo IMPORTANT: Ce script doit etre execute en tant qu'administrateur!
echo.
echo Appuyez sur une touche pour continuer ou fermez cette fenetre pour annuler...
pause >nul

echo.
echo Lancement de l'installation...
echo.

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0installer_flutter.ps1'"

if errorlevel 1 (
    echo.
    echo ERREUR: L'installation a echoue.
    echo.
    echo Solutions possibles:
    echo 1. Executez ce script en tant qu'administrateur
    echo 2. Verifiez votre connexion Internet
    echo 3. Desactivez temporairement votre antivirus
    echo.
    pause
    exit /b 1
)

echo.
echo Installation terminee avec succes!
echo.
pause
