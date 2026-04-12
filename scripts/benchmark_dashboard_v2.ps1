param(
    [string]$BaseUrl = "http://127.0.0.1:8010"
)

function Measure-Endpoint($url) {
    $measure = Measure-Command { $resp = Invoke-WebRequest $url -UseBasicParsing }
    [pscustomobject]@{
        Url = $url
        Milliseconds = [math]::Round($measure.TotalMilliseconds, 0)
        XCache = $resp.Headers['X-Cache-Status']
        XKP = $resp.Headers['X-KP-Cache-Status']
        XProcess = $resp.Headers['X-Process-Time-Ms']
    }
}

Write-Host "1) Cold cached endpoint (expected MISS)" -ForegroundColor Cyan
Measure-Endpoint "$BaseUrl/api/v1/dashboard" | Format-List

Write-Host "2) Immediate cached endpoint (expected HIT)" -ForegroundColor Green
Measure-Endpoint "$BaseUrl/api/v1/dashboard" | Format-List

Write-Host "3) Fresh endpoint (expected MISS)" -ForegroundColor Yellow
Measure-Endpoint "$BaseUrl/api/v1/dashboard?fresh=true" | Format-List
