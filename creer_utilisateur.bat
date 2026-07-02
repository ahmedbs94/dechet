@echo off
chcp 65001 > nul
echo.
echo ========================================
echo    CRÉATION D'UTILISATEUR - TriDéchet
echo ========================================
echo.

cd backend
call venv\Scripts\activate.bat
python scripts\utils\manage_users.py
cd ..

echo.
echo ========================================
echo    Terminé !
echo ========================================
echo.
pause
