param(
  [string]$BaseUrl = 'http://127.0.0.1:8010',
  [int]$Limit = 30
)

function Invoke-TimedJson {
  param(
    [Parameter(Mandatory = $true)][string]$Url
  )

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $response = Invoke-WebRequest $Url -UseBasicParsing
  $sw.Stop()

  [pscustomobject]@{
    Url               = $Url
    Milliseconds      = [int]$sw.ElapsedMilliseconds
    XAlertsCache      = $response.Headers['x-alerts-cache-status']
    XAlertsSource     = $response.Headers['x-alerts-source']
    XAlertsRepairs    = $response.Headers['x-alerts-text-repairs']
    XProcess          = $response.Headers['x-process-time-ms']
  }
}

Write-Host '1) Fresh alerts (expected MISS)' -ForegroundColor Cyan
Invoke-TimedJson -Url "$BaseUrl/api/v1/alerts?fresh=true&limit=$Limit" | Format-List

Write-Host ''
Write-Host '2) Cached alerts (expected HIT)' -ForegroundColor Cyan
Invoke-TimedJson -Url "$BaseUrl/api/v1/alerts?limit=$Limit" | Format-List

Write-Host ''
Write-Host '3) Immediate cached alerts (expected HIT)' -ForegroundColor Cyan
Invoke-TimedJson -Url "$BaseUrl/api/v1/alerts?limit=$Limit" | Format-List
