@echo off
REM migrate.bat — Scripts Alembic pour EcoRewind (Windows)
REM ========================================================
REM Utilisation : migrate.bat [commande]
REM
REM   migrate.bat up          → Appliquer toutes les migrations
REM   migrate.bat down        → Revenir d'une migration en arrière
REM   migrate.bat new "msg"   → Créer une nouvelle migration (autogenerate)
REM   migrate.bat status      → Voir l'état des migrations
REM   migrate.bat history     → Historique complet
REM   migrate.bat reset       → ⚠️  Revenir à zéro (SUPPRIME TOUTES LES TABLES)

setlocal

REM Se placer dans le dossier backend/ (là où se trouve alembic.ini)
cd /d "%~dp0"

IF "%1"=="" GOTO help
IF "%1"=="up" GOTO up
IF "%1"=="down" GOTO down
IF "%1"=="new" GOTO new
IF "%1"=="status" GOTO status
IF "%1"=="history" GOTO history
IF "%1"=="reset" GOTO reset
GOTO help

:up
echo [Alembic] Application de toutes les migrations...
alembic upgrade head
GOTO end

:down
echo [Alembic] Retour d'une migration en arriere...
alembic downgrade -1
GOTO end

:new
IF "%2"=="" (
    echo Usage: migrate.bat new "description de la migration"
    GOTO end
)
echo [Alembic] Creation d'une nouvelle migration : %2
alembic revision --autogenerate -m "%2"
GOTO end

:status
echo [Alembic] Etat actuel des migrations :
alembic current
GOTO end

:history
echo [Alembic] Historique des migrations :
alembic history --verbose
GOTO end

:reset
echo.
echo [ATTENTION] Cette operation va supprimer TOUTES les tables !
echo Appuyez sur Ctrl+C pour annuler, ou Entree pour continuer...
pause
alembic downgrade base
echo [Alembic] Base de donnees reinitialise. Relancez 'migrate.bat up' pour recreer.
GOTO end

:help
echo.
echo  EcoRewind — Gestionnaire de migrations Alembic
echo  ================================================
echo  Usage: migrate.bat [commande]
echo.
echo  Commandes disponibles :
echo    up          Appliquer toutes les migrations (alembic upgrade head)
echo    down        Revenir d'une migration en arriere (alembic downgrade -1)
echo    new "msg"   Creer une nouvelle migration autogeneree
echo    status      Voir la migration courante (alembic current)
echo    history     Historique complet des migrations
echo    reset       Revenir a zero (SUPPRIME toutes les tables !)
echo.
echo  Exemples :
echo    migrate.bat up
echo    migrate.bat new "add_user_phone_column"
echo    migrate.bat status
echo.
GOTO end

:end
endlocal
