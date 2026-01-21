# Script de téléchargement et installation de Flutter SDK
# Pas besoin de droits administrateur pour télécharger

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   TÉLÉCHARGEMENT DE FLUTTER SDK" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"
$downloadPath = "$env:USERPROFILE\Downloads\flutter_windows.zip"
$extractPath = "C:\flutter"

Write-Host "[1/3] Téléchargement de Flutter SDK..." -ForegroundColor Yellow
Write-Host "  URL: $flutterUrl" -ForegroundColor Gray
Write-Host "  Destination: $downloadPath" -ForegroundColor Gray
Write-Host "  Taille: ~1 GB (cela peut prendre 5-10 minutes)" -ForegroundColor Gray
Write-Host ""

try {
    # Télécharger avec barre de progression
    $ProgressPreference = 'Continue'
    Invoke-WebRequest -Uri $flutterUrl -OutFile $downloadPath -UseBasicParsing
    Write-Host "  ✓ Téléchargement terminé!" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Erreur lors du téléchargement: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Solutions alternatives:" -ForegroundColor Yellow
    Write-Host "1. Téléchargez manuellement depuis:" -ForegroundColor White
    Write-Host "   $flutterUrl" -ForegroundColor Cyan
    Write-Host "2. Sauvegardez dans: $downloadPath" -ForegroundColor White
    Write-Host "3. Relancez ce script" -ForegroundColor White
    pause
    exit 1
}

Write-Host ""
Write-Host "[2/3] Extraction de Flutter..." -ForegroundColor Yellow

# Vérifier si le dossier existe déjà
if (Test-Path $extractPath) {
    Write-Host "  Le dossier C:\flutter existe déjà." -ForegroundColor Yellow
    Write-Host "  Voulez-vous le supprimer et réinstaller? (O/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq "O" -or $response -eq "o") {
        try {
            Remove-Item -Path $extractPath -Recurse -Force -ErrorAction Stop
            Write-Host "  ✓ Ancien dossier supprimé" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ Impossible de supprimer. Utilisez les droits admin ou choisissez un autre emplacement." -ForegroundColor Red
            pause
            exit 1
        }
    }
    else {
        Write-Host "  Installation annulée." -ForegroundColor Yellow
        pause
        exit 0
    }
}

try {
    Write-Host "  Extraction en cours..." -ForegroundColor Gray
    Expand-Archive -Path $downloadPath -DestinationPath "C:\" -Force
    Write-Host "  ✓ Extraction terminée!" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Erreur lors de l'extraction: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Solution:" -ForegroundColor Yellow
    Write-Host "1. Extrayez manuellement le fichier:" -ForegroundColor White
    Write-Host "   $downloadPath" -ForegroundColor Cyan
    Write-Host "2. Dans le dossier: C:\" -ForegroundColor White
    pause
    exit 1
}

Write-Host ""
Write-Host "[3/3] Configuration du PATH..." -ForegroundColor Yellow

$flutterBin = "C:\flutter\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($userPath -notlike "*$flutterBin*") {
    try {
        # Ajouter au PATH utilisateur (pas besoin de droits admin)
        [Environment]::SetEnvironmentVariable(
            "Path",
            "$userPath;$flutterBin",
            "User"
        )
        Write-Host "  ✓ Flutter ajouté au PATH utilisateur" -ForegroundColor Green
        
        # Mettre à jour la session actuelle
        $env:Path = "$env:Path;$flutterBin"
    }
    catch {
        Write-Host "  ⚠ Impossible d'ajouter au PATH automatiquement" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Ajoutez manuellement au PATH:" -ForegroundColor Yellow
        Write-Host "1. Win + R -> sysdm.cpl" -ForegroundColor White
        Write-Host "2. Avancé -> Variables d'environnement" -ForegroundColor White
        Write-Host "3. Variables utilisateur -> Path -> Modifier" -ForegroundColor White
        Write-Host "4. Nouveau -> C:\flutter\bin" -ForegroundColor Cyan
    }
}
else {
    Write-Host "  ✓ Flutter est déjà dans le PATH" -ForegroundColor Green
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   INSTALLATION TERMINÉE!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Prochaines étapes:" -ForegroundColor Yellow
Write-Host "1. Fermez et rouvrez PowerShell/VS Code" -ForegroundColor White
Write-Host "2. Exécutez: flutter doctor" -ForegroundColor Cyan
Write-Host "3. Lancez l'app: flutter run -d chrome" -ForegroundColor Cyan
Write-Host ""
Write-Host "Emplacement de Flutter: C:\flutter" -ForegroundColor Gray
Write-Host "Fichier téléchargé: $downloadPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Appuyez sur une touche pour continuer..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
