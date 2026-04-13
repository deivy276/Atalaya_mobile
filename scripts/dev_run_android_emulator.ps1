param(
    [string]$AvdName = "Medium_Phone_API_36.0",
    [string]$FlutterBin = "$env:USERPROFILE\flutter\3.38.6\bin\flutter.bat",
    [string]$AndroidSdkRoot = "$env:LOCALAPPDATA\Android\sdk",
    [switch]$UseMock,
    [string]$ApiBaseUrl = "",
    [int]$DeviceTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"

function Resolve-ToolPath {
    param(
        [string]$Candidate,
        [string]$CommandName
    )

    if ($Candidate -and (Test-Path $Candidate)) {
        return (Resolve-Path $Candidate).Path
    }

    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        return $cmd.Source
    }

    return $null
}

$emulatorExe = Join-Path $AndroidSdkRoot "emulator\emulator.exe"
$adbExe = Join-Path $AndroidSdkRoot "platform-tools\adb.exe"

$flutterExe = Resolve-ToolPath -Candidate $FlutterBin -CommandName "flutter"
if (-not $flutterExe) {
    throw "No se encontró flutter. Define -FlutterBin o agrega flutter al PATH."
}
if (-not (Test-Path $emulatorExe)) {
    throw "No se encontró emulator.exe en $emulatorExe. Revisa -AndroidSdkRoot."
}
if (-not (Test-Path $adbExe)) {
    throw "No se encontró adb.exe en $adbExe. Revisa -AndroidSdkRoot."
}

Write-Host "==> Flutter: $flutterExe"
Write-Host "==> Emulator: $emulatorExe"
Write-Host "==> ADB: $adbExe"

$availableAvds = & $emulatorExe -list-avds
if (-not $availableAvds) {
    throw "No hay AVDs disponibles. Crea uno con Android Studio Device Manager."
}
if ($availableAvds -notcontains $AvdName) {
    Write-Host "AVD '$AvdName' no encontrado. Disponibles:"
    $availableAvds | ForEach-Object { Write-Host " - $_" }
    throw "Selecciona -AvdName con un valor válido."
}

Write-Host "==> Reiniciando ADB..."
& $adbExe kill-server | Out-Null
& $adbExe start-server | Out-Null

Write-Host "==> Lanzando emulador: $AvdName"
Start-Process -FilePath $emulatorExe -ArgumentList @("-avd", $AvdName, "-no-snapshot-load")

Write-Host "==> Esperando dispositivo..."
& $adbExe wait-for-device | Out-Null

$maxRetries = 90
for ($i = 0; $i -lt $maxRetries; $i++) {
    $bootState = (& $adbExe shell getprop sys.boot_completed 2>$null).Trim()
    $deviceState = (& $adbExe get-state 2>$null).Trim()
    if ($bootState -eq "1" -and $deviceState -eq "device") {
        break
    }
    Start-Sleep -Seconds 2
}

$deviceList = & $adbExe devices
if ($deviceList -notmatch "emulator-\d+\s+device") {
    Write-Host $deviceList
    throw "El emulador no quedó en estado 'device'."
}

$emulatorId = ([regex]::Match($deviceList, "(emulator-\d+)\s+device")).Groups[1].Value
Write-Host "==> Emulador online: $emulatorId"

Write-Host "==> Flutter devices"
& $flutterExe devices --device-timeout $DeviceTimeoutSeconds

$flutterArgs = @("run", "-d", $emulatorId)
if ($UseMock) {
    $flutterArgs += "--dart-define=ATALAYA_USE_MOCK=true"
}
if ($ApiBaseUrl) {
    $flutterArgs += "--dart-define=ATALAYA_API_BASE_URL=$ApiBaseUrl"
}

Write-Host "==> Ejecutando: flutter $($flutterArgs -join ' ')"
& $flutterExe @flutterArgs
