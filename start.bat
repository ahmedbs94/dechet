@echo off
title EcoRewind - Lancement complet
echo.
echo  ========================================
echo    EcoRewind - Demarrage en cours...
echo  ========================================
echo.

:: Verifier que DATABASE_URL est defini (PostgreSQL obligatoire)
if "%DATABASE_URL%"=="" (
    echo [DB] Chargement de backend\.env...
)

:: Lancer le backend avec le venv Python (qui a alembic + psycopg2)
echo [1/2] Demarrage du backend (venv Python)...
start "EcoRewind Backend" cmd /c "cd backend && .\venv\Scripts\python.exe -m uvicorn main:app --reload --reload-exclude uploads --host 0.0.0.0 --port 8000"

:: Attendre 3 secondes que le backend demarre
timeout /t 3 /nobreak >nul

:: Lancer Flutter
echo [2/2] Demarrage de Flutter (Chrome)...
flutter run -d chrome
