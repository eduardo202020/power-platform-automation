[CmdletBinding()]
param(
    [string]$AutomationConfig = 'config/automations/smoke-test.json',
    [Parameter(Mandatory)][string]$EnvironmentConfig,
    [string]$AppId,
    [string]$PacPath
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'AutomationConfig.psm1') -Force

$automation = Get-AutomationConfig -Path $AutomationConfig -Root $root
$environment = Get-EnvironmentConfig -Path $EnvironmentConfig -Root $root
$pac = Get-PacExecutable -Automation $automation -Environment $environment -PacPath $PacPath
if ([string]::IsNullOrWhiteSpace($AppId)) { $AppId = Resolve-CanvasAppId -Pac $pac -Automation $automation -Environment $environment }

$flowResult = Invoke-PacJson -Pac $pac -Arguments @('power-automate', 'list-cloud-flows', '--environment', $environment.environmentId, '--workflow-id', $automation.flow.workflowId, '--json')
$flow = @($flowResult.value)
if ($flow.Count -ne 1 -or $flow[0].stateCode -ne 'Published') { throw 'El flujo configurado no esta publicado.' }
$app = Invoke-PacJson -Pac $pac -Arguments @('power-apps', 'get-admin-app', '--environment', $environment.environmentId, '--app', $AppId, '--json')
if ($app.properties.lifeCycleId -ne 'Published') { throw 'La app configurada no esta publicada.' }
$connection = $app.properties.connectionReferences.PSObject.Properties.Value | Where-Object {
    $_.parameterHints.workflowEntityId.value -eq $automation.flow.workflowId -and
    $_.parameterHints.workflowName.value -eq $flow[0].resourceId
}
if (-not $connection) { throw 'La app no referencia el flujo configurado.' }
$runs = Invoke-PacJson -Pac $pac -Arguments @('power-automate', 'list-flow-runs', '--environment', $environment.environmentId, '--workflow-id', $automation.flow.workflowId, '--json')
Write-Output "App '$($automation.app.logicalName)' publicada; flujo '$($automation.flow.displayName)' publicado; referencia app-flujo verificada."
if ($null -eq $runs -or ($runs.PSObject.Properties.Name -contains 'value' -and -not $runs.value)) {
    Write-Output 'La consulta CLI no devuelve ejecuciones. Verificar el resultado en la app o en el historial de Power Automate; esta consulta no acredita un fallo.'
} else {
    Write-Output 'El historial devuelve ejecuciones; comparar el ID mostrado por la app con el historial de Power Automate.'
}
