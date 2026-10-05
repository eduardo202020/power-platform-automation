[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EnvironmentId,
    [string]$AppId = '5ff47c3f-6729-4fed-867a-682f1b04d639'
)
$ErrorActionPreference = 'Stop'
$pac = Join-Path $env:LOCALAPPDATA 'Microsoft/PowerPlatformCLI/2.12.2/tools/pac.exe'
$workflowId = '6e19f7d8-3550-48c2-a4d6-e9764302e973'
function Read-PacJson {
    param([string[]]$Arguments)
    $output = (& $pac @Arguments 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'La consulta pac fallo. Ejecuta el comando de consulta individual para ver el diagnostico.' }
    if ([string]::IsNullOrWhiteSpace($output)) { return $null }
    $output | ConvertFrom-Json
}
$flowResult = Read-PacJson @('power-automate','list-cloud-flows','--environment',$EnvironmentId,'--workflow-id',$workflowId,'--json')
$flow = $flowResult.value
if ($flow.Count -ne 1 -or $flow[0].stateCode -ne 'Published') { throw 'El flujo de prueba no esta publicado.' }
$app = Read-PacJson @('power-apps','get-admin-app','--environment',$EnvironmentId,'--app',$AppId,'--json')
if ($app.properties.lifeCycleId -ne 'Published') { throw 'La app no esta publicada.' }
$connection = $app.properties.connectionReferences.PSObject.Properties.Value | Where-Object {
    $_.parameterHints.workflowEntityId.value -eq $workflowId -and
    $_.parameterHints.workflowName.value -eq $flow[0].resourceId
}
if (-not $connection) { throw 'La app no referencia el flujo de prueba esperado.' }
$runs = Read-PacJson @('power-automate','list-flow-runs','--environment',$EnvironmentId,'--workflow-id',$workflowId,'--json')
Write-Output 'App publicada; flujo publicado; referencia app-flujo verificada.'
if ($null -eq $runs -or ($runs.PSObject.Properties.Name -contains 'value' -and -not $runs.value)) {
    Write-Output 'La consulta CLI no devuelve ejecuciones. Verificar el resultado en la app o en el historial de Power Automate; esta consulta no acredita un fallo.'
} else {
    Write-Output 'El historial devuelve ejecuciones; comparar el ID mostrado por la app con el historial de Power Automate.'
    # Las ejecuciones pueden incluir datos de entrada; no imprimir su contenido completo.
}
