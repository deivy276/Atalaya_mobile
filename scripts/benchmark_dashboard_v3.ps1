param(
  [string]$BaseUrl = 'http://127.0.0.1:8010'
)

function Invoke-TimedJson {
  param(
    [Parameter(Mandatory = $true)][string]$Url
  )

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $response = Invoke-WebRequest $Url -UseBasicParsing
  $sw.Stop()

  [pscustomobject]@{
    Url          = $Url
    Milliseconds = [int]$sw.ElapsedMilliseconds
    XCache       = $response.Headers['x-cache-status']
    XKP          = $response.Headers['x-kp-cache-status']
    XAlerts      = $response.Headers['x-alerts-cache-status']
    XSamples     = $response.Headers['x-samples-source']
    XProcess     = $response.Headers['x-process-time-ms']
  }
}

Write-Host '1) Cold dashboard (expected MISS)' -ForegroundColor Cyan
Invoke-TimedJson -Url "$BaseUrl/api/v1/dashboard" | Format-List

Write-Host ''
Write-Host '2) Immediate dashboard (expected HIT)' -ForegroundColor Cyan
Invoke-TimedJson -Url "$BaseUrl/api/v1/dashboard" | Format-List

Write-Host ''
Write-Host '3) Fresh dashboard core (target < 2s with materialized view)' -ForegroundColor Cyan
Invoke-TimedJson -Url "$BaseUrl/api/v1/dashboard?fresh=true" | Format-List

Write-Host ''
Write-Host '4) Fresh alerts (separate from dashboard core)' -ForegroundColor Cyan
Invoke-TimedJson -Url "$BaseUrl/api/v1/alerts?fresh=true" | Format-List

Write-Host ''
Write-Host '5) Legacy full dashboard (for compatibility only)' -ForegroundColor Cyan
Invoke-TimedJson -Url "$BaseUrl/api/v1/dashboard/full?fresh=true&alerts_fresh=true" | Format-List
