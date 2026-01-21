$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"
$output = "$env:USERPROFILE\Downloads\flutter_windows.zip"

Write-Host "Suppression du fichier corrompu s'il existe..."
if (Test-Path $output) {
    Remove-Item -Path $output -Force
}

Write-Host "Téléchargement de Flutter SDK via BITS (plus fiable)..."
try {
    Start-BitsTransfer -Source $url -Destination $output -DisplayName "Flutter SDK Download"
    Write-Host "Téléchargement terminé!"
    
    $fileSize = (Get-Item $output).Length
    Write-Host "Taille du fichier : $([math]::Round($fileSize / 1MB, 2)) MB"
    
    if ($fileSize -lt 500MB) {
        Write-Error "Le fichier semble trop petit ($($fileSize) octets). Le téléchargement a probablement échoué."
        exit 1
    }
}
catch {
    Write-Error "Échec du téléchargement : $_"
    exit 1
}
