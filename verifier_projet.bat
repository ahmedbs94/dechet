@echo off
echo ================================================
echo    VERIFICATION DU CODE TRIDECHET
echo ================================================
echo.

REM Verifier si Flutter est disponible
where flutter >nul 2>nul
if errorlevel 1 (
    echo [ERREUR] Flutter n'est pas installe ou n'est pas dans le PATH
    echo.
    echo SOLUTION:
    echo 1. Executez 'installer_flutter.bat' en tant qu'administrateur
    echo 2. OU installez Flutter manuellement depuis https://flutter.dev
    echo 3. OU utilisez VS Code avec l'extension Flutter
    echo.
    echo Pour plus d'informations, consultez GUIDE_RESOLUTION.md
    pause
    exit /b 1
)

echo [OK] Flutter est installe
echo.

echo Verification de la version de Flutter...
flutter --version
echo.

echo ================================================
echo    ANALYSE DU PROJET
echo ================================================
echo.

echo [1/4] Nettoyage du projet...
call flutter clean
echo.

echo [2/4] Verification des dependances...
call flutter pub get
if errorlevel 1 (
    echo.
    echo [ERREUR] Impossible de recuperer les dependances
    echo Verifiez votre connexion Internet
    pause
    exit /b 1
)
echo.

echo [3/4] Analyse statique du code...
call flutter analyze
echo.

echo [4/4] Verification de la configuration...
call flutter doctor
echo.

echo ================================================
echo    VERIFICATION TERMINEE
echo ================================================
echo.
echo Si aucune erreur n'est affichee ci-dessus, vous pouvez:
echo 1. Lancer l'application avec: flutter run -d chrome
echo 2. OU utiliser le script: relancer_app.bat
echo 3. OU appuyer sur F5 dans VS Code
echo.
pause
