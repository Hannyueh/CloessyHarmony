#Requires -Version 5.1
<#
.SYNOPSIS
  Builds the Yunmei HarmonyOS HAP with the DevEco Studio toolchain that is
  already installed on this machine.

.DESCRIPTION
  The project ships without a signingConfig, so the build produces
  entry-default-unsigned.hap. Open the project in DevEco Studio and enable
  automatic signing to install it on a device.
#>
param(
  [string]$DevEcoHome = 'C:\Program Files\Huawei\DevEco Studio',
  [string]$Product = 'default',
  [string]$BuildMode = 'debug'
)

$ErrorActionPreference = 'Stop'

$node = Join-Path $DevEcoHome 'tools\node\node.exe'
$hvigor = Join-Path $DevEcoHome 'tools\hvigor\bin\hvigorw.js'
$sdk = Join-Path $DevEcoHome 'sdk'

if (-not (Test-Path $node) -or -not (Test-Path $hvigor)) {
  throw "DevEco Studio toolchain not found at $DevEcoHome"
}

$env:DEVECO_SDK_HOME = $sdk
$project = Split-Path -Parent $PSScriptRoot
Push-Location $project
try {
  & $node $hvigor assembleHap --mode module -p module=entry@default `
    -p product=$Product -p buildMode=$BuildMode --no-daemon
  if ($LASTEXITCODE -ne 0) {
    throw "hvigor exited with code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

$output = Join-Path $project "entry\build\$Product\outputs\$Product"
Write-Host ""
Write-Host "Artifacts:" -ForegroundColor Green
Get-ChildItem $output -Filter '*.hap' | ForEach-Object {
  Write-Host ("  {0}  ({1:N0} bytes)" -f $_.FullName, $_.Length)
}
