[CmdletBinding()]
param([ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version = '2.12.2')

$ErrorActionPreference = 'Stop'
$installPath = Join-Path $env:LOCALAPPDATA "Microsoft/PowerPlatformCLI/$Version"
$pacFiles = @(Get-ChildItem -LiteralPath $installPath -Filter pac.exe -Recurse -ErrorAction SilentlyContinue)
if ($pacFiles.Count -eq 0) {
    $archivePath = Join-Path $env:TEMP "microsoft.powerapps.cli.$Version.zip"
    Invoke-WebRequest -Uri "https://api.nuget.org/v3-flatcontainer/microsoft.powerapps.cli/$Version/microsoft.powerapps.cli.$Version.nupkg" -OutFile $archivePath -UseBasicParsing
    Expand-Archive -LiteralPath $archivePath -DestinationPath $installPath -Force
    $pacFiles = @(Get-ChildItem -LiteralPath $installPath -Filter pac.exe -Recurse)
}
if ($pacFiles.Count -ne 1) { throw 'No se encontro un unico pac.exe en la distribucion.' }
$pacPath = $pacFiles[0].FullName
$signature = Get-AuthenticodeSignature -LiteralPath $pacPath
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
    throw 'La firma Microsoft de pac.exe no es valida. No se agregara al PATH.'
}
$pacDirectory = Split-Path -Parent $pacPath
$userPath = [string][Environment]::GetEnvironmentVariable('Path', 'User')
if ($pacDirectory -notin @($userPath -split ';')) {
    $updatedUserPath = ($userPath.TrimEnd(';') + ';' + $pacDirectory).TrimStart(';')
    [Environment]::SetEnvironmentVariable('Path', $updatedUserPath, 'User')
}
if ($pacDirectory -notin @($env:Path -split ';')) { $env:Path += ';' + $pacDirectory }
& $pacPath help
if ($LASTEXITCODE -ne 0) { throw 'pac no pudo ejecutarse correctamente.' }
Write-Output "pac instalado y verificado: $pacPath"
