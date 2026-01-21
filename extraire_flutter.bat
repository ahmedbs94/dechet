@echo off
echo ================================================
echo    EXTRACTION ET CONFIGURATION DE FLUTTER
echo ================================================
echo.

set "FLUTTER_ZIP=%USERPROFILE%\Downloads\flutter_windows.zip"
set "EXTRACT_PATH=C:\"

echo Verification du fichier telecharge...
if not exist "%FLUTTER_ZIP%" (
    echo ERREUR: Le fichier Flutter n'a pas ete trouve dans:
    echo %FLUTTER_ZIP%
    echo.
    echo Le telechargement est peut-etre encore en cours.
    echo Attendez qu'il se termine, puis relancez ce script.
    pause
    exit /b 1
)

echo ✓ Fichier trouve: %FLUTTER_ZIP%
echo.

echo [1/3] Extraction de Flutter dans C:\flutter...
echo Cela peut prendre 2-3 minutes...
echo.

PowerShell -NoProfile -Command "Expand-Archive -Path '%FLUTTER_ZIP%' -DestinationPath '%EXTRACT_PATH%' -Force"

if errorlevel 1 (
    echo.
    echo ERREUR lors de l'extraction.
    echo.
    echo Solution manuelle:
    echo 1. Ouvrez l'Explorateur de fichiers
    echo 2. Allez dans: %USERPROFILE%\Downloads
    echo 3. Clic droit sur flutter_windows.zip
    echo 4. Selectionnez "Extraire tout..."
    echo 5. Choisissez C:\ comme destination
    pause
    exit /b 1
)

echo ✓ Extraction terminee!
echo.

echo [2/3] Ajout de Flutter au PATH utilisateur...
PowerShell -NoProfile -Command "$path = [Environment]::GetEnvironmentVariable('Path', 'User'); if ($path -notlike '*C:\flutter\bin*') { [Environment]::SetEnvironmentVariable('Path', $path + ';C:\flutter\bin', 'User'); Write-Host '✓ Flutter ajoute au PATH' } else { Write-Host '✓ Flutter deja dans le PATH' }"

echo.
echo [3/3] Verification de l'installation...
echo.

REM Ajouter temporairement au PATH de cette session
set "PATH=%PATH%;C:\flutter\bin"

echo Lancement de flutter doctor...
echo.
call C:\flutter\bin\flutter.bat doctor

echo.
echo ================================================
echo    INSTALLATION TERMINEE!
echo ================================================
echo.
echo Flutter est maintenant installe dans: C:\flutter
echo.
echo IMPORTANT: Fermez et rouvrez VS Code pour qu'il detecte Flutter
echo.
echo Prochaines etapes:
echo 1. Fermez VS Code
echo 2. Rouvrez VS Code
echo 3. Ouvrez le projet TriDechet
echo 4. Appuyez sur F5 pour lancer l'application
echo.
echo OU utilisez la commande:
echo   flutter run -d chrome
echo.
pause
