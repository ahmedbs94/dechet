@echo off
title EcoRewind - Lancement complet
echo.
echo  ========================================
echo    EcoRewind - Demarrage en cours...
echo  ========================================
echo.

:: Lancer le backend en arriere-plan
echo [1/2] Demarrage du backend...
start "EcoRewind Backend" cmd /c "cd backend && python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000"

:: Attendre 3 secondes que le backend demarre
timeout /t 3 /nobreak >nul

:: Lancer Flutter
echo [2/2] Demarrage de Flutter (Chrome)...
flutter run -d chrome
