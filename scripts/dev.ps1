# ============================================
# Script de lancement - Environnement de dev
# ============================================
#
# Utilisation:
#   .\scripts\dev.ps1              -> Lance tout
#   .\scripts\dev.ps1 -BackendOnly -> Backend seulement
#   .\scripts\dev.ps1 -FrontendOnly -> Frontend seulement

param(
    [switch]$BackendOnly,
    [switch]$FrontendOnly
)

# Chemins du projet
$Racine = Split-Path -Parent $PSScriptRoot
$DossierBackend = Join-Path $Racine "backend"

# Demarre le serveur API
function Demarrer-Backend {
    Write-Host "[Backend] Serveur sur http://localhost:8000" -ForegroundColor Yellow
    Push-Location $DossierBackend
    & .\venv\Scripts\python.exe -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
    Pop-Location
}

# Demarre l'application Flutter
function Demarrer-Frontend {
    Write-Host "[Frontend] Lancement de Flutter..." -ForegroundColor Cyan
    Push-Location $Racine
    flutter run -d chrome
    Pop-Location
}

# Logique principale
if ($BackendOnly) {
    Demarrer-Backend
}
elseif ($FrontendOnly) {
    Demarrer-Frontend
}
else {
    # Lance le backend en arriere-plan
    $tache = Start-Job -ScriptBlock {
        param($chemin)
        Set-Location $chemin
        & .\venv\Scripts\python.exe -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
    } -ArgumentList $DossierBackend
    
    Write-Host "[Backend] Demarre en arriere-plan" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    # Lance le frontend
    Demarrer-Frontend
    
    # Arret propre du backend
    Stop-Job $tache -ErrorAction SilentlyContinue
    Remove-Job $tache -ErrorAction SilentlyContinue
}
