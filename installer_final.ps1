$zipPath = "$env:USERPROFILE\Downloads\flutter_windows.zip"
$destPath = "$env:USERPROFILE\flutter_sdk"

Write-Host "Vérification du fichier zip..."
if (-not (Test-Path $zipPath)) {
    Write-Error "Fichier zip non trouvé à $zipPath"
    exit 1
}

if (-not (Test-Path $destPath)) {
    New-Item -ItemType Directory -Path $destPath -Force
}

Write-Host "Extraction de Flutter vers $destPath..."
try {
    # On extrait vers le dossier utilisateur pour éviter les problèmes de permissions
    Expand-Archive -Path $zipPath -DestinationPath $destPath -Force
    Write-Host "Extraction terminée avec succès."
}
catch {
    Write-Error "Échec de l'extraction : $_"
    exit 1
}

# Le zip contient généralement un dossier "flutter". On cherche le bin.
$flutterRoot = Get-ChildItem -Path $destPath -Filter "flutter" -Directory | Select-Object -First 1
if ($null -eq $flutterRoot) {
    # Si le zip a été extrait à plat
    $flutterRootPath = $destPath
}
else {
    $flutterRootPath = $flutterRoot.FullName
}

Write-Host "Configuration du PATH..."
$flutterBin = Join-Path $flutterRootPath "bin"
if (Test-Path $flutterBin) {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$flutterBin*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$flutterBin", "User")
        Write-Host "Flutter ajouté au PATH utilisateur ($flutterBin)."
    }
    else {
        Write-Host "Flutter est déjà dans le PATH."
    }
}
else {
    Write-Warning "Le dossier bin n'a pas été trouvé à $flutterBin."
}

Write-Host "Exécution de flutter doctor..."
$flutterBat = Join-Path $flutterBin "flutter.bat"
& $flutterBat doctor
