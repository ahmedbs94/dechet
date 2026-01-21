# Script d'installation automatique de Flutter pour Windows
# Exécutez ce script en tant qu'administrateur

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   INSTALLATION AUTOMATIQUE DE FLUTTER SDK" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier si Flutter est déjà installé
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue

if ($flutterPath) {
    Write-Host "✓ Flutter est déjà installé!" -ForegroundColor Green
    Write-Host "  Emplacement: $($flutterPath.Source)" -ForegroundColor Gray
    Write-Host ""
    flutter --version
    Write-Host ""
    Write-Host "Voulez-vous réinstaller Flutter? (O/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -ne "O" -and $response -ne "o") {
        Write-Host "Installation annulée." -ForegroundColor Yellow
        exit 0
    }
}

# Définir le chemin d'installation
$installPath = "C:\flutter"
$flutterZip = "$env:TEMP\flutter_windows.zip"

Write-Host "[1/5] Téléchargement de Flutter SDK..." -ForegroundColor Cyan

# URL de téléchargement Flutter (version stable)
$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"

try {
    # Télécharger Flutter
    Write-Host "  Téléchargement depuis: $flutterUrl" -ForegroundColor Gray
    Invoke-WebRequest -Uri $flutterUrl -OutFile $flutterZip -UseBasicParsing
    Write-Host "  ✓ Téléchargement terminé" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Erreur lors du téléchargement: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2/5] Extraction de Flutter..." -ForegroundColor Cyan

# Supprimer l'ancien dossier s'il existe
if (Test-Path $installPath) {
    Write-Host "  Suppression de l'ancienne installation..." -ForegroundColor Gray
    Remove-Item -Path $installPath -Recurse -Force
}

try {
    # Extraire Flutter
    Expand-Archive -Path $flutterZip -DestinationPath "C:\" -Force
    Write-Host "  ✓ Extraction terminée" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Erreur lors de l'extraction: $_" -ForegroundColor Red
    exit 1
}

# Nettoyer le fichier zip
Remove-Item -Path $flutterZip -Force

Write-Host ""
Write-Host "[3/5] Configuration du PATH système..." -ForegroundColor Cyan

# Ajouter Flutter au PATH
$flutterBinPath = "$installPath\bin"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

if ($currentPath -notlike "*$flutterBinPath*") {
    try {
        [Environment]::SetEnvironmentVariable(
            "Path",
            "$currentPath;$flutterBinPath",
            "Machine"
        )
        Write-Host "  ✓ Flutter ajouté au PATH système" -ForegroundColor Green
        
        # Mettre à jour le PATH de la session actuelle
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine")
    } catch {
        Write-Host "  ✗ Erreur lors de la configuration du PATH: $_" -ForegroundColor Red
        Write-Host "  Veuillez ajouter manuellement $flutterBinPath au PATH" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✓ Flutter est déjà dans le PATH" -ForegroundColor Green
}

Write-Host ""
Write-Host "[4/5] Vérification de l'installation..." -ForegroundColor Cyan

# Rafraîchir les variables d'environnement
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine")

# Vérifier que Flutter fonctionne
try {
    & "$flutterBinPath\flutter.bat" --version
    Write-Host "  ✓ Flutter installé avec succès!" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Erreur lors de la vérification: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[5/5] Exécution de Flutter Doctor..." -ForegroundColor Cyan
Write-Host ""

& "$flutterBinPath\flutter.bat" doctor

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   INSTALLATION TERMINÉE!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Prochaines étapes:" -ForegroundColor Yellow
Write-Host "1. Fermez et rouvrez PowerShell/Terminal" -ForegroundColor White
Write-Host "2. Exécutez 'flutter doctor' pour vérifier les dépendances" -ForegroundColor White
Write-Host "3. Installez les composants manquants (Android Studio, Chrome, etc.)" -ForegroundColor White
Write-Host "4. Lancez l'application avec 'flutter run -d chrome'" -ForegroundColor White
Write-Host ""
Write-Host "Appuyez sur une touche pour continuer..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
