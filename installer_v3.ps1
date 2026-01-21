Add-Type -AssemblyName System.IO.Compression.FileSystem

$zipPath = "$env:USERPROFILE\Downloads\flutter_windows.zip"
$destPath = "$env:USERPROFILE\flutter_dev"

Write-Host "Nettoyage du dossier de destination..."
if (Test-Path $destPath) {
    Remove-Item -Path $destPath -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $destPath -Force

Write-Host "Extraction de Flutter vers $destPath..."
try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $destPath)
    Write-Host "Extraction terminée avec succès."
}
catch {
    Write-Error "Échec de l'extraction : $_"
    exit 1
}

# Recherche du dossier bin
$flutterBin = Get-ChildItem -Path $destPath -Filter "bin" -Recurse | Where-Object { $_.FullName -like "*flutter\bin" } | Select-Object -First 1

if ($null -eq $flutterBin) {
    Write-Warning "Le dossier bin n'a pas été trouvé."
}
else {
    $binPath = $flutterBin.FullName
    Write-Host "Dossier bin trouvé à : $binPath"
    
    Write-Host "Configuration du PATH utilisateur..."
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$binPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$binPath", "User")
        Write-Host "Flutter ajouté au PATH."
    }
    else {
        Write-Host "Flutter est déjà dans le PATH."
    }
    
    Write-Host "Vérification avec flutter --version..."
    $flutterBat = Join-Path $binPath "flutter.bat"
    & $flutterBat --version
}
