@echo off
echo ================================================
echo    OUVERTURE DU PROJET DANS VS CODE
echo ================================================
echo.
echo Ce script va ouvrir le projet dans VS Code.
echo Ensuite, suivez ces etapes simples:
echo.
echo 1. VS Code va s'ouvrir
echo 2. Installez l'extension "Flutter" si demande
echo 3. VS Code detectera automatiquement que Flutter n'est pas installe
echo 4. Cliquez sur "Download SDK" ou "Locate SDK"
echo 5. Laissez VS Code telecharger et configurer Flutter
echo 6. Une fois termine, appuyez sur F5 pour lancer l'app
echo.
echo Appuyez sur une touche pour ouvrir VS Code...
pause >nul

code .

echo.
echo VS Code est maintenant ouvert!
echo.
echo PROCHAINES ETAPES:
echo 1. Attendez que VS Code charge le projet
echo 2. En bas a droite, cliquez sur "Get Packages" si affiche
echo 3. Installez l'extension Flutter (Ctrl+Shift+X, cherchez "Flutter")
echo 4. Suivez les instructions pour installer le SDK Flutter
echo 5. Appuyez sur F5 pour lancer l'application
echo.
pause
