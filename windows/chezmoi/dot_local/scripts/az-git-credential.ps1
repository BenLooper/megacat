param(
  [Parameter(Position = 0)]
  [string]$Operation
)

if ($Operation -ne "get") {
  exit 0
}

$request = [Console]::In.ReadToEnd()
$hostLine = $request -split "`r?`n" | Where-Object { $_ -like "host=*" } | Select-Object -First 1
if (-not $hostLine -or $hostLine.Substring(5) -ne "dev.azure.com") {
  exit 0
}

$token = az account get-access-token `
  --resource 499b84ac-1321-427f-aa17-267ca6975798 `
  --query accessToken `
  --output tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
  throw "Azure CLI could not obtain an Azure DevOps access token. Run 'az login' again."
}

Write-Output "protocol=https"
Write-Output "host=dev.azure.com"
Write-Output "username=oauth2"
Write-Output "password=$token"
