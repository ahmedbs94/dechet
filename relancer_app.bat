@echo off
echo ================================================
echo    REPARATION ET RELANCE DE L'APPLICATION
echo ================================================
echo.

echo [1/4] Nettoyage du projet...
call flutter clean
if errorlevel 1 (
    echo ERREUR: Flutter n'est pas dans le PATH
    echo.
    echo SOLUTION: Ouvrez VS Code, puis:
    echo 1. Appuyez sur Ctrl+Shift+P
    echo 2. Tapez "Flutter: Run Flutter Doctor"
    echo 3. Puis utilisez "Flutter: Run" ou F5
    pause
    exit /b 1
)

echo.
echo [2/4] Installation des packages...
call flutter pub get

echo.
echo [3/4] Generation des fichiers...
call flutter pub run build_runner build --delete-conflicting-outputs

echo.
echo [4/4] Lancement de l'application...
call flutter run -d chrome

pause
