param(
    [string]$AedtExe = "$env:ProgramFiles\ANSYS Inc\ANSYS Student\v252\AnsysEM\ansysedtng.exe"
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'run_b6_maxwell.py'
$postPath = Join-Path $PSScriptRoot 'matrix_to_pairs.py'
$resultsDir = Join-Path $PSScriptRoot 'results'
$aedtTempDir = Join-Path $resultsDir 'aedt_temp'
$logPath = Join-Path $resultsDir 'maxwell_console.log'
$jsonPath = Join-Path $resultsDir 'maxwell_run.json'
$matrixPath = Join-Path $resultsDir 'B6_Maxwell_Ymatrix.tab'
$batchOptionsPath = Join-Path $resultsDir 'aedt_batchoptions.cfg'

if (-not (Test-Path -LiteralPath $AedtExe -PathType Leaf)) {
    throw "Maxwell launcher not found: $AedtExe. Pass its full path with -AedtExe."
}
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Maxwell script not found: $scriptPath"
}
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
New-Item -ItemType Directory -Force -Path $aedtTempDir | Out-Null
$env:TEMP = $aedtTempDir
$env:TMP = $aedtTempDir

$config = @{
    runscriptandexit = $scriptPath
    logfile = $logPath
    monitor = $true
}
$config | ConvertTo-Json | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$aedtTempForCli = $aedtTempDir.Replace('\', '/')
@("`$begin 'Config'", "'TempDirectory'='$aedtTempForCli'", "`$end 'Config'") |
    Set-Content -LiteralPath $batchOptionsPath -Encoding ASCII

Write-Host "Launching Maxwell: $AedtExe"
Write-Host "Script: $scriptPath"
Write-Host "Log: $logPath"
$runStarted = Get-Date
& $AedtExe -batchoptions $batchOptionsPath -json $jsonPath
if ($LASTEXITCODE -ne 0) {
    throw "Maxwell exited with code $LASTEXITCODE. Inspect $logPath"
}
if (-not (Test-Path -LiteralPath $matrixPath -PathType Leaf)) {
    throw "AEDT returned without producing the Y matrix. The script likely failed before solving; inspect $logPath."
}
if ((Get-Item -LiteralPath $matrixPath).LastWriteTime -lt $runStarted) {
    throw "AEDT did not update the Y matrix during this run; refusing to postprocess a stale file. Inspect $logPath."
}

Write-Host 'Converting the exported grounded Y matrix into 120 floating-pair rows...'
& py $postPath
if ($LASTEXITCODE -ne 0) {
    throw "Matrix post-processing failed. Inspect maxwell_run.json and the exported .tab layout; no pair CSV was accepted."
}
