# Script PowerShell pour créer un utilisateur TriDéchet
# Usage: .\creer_utilisateur.ps1

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   CRÉATION D'UTILISATEUR - TriDéchet" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Vérifier qu'on est dans le bon répertoire
if (!(Test-Path "backend\manage_users.py")) {
    Write-Host "❌ Erreur: Ce script doit être exécuté depuis le dossier TriDéchet" -ForegroundColor Red
    exit 1
}

# Menu de sélection du type de compte
Write-Host " Quel type de compte voulez-vous créer ?`n" -ForegroundColor Yellow

Write-Host "1️  Admin (Administrateur)" -ForegroundColor White
Write-Host "2️  Educator (Éducateur)" -ForegroundColor White
Write-Host "3️  PointManager (Gestionnaire de Points)" -ForegroundColor White
Write-Host "4️  Collector (Collecteur)" -ForegroundColor White
Write-Host "5️  Intercommunality (Mairie/Commune)" -ForegroundColor White
Write-Host "6️  User (Utilisateur Normal)" -ForegroundColor White
Write-Host ""

$choix = Read-Host "Votre choix (1-6)"

$roles = @{
    "1" = "admin"
    "2" = "educator"
    "3" = "pointManager"
    "4" = "collector"
    "5" = "intercommunality"
    "6" = "user"
}

$rolenames = @{
    "1" = "Administrateur"
    "2" = "Éducateur"
    "3" = "Gestionnaire de Points"
    "4" = "Collecteur"
    "5" = "Mairie/Commune"
    "6" = "Utilisateur Normal"
}

if (!$roles.ContainsKey($choix)) {
    Write-Host "`n❌ Choix invalide" -ForegroundColor Red
    exit 1
}

$role = $roles[$choix]
$rolename = $rolenames[$choix]

Write-Host "`n✅ Type sélectionné: $rolename ($role)`n" -ForegroundColor Green

# Collecter les informations
$email = Read-Host "📧 Email"
$fullname = Read-Host "👤 Nom complet"

# Afficher un résumé
Write-Host "`n📝 RÉSUMÉ:" -ForegroundColor Cyan
Write-Host "   Email: $email" -ForegroundColor White
Write-Host "   Nom: $fullname" -ForegroundColor White
Write-Host "   Rôle: $rolename" -ForegroundColor White
Write-Host ""

$confirm = Read-Host "Confirmer la création ? (O/N)"

if ($confirm -ne "O" -and $confirm -ne "o") {
    Write-Host "`n❌ Annulé" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n🚀 Création en cours...`n" -ForegroundColor Cyan

# Se déplacer dans le dossier backend et exécuter le script Python
cd backend

# Créer un fichier temporaire avec les données
$tempFile = ".\temp_user_data.txt"
@"
$email
$fullname
$role
"@ | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline

# Note: Le mot de passe sera demandé de manière sécurisée par le script Python
Write-Host "⚠️  Le script Python va maintenant vous demander le mot de passe de manière sécurisée`n" -ForegroundColor Yellow

# Exécuter le script Python
.\venv\Scripts\python.exe manage_users.py

# Nettoyer
if (Test-Path $tempFile) {
    Remove-Item $tempFile
}

cd ..

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✅ Terminé !" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
