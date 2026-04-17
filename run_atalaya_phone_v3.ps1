# ==========================================
# Atalaya - Phone Run Helper v3 (Interactive)
# ==========================================
$ErrorActionPreference = "Continue"

# ---------- Config editable ----------
$PROJECT_DIR = "C:\Users\DeivyRafaelPatinoUga\anaconda3\Atalaya\Mobile"
$API_IP      = "192.168.159.36"
$API_PORT    = 8010
$DEVICE_ID   = "R5CY12BRYRM"
$ADB_EXE     = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$UVICORN_CMD = "python -m uvicorn app.main:app --app-dir backend_fastapi --host 0.0.0.0 --port $API_PORT"
# -------------------------------------

# ---------- Logging ----------
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$LOG_DIR = Join-Path $PROJECT_DIR "logs"
if (-not (Test-Path $LOG_DIR)) { New-Item -ItemType Directory -Path $LOG_DIR | Out-Null }
$LOG_FILE = Join-Path $LOG_DIR "run_v3_$ts.txt"

function Log {
  param([string]$msg, [string]$color="White")
  $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
  Write-Host $line -ForegroundColor $color
  Add-Content -Path $LOG_FILE -Value $line
}

function Cmd {
  param([string]$cmd)
  Log "CMD> $cmd" "DarkCyan"
  try {
    $out = Invoke-Expression $cmd 2>&1
    if ($out) {
      ($out | Out-String).TrimEnd().Split("`n") | ForEach-Object {
        Add-Content -Path $LOG_FILE -Value $_.TrimEnd()
      }
    }
    return ,$out
  } catch {
    Log "ERROR comando: $($_.Exception.Message)" "Red"
    return $null
  }
}

function Init-Summary {
  return [ordered]@{
    "Paths"         = "PENDING"
    "Port"          = "PENDING"
    "BackendSpawn"  = "PENDING"
    "HealthLocal"   = "PENDING"
    "HealthLan"     = "PENDING"
    "HealthDb"      = "PENDING"
    "AdbPresent"    = "PENDING"
    "AdbDevice"     = "PENDING"
    "FlutterClean"  = "SKIPPED"
    "FlutterPubGet" = "PENDING"
    "FlutterRun"    = "PENDING"
  }
}

function Print-Summary {
  param($summary)
  Log "`n=== RESUMEN ===" "Cyan"
  foreach ($k in $summary.Keys) {
    $v = $summary[$k]
    switch ($v) {
      "PASS"    { Log ("✅ {0}: {1}" -f $k, $v) "Green" }
      "FAIL"    { Log ("❌ {0}: {1}" -f $k, $v) "Red" }
      "SKIPPED" { Log ("⚠️ {0}: {1}" -f $k, $v) "Yellow" }
      default   { Log ("⚠️ {0}: {1}" -f $k, $v) "Yellow" }
    }
  }
  Log "Log: $LOG_FILE" "Gray"
}

function Check-Paths {
  param([hashtable]$summary)

  Log "Pre-check rutas..." "Cyan"
  if (-not (Test-Path $PROJECT_DIR)) {
    Log "❌ PROJECT_DIR no existe: $PROJECT_DIR" "Red"
    $summary["Paths"] = "FAIL"
    return $false
  }
  if (-not (Test-Path (Join-Path $PROJECT_DIR "backend_fastapi"))) {
    Log "❌ Falta backend_fastapi en proyecto." "Red"
    $summary["Paths"] = "FAIL"
    return $false
  }
  if (-not (Test-Path $ADB_EXE)) {
    Log "❌ adb.exe no encontrado en: $ADB_EXE" "Red"
    $summary["Paths"] = "FAIL"
    $summary["AdbPresent"] = "FAIL"
    return $false
  }

  Set-Location $PROJECT_DIR
  $summary["Paths"] = "PASS"
  $summary["AdbPresent"] = "PASS"
  Log "✅ Rutas OK" "Green"
  return $true
}

function Free-Port8010 {
  param([hashtable]$summary)
  Log "Liberando puerto $API_PORT si está ocupado..." "Cyan"
  $netOut = netstat -ano | Select-String ":$API_PORT"
  if ($netOut) {
    $pids = @()
    foreach ($line in $netOut) {
      $parts = ($line.ToString() -replace "\s+", " ").Trim().Split(" ")
      $pid = $parts[-1]
      if ($pid -match "^\d+$") { $pids += $pid }
    }
    $pids = $pids | Select-Object -Unique
    foreach ($pid in $pids) {
      Log "⚠️ Matando PID $pid (usa $API_PORT)" "Yellow"
      Cmd "taskkill /PID $pid /F" | Out-Null
    }
    Start-Sleep -Seconds 1
  }
  $summary["Port"] = "PASS"
  Log "✅ Puerto $API_PORT listo." "Green"
}

function Start-Backend {
  param([hashtable]$summary)
  Log "Levantando backend en nueva ventana..." "Cyan"
  $uvicornWindowCmd = "cd /d `"$PROJECT_DIR`" && $UVICORN_CMD"
  try {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/k $uvicornWindowCmd" | Out-Null
    $summary["BackendSpawn"] = "PASS"
    Log "✅ Backend lanzado." "Green"
    Start-Sleep -Seconds 4
    return $true
  } catch {
    $summary["BackendSpawn"] = "FAIL"
    Log "❌ Error lanzando backend: $($_.Exception.Message)" "Red"
    return $false
  }
}

function Test-OneHealth {
  param([string]$url, [string]$key, [hashtable]$summary)
  Log "Health -> $url" "DarkCyan"
  try {
    $resp = Invoke-RestMethod -Uri $url -TimeoutSec 6
    Add-Content -Path $LOG_FILE -Value ("HEALTH_RESP {0}: {1}" -f $url, ($resp | ConvertTo-Json -Compress))
    if ($resp.status -eq "ok") {
      $summary[$key] = "PASS"
      Log "✅ $url = ok" "Green"
      return $true
    } else {
      $summary[$key] = "FAIL"
      Log "❌ $url respuesta inesperada" "Red"
      return $false
    }
  } catch {
    $summary[$key] = "FAIL"
    Log "❌ $url error: $($_.Exception.Message)" "Red"
    return $false
  }
}

function Check-HealthAll {
  param([hashtable]$summary)
  $h1 = Test-OneHealth "http://127.0.0.1:$API_PORT/health"      "HealthLocal" $summary
  $h2 = Test-OneHealth "http://${API_IP}:${API_PORT}/health"    "HealthLan"   $summary
  $h3 = Test-OneHealth "http://${API_IP}:${API_PORT}/health/db" "HealthDb"    $summary
  return ($h1 -and $h2 -and $h3)
}

function Check-AdbDevice {
  param([hashtable]$summary)
  Log "Chequeando ADB + dispositivo..." "Cyan"
  Cmd "& `"$ADB_EXE`" kill-server" | Out-Null
  Start-Sleep -Milliseconds 500
  Cmd "& `"$ADB_EXE`" start-server" | Out-Null
  Start-Sleep -Milliseconds 500

  $adbOut = Cmd "& `"$ADB_EXE`" devices"
  $txt = ($adbOut | Out-String)

  if (-not ($txt -match [regex]::Escape($DEVICE_ID))) {
    $summary["AdbDevice"] = "FAIL"
    Log "❌ Dispositivo $DEVICE_ID no aparece." "Red"
    return $false
  }

  $line = ($txt -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($DEVICE_ID) } | Select-Object -First 1)

  if ($line -match "unauthorized") {
    $summary["AdbDevice"] = "FAIL"
    Log "⚠️ Dispositivo unauthorized." "Yellow"
    Log "Acción: revocar autorizaciones USB, reconectar, aceptar popup RSA." "Yellow"
    return $false
  }

  if ($line -match "device") {
    $summary["AdbDevice"] = "PASS"
    Log "✅ Dispositivo autorizado: $line" "Green"
    return $true
  }

  $summary["AdbDevice"] = "FAIL"
  Log "❌ Estado ADB inesperado: $line" "Red"
  return $false
}

function Reset-AdbDeep {
  Log "Reset ADB profundo..." "Cyan"
  Cmd "& `"$ADB_EXE`" kill-server" | Out-Null
  Cmd "Remove-Item `"$env:USERPROFILE\.android\adbkey*`" -Force -ErrorAction SilentlyContinue" | Out-Null
  Cmd "& `"$ADB_EXE`" start-server" | Out-Null
  $out = Cmd "& `"$ADB_EXE`" devices"
  Log "✅ Reset ADB realizado. Revisa si aparece popup RSA en teléfono." "Green"
  return $out
}

function Run-Flutter {
  param([hashtable]$summary, [bool]$doClean)

  if ($doClean) {
    Log "flutter clean..." "Cyan"
    Cmd "flutter clean" | Out-Null
    if ($LASTEXITCODE -eq 0) { $summary["FlutterClean"] = "PASS" } else { $summary["FlutterClean"] = "FAIL" }
  }

  Log "flutter pub get..." "Cyan"
  Cmd "flutter pub get" | Out-Null
  if ($LASTEXITCODE -eq 0) {
    $summary["FlutterPubGet"] = "PASS"
  } else {
    $summary["FlutterPubGet"] = "FAIL"
    Log "❌ flutter pub get falló." "Red"
    return $false
  }

  Log "flutter run..." "Cyan"
  $runCmd = "flutter run -d $DEVICE_ID --dart-define=ATALAYA_USE_MOCK=false --dart-define=ATALAYA_API_BASE_URL=http://${API_IP}:${API_PORT}"
  Add-Content -Path $LOG_FILE -Value "---- FLUTTER RUN START ----"
  try {
    Invoke-Expression $runCmd 2>&1 | Tee-Object -FilePath $LOG_FILE -Append
    if ($LASTEXITCODE -eq 0) {
      $summary["FlutterRun"] = "PASS"
    } else {
      $summary["FlutterRun"] = "FAIL"
    }
  } catch {
    $summary["FlutterRun"] = "FAIL"
    Log "❌ Excepción flutter run: $($_.Exception.Message)" "Red"
  }
  return ($summary["FlutterRun"] -eq "PASS")
}

function Flow-ChecksOnly {
  $summary = Init-Summary
  if (-not (Check-Paths $summary)) { Print-Summary $summary; return }
  Free-Port8010 $summary
  if (-not (Start-Backend $summary)) { Print-Summary $summary; return }
  [void](Check-HealthAll $summary)
  [void](Check-AdbDevice $summary)
  Print-Summary $summary
}

function Flow-ChecksAndRun {
  $summary = Init-Summary
  if (-not (Check-Paths $summary)) { Print-Summary $summary; return }
  Free-Port8010 $summary
  if (-not (Start-Backend $summary)) { Print-Summary $summary; return }
  if (-not (Check-HealthAll $summary)) {
    Log "❌ Health checks fallaron." "Red"
    Print-Summary $summary
    return
  }
  if (-not (Check-AdbDevice $summary)) {
    Log "❌ ADB/dispositivo no listo. Corre opción 3 si sigue unauthorized." "Red"
    Print-Summary $summary
    return
  }
  [void](Run-Flutter $summary $true)
  Print-Summary $summary
}

function Flow-BackendOnly {
  $summary = Init-Summary
  if (-not (Check-Paths $summary)) { Print-Summary $summary; return }
  Free-Port8010 $summary
  if (-not (Start-Backend $summary)) { Print-Summary $summary; return }
  [void](Check-HealthAll $summary)
  Print-Summary $summary
}

# ---------- Main menu ----------
Log "=== Atalaya Run Helper v3 ===" "Cyan"
Log "Log file: $LOG_FILE" "Gray"

do {
  Write-Host ""
  Write-Host "Selecciona una opción:" -ForegroundColor Cyan
  Write-Host "  1) Solo pre-checks (paths, backend, health, adb)"
  Write-Host "  2) Pre-checks + flutter run"
  Write-Host "  3) Reset ADB profundo"
  Write-Host "  4) Solo backend (levantar + health)"
  Write-Host "  5) Salir"
  $opt = Read-Host "Opción"

  switch ($opt) {
    "1" { Flow-ChecksOnly }
    "2" { Flow-ChecksAndRun }
    "3" { [void](Reset-AdbDeep) }
    "4" { Flow-BackendOnly }
    "5" { Log "Saliendo..." "Gray" }
    default { Log "Opción inválida: $opt" "Yellow" }
  }
}
while ($opt -ne "5")