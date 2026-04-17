$ErrorActionPreference = "Stop"

$PROJECT_DIR = "C:\Users\DeivyRafaelPatinoUga\anaconda3\Atalaya\Mobile"
$API_IP      = "192.168.159.36"
$API_PORT    = 8010
$DEVICE_ID   = "R5CY12BRYRM"
$ADB_EXE     = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

Write-Host "[INFO] Inicio v4-min" -ForegroundColor Cyan
Set-Location $PROJECT_DIR

# 1) Backend (si no responde, lo levanta)
function Test-Url($u){
  try { (Invoke-RestMethod -Uri $u -TimeoutSec 4).status -eq "ok" } catch { $false }
}

$okLan = Test-Url "http://${API_IP}:${API_PORT}/health"
$okDb  = Test-Url "http://${API_IP}:${API_PORT}/health/db"

if(-not ($okLan -and $okDb)){
  Write-Host "[INFO] Levantando backend..." -ForegroundColor Cyan
  $cmd = "cd /d `"$PROJECT_DIR`" && python -m uvicorn app.main:app --app-dir backend_fastapi --host 0.0.0.0 --port $API_PORT"
  Start-Process cmd.exe -ArgumentList "/k $cmd" | Out-Null

  $ready = $false
  for($i=1; $i -le 20; $i++){
    Start-Sleep -Seconds 2
    $okLan = Test-Url "http://${API_IP}:${API_PORT}/health"
    $okDb  = Test-Url "http://${API_IP}:${API_PORT}/health/db"
    if($okLan -and $okDb){ $ready = $true; break }
  }
  if(-not $ready){ throw "Backend no quedó listo en LAN/DB." }
}
Write-Host "[OK] Backend LAN/DB OK" -ForegroundColor Green

# 2) ADB
& $ADB_EXE kill-server | Out-Null
Start-Sleep -Milliseconds 500
& $ADB_EXE start-server | Out-Null
Start-Sleep -Milliseconds 700

$adb = (& $ADB_EXE devices | Out-String)
$line = ($adb -split "`r?`n" | Where-Object {$_ -match [regex]::Escape($DEVICE_ID)} | Select-Object -First 1)

if(-not $line){ throw "No aparece dispositivo $DEVICE_ID en adb devices." }
if($line -match "unauthorized"){
  throw "Dispositivo unauthorized. Acepta popup RSA en el teléfono y vuelve a ejecutar."
}
if(-not ($line -match "device")){
  throw "Estado ADB inesperado: $line"
}
Write-Host "[OK] ADB autorizado: $line" -ForegroundColor Green

# 3) Flutter
flutter clean
flutter pub get
flutter run -d $DEVICE_ID --dart-define=ATALAYA_USE_MOCK=false --dart-define=ATALAYA_API_BASE_URL="http://${API_IP}:${API_PORT}"
