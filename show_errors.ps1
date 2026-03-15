$ErrorActionPreference = "Continue"
$output = flutter analyze --no-pub 2>&1 | Out-String
$lines = $output -split "`r?`n"

Write-Host "===== ANALYSE DES ERREURS FLUTTER =====" -ForegroundColor Cyan
Write-Host ""

$errorLines = $lines | Where-Object { $_ -match "warning|info|error" -and $_ -match "lib\\" }
foreach ($line in $errorLines) {
    if ($line -match "(warning|error)") {
        Write-Host $line -ForegroundColor Red
    }
    elseif ($line -match "info") {
        Write-Host $line -ForegroundColor Yellow
    }
    else {
        Write-Host $line
    }
}

Write-Host ""
$summary = $lines | Where-Object { $_ -match "issues found" }
Write-Host $summary -ForegroundColor Cyan
