param(
  [string]$WebhookUrl = "http://localhost:5678/webhook/cashflow-ai-analysis",
  [string]$Secret = "replace-with-local-webhook-hmac-secret",
  [string]$MockProviderUrl = "http://localhost:4567"
)

$ErrorActionPreference = "Stop"

function New-Signature([string]$Body, [string]$Key) {
  $hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($Key))
  try {
    return ([BitConverter]::ToString($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($Body))) -replace '-', '').ToLowerInvariant()
  } finally {
    $hmac.Dispose()
  }
}

$body = [ordered]@{
  question = "Phan tich chi tieu thang nay"
  locale = "vi"
} | ConvertTo-Json -Compress

try {
  Invoke-RestMethod -Method Post -Uri "$MockProviderUrl/__reset" | Out-Null
} catch {
  throw "Mock provider stats endpoint is unavailable. Start scripts/mock-openai-compatible-provider.mjs before running this smoke test."
}

$invalidRejected = $false
try {
  Invoke-RestMethod -Method Post -Uri $WebhookUrl -ContentType "application/json" -Headers @{
    "x-cashflow-signature-sha256" = "0000000000000000000000000000000000000000000000000000000000000000"
  } -Body $body | Out-Null
} catch {
  $invalidRejected = $true
}

if (-not $invalidRejected) {
  throw "n8n accepted an invalid CashFlow signature."
}

$statsAfterInvalid = Invoke-RestMethod -Method Get -Uri "$MockProviderUrl/__stats"
if ($statsAfterInvalid.chatCompletionRequests -ne 0) {
  throw "n8n called the AI provider before rejecting the invalid CashFlow signature."
}

$response = Invoke-RestMethod -Method Post -Uri $WebhookUrl -ContentType "application/json" -Headers @{
  "x-cashflow-signature-sha256" = New-Signature $body $Secret
} -Body $body

if (-not $response.answer) {
  throw "n8n returned no answer."
}

if ($null -eq $response.suggestions -or $response.suggestions.Count -lt 3 -or $response.suggestions.Count -gt 5) {
  throw "n8n returned an invalid suggestions array."
}

foreach ($suggestion in $response.suggestions) {
  if ($suggestion -isnot [string] -or [string]::IsNullOrWhiteSpace($suggestion)) {
    throw "n8n returned an invalid suggestion item."
  }
}

$statsAfterValid = Invoke-RestMethod -Method Get -Uri "$MockProviderUrl/__stats"
if ($statsAfterValid.chatCompletionRequests -ne 1) {
  throw "n8n did not call the AI provider exactly once after a valid CashFlow signature."
}

[pscustomobject]@{
  invalidSignatureRejected = $invalidRejected
  providerSkippedForInvalidSignature = $true
  answerPresent = [bool]$response.answer
  suggestions = $response.suggestions.Count
  providerCalls = $statsAfterValid.chatCompletionRequests
}
