[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'solutions/AutomationConnectionTest/src'
$workflowFolder = Join-Path $source 'Workflows'
$flowId = '6e19f7d8-3550-48c2-a4d6-e9764302e973'
$name = 'AutomatizacionPruebaConexion'
$filename = "$name-$($flowId.ToUpperInvariant()).json"
New-Item -ItemType Directory -Path $workflowFolder -Force | Out-Null
$json = Get-Content (Join-Path $root 'examples/smoke-test/flow.clientdata.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$json | Add-Member -MemberType NoteProperty -Name schemaVersion -Value '1.0.0.0' -Force
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $workflowFolder $filename), ($json | ConvertTo-Json -Depth 100), $utf8)
$workflowXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Workflow WorkflowId="{$flowId}" Name="$name" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <JsonFileName>/Workflows/$filename</JsonFileName>
  <Type>1</Type><Subprocess>0</Subprocess><Category>5</Category>
  <Mode>0</Mode><Scope>4</Scope><OnDemand>0</OnDemand>
  <TriggerOnCreate>0</TriggerOnCreate><TriggerOnDelete>0</TriggerOnDelete>
  <AsyncAutodelete>0</AsyncAutodelete><SyncWorkflowLogOnFailure>0</SyncWorkflowLogOnFailure>
  <StateCode>1</StateCode><StatusCode>2</StatusCode><RunAs>1</RunAs>
  <IsTransacted>1</IsTransacted><IntroducedVersion>1.0.0.0</IntroducedVersion>
  <IsCustomizable>1</IsCustomizable>
  <IsCustomProcessingStepAllowedForOtherPublishers>1</IsCustomProcessingStepAllowedForOtherPublishers>
  <PrimaryEntity>none</PrimaryEntity>
  <LocalizedNames><LocalizedName languagecode="1033" description="$name" /></LocalizedNames>
</Workflow>
"@
[IO.File]::WriteAllText((Join-Path $workflowFolder ($filename + '.data.xml')), $workflowXml, $utf8)
$solutionPath = Join-Path $source 'Other/Solution.xml'
[xml]$solution = Get-Content $solutionPath -Raw
$solution.ImportExportXml.SolutionManifest.Managed = '0'
$solution.ImportExportXml.SolutionManifest.Version = '1.0.0.0'
$components = $solution.SelectSingleNode('//RootComponents')
$components.RemoveAll()
$component = $solution.CreateElement('RootComponent')
$component.SetAttribute('type', '29')
$component.SetAttribute('id', "{$flowId}")
$component.SetAttribute('behavior', '0')
$null = $components.AppendChild($component)
$solution.Save($solutionPath)
$pac = Join-Path $env:LOCALAPPDATA 'Microsoft/PowerPlatformCLI/2.12.2/tools/pac.exe'
& $pac solution pack --folder $source --zipfile (Join-Path $root 'artifacts/AutomationConnectionTest.zip') --packagetype Unmanaged
if ($LASTEXITCODE -ne 0) { throw 'No se pudo empaquetar la solucion.' }
