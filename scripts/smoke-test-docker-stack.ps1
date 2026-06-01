param(
  [string]$ApiBaseUrl = "http://localhost:3000",
  [string]$FrontendBaseUrl = "http://localhost:8080",
  [string]$N8nBaseUrl = "http://localhost:5678"
)

$ErrorActionPreference = "Stop"

function Test-JsonEndpoint([string]$Name, [string]$Url) {
  try {
    $response = Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = "application/json" }
    [pscustomobject]@{
      name = $Name
      url = $Url
      ok = $true
      detail = $response
    }
  } catch {
    throw "$Name failed at $Url. $($_.Exception.Message)"
  }
}

function Test-BinaryEndpoint([string]$Name, [string]$Url) {
  try {
    $response = Invoke-WebRequest -Method Get -Uri $Url -UseBasicParsing
    [pscustomobject]@{
      name = $Name
      url = $Url
      ok = $response.StatusCode -ge 200 -and $response.StatusCode -lt 400
      statusCode = $response.StatusCode
      contentLength = $response.RawContentLength
    }
  } catch {
    throw "$Name failed at $Url. $($_.Exception.Message)"
  }
}

$results = @(
  Test-JsonEndpoint "api-health" "$ApiBaseUrl/healthz"
  Test-JsonEndpoint "api-ready" "$ApiBaseUrl/readyz"
  Test-JsonEndpoint "api-jwks" "$ApiBaseUrl/.well-known/jwks.json"
  Test-BinaryEndpoint "frontend-apk" "$FrontendBaseUrl/cashflow-manager.apk"
  Test-JsonEndpoint "n8n-health" "$N8nBaseUrl/healthz"
)

$failed = $results | Where-Object { -not $_.ok }
if ($failed) {
  $failed | Format-List | Out-String | Write-Error
  exit 1
}

$results
