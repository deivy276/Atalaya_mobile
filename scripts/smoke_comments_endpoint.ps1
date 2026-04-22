param(
  [string]$BaseUrl = "https://atalaya-mobile-api-staging.onrender.com",
  [string]$Username = "mobile_test@atalaya.local",
  [string]$Password = $env:ATALAYA_MOBILE_STAGING_PASSWORD,
  [string]$Well = "IXACHI-45",
  [string]$Job = "",
  [int]$Limit = 20
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Password)) {
  $secure = Read-Host "Password for $Username" -AsSecureString
  $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}

$body = @{ username = $Username; password = $Password } | ConvertTo-Json -Compress
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/login" -ContentType "application/json" -Body $body
$token = $login.access_token

$query = "well=$([uri]::EscapeDataString($Well))&limit=$Limit"
if (-not [string]::IsNullOrWhiteSpace($Job)) {
  $query += "&job=$([uri]::EscapeDataString($Job))"
}

$comments = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/comments?$query" -Headers @{ Authorization = "Bearer $token" }
"Comments count: $($comments.count)"
$comments.items | Format-Table id, author, job, body, createdAt -AutoSize
