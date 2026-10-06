[CmdletBinding()]
param(
    [string]$AutomationConfig = 'config/automations/smoke-test.json',
    [string]$PacPath
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'AutomationConfig.psm1') -Force

$automation = Get-AutomationConfig -Path $AutomationConfig -Root $root
$pac = Get-PacExecutable -Automation $automation -PacPath $PacPath
$stage = New-AutomationStage -Automation $automation -Root $root

Update-SolutionManifestIdentity -Automation $automation -SolutionPath $stage.Solution
$filename = Write-AutomationFlowSource -Automation $automation -Root $root -SolutionPath $stage.Solution
Set-SolutionRootComponents -Automation $automation -SolutionPath $stage.Solution
# El paquete inicial solo contiene el flujo. La plantilla del piloto ya tiene
# una app publicada, que no puede acompañar un manifiesto sin su componente.
$canvasFolder = Join-Path $stage.Solution 'CanvasApps'
if (Test-Path -LiteralPath $canvasFolder) {
    $stagePrefix = ([IO.Path]::GetFullPath($stage.Solution).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar)
    if (-not [IO.Path]::GetFullPath($canvasFolder).StartsWith($stagePrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'La limpieza de CanvasApps saldria del staging.' }
    Remove-Item -LiteralPath $canvasFolder -Recurse -Force
}
$customPath = Join-Path $stage.Solution 'Other/Customizations.xml'
[xml]$custom = Get-Content -LiteralPath $customPath -Raw
if ($canvasApps = $custom.SelectSingleNode('//CanvasApps')) { $null = $canvasApps.ParentNode.RemoveChild($canvasApps) }
$custom.Save($customPath)

$package = Join-Path $root ("artifacts/{0}.zip" -f $automation.solution.uniqueName)
& $pac solution pack --folder $stage.Solution --zipfile $package --packagetype Unmanaged
if ($LASTEXITCODE -ne 0) { throw 'No se pudo empaquetar la solucion.' }
Write-Output "Flujo generado: $filename"
Write-Output "Paquete generado: $package"
