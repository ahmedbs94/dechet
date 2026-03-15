Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   DIAGNOSTIC AUTHENTIFICATION FACEBOOK - TriDechet" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Key Hash Debug
Write-Host "[1/4] Calcul du Key Hash Facebook (Debug Keystore)..." -ForegroundColor Yellow
$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"

if (Test-Path $debugKeystore) {
    $keyHashScript = @"
import sys, hashlib, base64
data = sys.stdin.buffer.read()
sha1 = hashlib.sha1(data).digest()
print(base64.b64encode(sha1).decode())
"@
    $tempScript = [System.IO.Path]::GetTempFileName() + ".py"
    $keyHashScript | Out-File -FilePath $tempScript -Encoding ASCII
    
    $keyHash = keytool -exportcert -alias androiddebugkey -keystore $debugKeystore -storepass android 2>$null | python $tempScript
    $keyHash = $keyHash.Trim()
    
    Write-Host ""
    Write-Host "  KEY HASH DEBUG (a ajouter dans Facebook Developer Console):" -ForegroundColor Green
    Write-Host "  >>> $keyHash <<<" -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host ""
    
    Remove-Item $tempScript -ErrorAction SilentlyContinue
}
else {
    Write-Host "  ATTENTION: Debug keystore introuvable!" -ForegroundColor Red
    Write-Host "  Chemin attendu: $debugKeystore" -ForegroundColor Red
}

# 2. Vérification du backend
Write-Host "[2/4] Vérification du backend FastAPI..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:8000/" -TimeoutSec 3 -ErrorAction Stop
    Write-Host "  Backend: ACTIF (http://127.0.0.1:8000/)" -ForegroundColor Green
    
    # Test endpoint Facebook
    try {
        $testFb = Invoke-WebRequest -Uri "http://127.0.0.1:8000/auth/facebook" -Method POST `
            -ContentType "application/json" `
            -Body '{"access_token": "test"}' `
            -TimeoutSec 5 -ErrorAction Stop
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 401 -or $_.Exception.Response.StatusCode -eq 422) {
            Write-Host "  Endpoint /auth/facebook: DISPONIBLE" -ForegroundColor Green
        }
        else {
            Write-Host "  Endpoint /auth/facebook: INACCESSIBLE ($($_.Exception.Response.StatusCode))" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "  Backend: ARRETE (http://127.0.0.1:8000/)" -ForegroundColor Red
    Write-Host "  Demarrage du backend requis. Executez: scripts\dev.bat" -ForegroundColor Yellow
}

# 3. Vérification configuration Android
Write-Host ""
Write-Host "[3/4] Vérification configuration Android..." -ForegroundColor Yellow

$stringsXml = "$PSScriptRoot\android\app\src\main\res\values\strings.xml"
if (Test-Path $stringsXml) {
    $content = Get-Content $stringsXml -Raw
    
    if ($content -match 'facebook_app_id.*?>(.+?)<') {
        $appId = $matches[1]
        Write-Host "  App ID Facebook: $appId" -ForegroundColor Green
    }
    else {
        Write-Host "  App ID Facebook: MANQUANT!" -ForegroundColor Red
    }
    
    if ($content -match 'fb_login_protocol_scheme.*?>(.+?)<') {
        $scheme = $matches[1]
        Write-Host "  Protocol Scheme: $scheme" -ForegroundColor Green
        
        if ($appId -and $scheme -ne "fb$appId") {
            Write-Host "  ATTENTION: Le scheme devrait etre 'fb$appId' mais c'est '$scheme'" -ForegroundColor Red
        }
    }
    
    if ($content -match 'facebook_client_token.*?>(.+?)<') {
        Write-Host "  Client Token: PRESENT" -ForegroundColor Green
    }
    else {
        Write-Host "  Client Token: MANQUANT!" -ForegroundColor Red
    }
}
else {
    Write-Host "  strings.xml INTROUVABLE!" -ForegroundColor Red
}

# 4. Instructions
Write-Host ""
Write-Host "[4/4] Instructions pour réparer Facebook Auth..." -ForegroundColor Yellow
Write-Host ""
Write-Host "  ETAPES OBLIGATOIRES:" -ForegroundColor White
Write-Host "  1. Allez sur: https://developers.facebook.com/apps/1420513346522756/settings/basic/" -ForegroundColor Cyan
Write-Host "  2. Section 'Plateforme Android', ajoutez le Key Hash ci-dessus" -ForegroundColor Cyan
Write-Host "  3. Assurez-vous que le Hash Store OAuth est ACTIVE" -ForegroundColor Cyan
Write-Host "  4. Verifiez que votre compte Facebook est dans la liste des testeurs:" -ForegroundColor Cyan
Write-Host "     https://developers.facebook.com/apps/1420513346522756/roles/test-users/" -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   KEY HASH A COPIER: $keyHash" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
