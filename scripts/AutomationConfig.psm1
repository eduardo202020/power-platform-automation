Set-StrictMode -Version Latest

function Get-RequiredValue {
    param([Parameter(Mandatory)]$Object, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Context)
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
        throw "$Context requiere '$Name'."
    }
    return $property.Value
}

function Test-GuidValue {
    param([Parameter(Mandatory)][string]$Value, [Parameter(Mandatory)][string]$Context)
    $parsed = [guid]::Empty
    if (-not [guid]::TryParse($Value, [ref]$parsed)) { throw "$Context debe ser un GUID valido." }
}

function Resolve-RepositoryPath {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Path, [switch]$MustExist)
    if ([IO.Path]::IsPathRooted($Path)) { throw "La ruta debe ser relativa al repositorio: $Path" }
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $candidate = [IO.Path]::GetFullPath((Join-Path $rootFull $Path))
    $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "La ruta sale del repositorio: $Path"
    }
    if ($MustExist -and -not (Test-Path -LiteralPath $candidate)) { throw "No existe la ruta configurada: $Path" }
    return $candidate
}

function Get-AutomationConfig {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Root, [switch]$AllowTemplate)
    $configPath = Resolve-RepositoryPath -Root $Root -Path $Path -MustExist
    try { $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { throw "No se pudo leer la configuracion '$Path': $($_.Exception.Message)" }
    if ($config.schemaVersion -ne 1) { throw "La configuracion '$Path' usa un schemaVersion no admitido." }
    $automationId = [string](Get-RequiredValue $config 'automationId' "Configuracion '$Path'")
    if ($automationId -notmatch '^[a-z][a-z0-9-]{1,62}$') { throw "automationId debe usar minusculas, numeros y guiones." }
    if ($config.isTemplate -eq $true -and -not $AllowTemplate) { throw "'$Path' es una plantilla. Copiala con otro nombre antes de construir." }

    foreach ($sourceName in @('flow', 'canvasDirectory', 'solutionTemplate', 'flowReferenceInCanvas')) {
        $null = Get-RequiredValue $config.sources $sourceName "sources de '$Path'"
    }
    foreach ($sourceName in @('flow', 'canvasDirectory', 'solutionTemplate')) {
        $null = Resolve-RepositoryPath -Root $Root -Path ([string]$config.sources.$sourceName) -MustExist
    }
    foreach ($section in @('solution', 'flow', 'app', 'tooling')) {
        if ($null -eq $config.PSObject.Properties[$section]) { throw "Configuracion '$Path' requiere '$section'." }
    }
    foreach ($name in @('uniqueName', 'displayName', 'version')) { $null = Get-RequiredValue $config.solution $name "solution de '$Path'" }
    foreach ($name in @('uniqueName', 'displayName', 'prefix', 'optionValuePrefix')) { $null = Get-RequiredValue $config.solution.publisher $name "publisher de '$Path'" }
    foreach ($name in @('displayName', 'workflowId')) { $null = Get-RequiredValue $config.flow $name "flow de '$Path'" }
    foreach ($name in @('displayName', 'logicalName', 'manifestId', 'connectionId')) { $null = Get-RequiredValue $config.app $name "app de '$Path'" }
    $null = Get-RequiredValue $config.tooling 'pacVersion' "tooling de '$Path'"

    if ([string]$config.solution.uniqueName -notmatch '^[A-Za-z][A-Za-z0-9_]{2,64}$') { throw 'solution.uniqueName no es valido.' }
    if ([string]$config.solution.publisher.prefix -notmatch '^[a-z][a-z0-9]{1,7}$') { throw 'solution.publisher.prefix no es valido.' }
    if ([string]$config.app.logicalName -notmatch '^[a-z][a-z0-9_]{2,99}$') { throw 'app.logicalName no es valido.' }
    if ([string]$config.solution.version -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw 'solution.version debe tener cuatro componentes numericos.' }
    Test-GuidValue -Value ([string]$config.flow.workflowId) -Context 'flow.workflowId'
    Test-GuidValue -Value ([string]$config.app.manifestId) -Context 'app.manifestId'
    Test-GuidValue -Value ([string]$config.app.connectionId) -Context 'app.connectionId'
    return $config
}

function Get-EnvironmentConfig {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Root)
    $configPath = Resolve-RepositoryPath -Root $Root -Path $Path -MustExist
    try { $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { throw "No se pudo leer la configuracion de entorno '$Path': $($_.Exception.Message)" }
    if ($config.schemaVersion -ne 1) { throw "La configuracion de entorno '$Path' usa un schemaVersion no admitido." }
    $environmentId = [string](Get-RequiredValue $config 'environmentId' "Entorno '$Path'")
    if ($environmentId -match '^<.+>$') { throw "'$Path' es una plantilla. Copiala como .local.json e indica el entorno autorizado." }
    $guid = [guid]::Empty
    if (-not [guid]::TryParse($environmentId, [ref]$guid) -and $environmentId -notmatch '^https://[^/]+/?$') {
        throw 'environmentId debe ser un GUID o una URL HTTPS base del entorno.'
    }
    $region = [string](Get-RequiredValue $config 'region' "Entorno '$Path'")
    if ($region -notmatch '^[a-z]+-\d{3}$') { throw 'region debe tener el formato de endpoint, por ejemplo europe-001.' }
    if ($null -eq $config.PSObject.Properties['pacPath']) { $config | Add-Member -MemberType NoteProperty -Name pacPath -Value '' }
    return $config
}

function Get-PacExecutable {
    param([Parameter(Mandatory)]$Automation, $Environment, [string]$PacPath)
    $candidate = $PacPath
    if ([string]::IsNullOrWhiteSpace($candidate) -and $null -ne $Environment) { $candidate = [string]$Environment.pacPath }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = Join-Path $env:LOCALAPPDATA "Microsoft/PowerPlatformCLI/$($Automation.tooling.pacVersion)/tools/pac.exe"
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "No se encontro pac.exe en '$candidate'. Configure pacPath o instale la version $($Automation.tooling.pacVersion)." }
    return (Resolve-Path -LiteralPath $candidate).Path
}

function Reset-DirectoryInsideRepository {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$RelativePath)
    $target = Resolve-RepositoryPath -Root $Root -Path $RelativePath
    $artifacts = Resolve-RepositoryPath -Root $Root -Path 'artifacts' -MustExist
    $artifactPrefix = $artifacts.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $target.StartsWith($artifactPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Solo se pueden reiniciar directorios dentro de artifacts.' }
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    return $target
}

function New-AutomationStage {
    param([Parameter(Mandatory)]$Automation, [Parameter(Mandatory)][string]$Root)
    $stage = Reset-DirectoryInsideRepository -Root $Root -RelativePath ("artifacts/build/" + $Automation.automationId)
    $solution = Join-Path $stage 'solution'
    New-Item -ItemType Directory -Path $solution -Force | Out-Null
    $template = Resolve-RepositoryPath -Root $Root -Path ([string]$Automation.sources.solutionTemplate) -MustExist
    Copy-Item -Path (Join-Path $template '*') -Destination $solution -Recurse -Force
    return [pscustomobject]@{ Root = $stage; Solution = $solution; Canvas = (Join-Path $stage 'canvas') }
}

function Write-AutomationFlowSource {
    param([Parameter(Mandatory)]$Automation, [Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$SolutionPath)
    $workflowFolder = Join-Path $SolutionPath 'Workflows'
    New-Item -ItemType Directory -Path $workflowFolder -Force | Out-Null
    Get-ChildItem -LiteralPath $workflowFolder -File | Remove-Item -Force
    $flowSource = Resolve-RepositoryPath -Root $Root -Path ([string]$Automation.sources.flow) -MustExist
    $flow = Get-Content -LiteralPath $flowSource -Raw -Encoding UTF8 | ConvertFrom-Json
    $flow | Add-Member -MemberType NoteProperty -Name schemaVersion -Value $Automation.solution.version -Force
    $filename = "$($Automation.flow.displayName)-$(([string]$Automation.flow.workflowId).ToUpperInvariant()).json"
    $utf8 = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText((Join-Path $workflowFolder $filename), ($flow | ConvertTo-Json -Depth 100), $utf8)
    $flowId = [Security.SecurityElement]::Escape([string]$Automation.flow.workflowId)
    $flowName = [Security.SecurityElement]::Escape([string]$Automation.flow.displayName)
    $filenameXml = [Security.SecurityElement]::Escape($filename)
    $version = [Security.SecurityElement]::Escape([string]$Automation.solution.version)
    $workflowXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Workflow WorkflowId="{$flowId}" Name="$flowName" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <JsonFileName>/Workflows/$filenameXml</JsonFileName>
  <Type>1</Type><Subprocess>0</Subprocess><Category>5</Category>
  <Mode>0</Mode><Scope>4</Scope><OnDemand>0</OnDemand>
  <TriggerOnCreate>0</TriggerOnCreate><TriggerOnDelete>0</TriggerOnDelete>
  <AsyncAutodelete>0</AsyncAutodelete><SyncWorkflowLogOnFailure>0</SyncWorkflowLogOnFailure>
  <StateCode>1</StateCode><StatusCode>2</StatusCode><RunAs>1</RunAs>
  <IsTransacted>1</IsTransacted><IntroducedVersion>$version</IntroducedVersion>
  <IsCustomizable>1</IsCustomizable>
  <IsCustomProcessingStepAllowedForOtherPublishers>1</IsCustomProcessingStepAllowedForOtherPublishers>
  <PrimaryEntity>none</PrimaryEntity>
  <LocalizedNames><LocalizedName languagecode="1033" description="$flowName" /></LocalizedNames>
</Workflow>
"@
    [IO.File]::WriteAllText((Join-Path $workflowFolder ($filename + '.data.xml')), $workflowXml, $utf8)
    return $filename
}

function Update-SolutionManifestIdentity {
    param([Parameter(Mandatory)]$Automation, [Parameter(Mandatory)][string]$SolutionPath)
    $solutionPath = Join-Path $SolutionPath 'Other/Solution.xml'
    [xml]$solution = Get-Content -LiteralPath $solutionPath -Raw
    $manifest = $solution.ImportExportXml.SolutionManifest
    $manifest.UniqueName = [string]$Automation.solution.uniqueName
    $manifest.LocalizedNames.LocalizedName.description = [string]$Automation.solution.displayName
    $manifest.Version = [string]$Automation.solution.version
    $manifest.Managed = '0'
    $publisher = $manifest.Publisher
    $publisher.UniqueName = [string]$Automation.solution.publisher.uniqueName
    $publisher.LocalizedNames.LocalizedName.description = [string]$Automation.solution.publisher.displayName
    $publisher.Descriptions.Description.description = [string]$Automation.solution.publisher.displayName
    $publisher.CustomizationPrefix = [string]$Automation.solution.publisher.prefix
    $publisher.CustomizationOptionValuePrefix = [string]$Automation.solution.publisher.optionValuePrefix
    $solution.Save($solutionPath)
}

function Set-SolutionRootComponents {
    param([Parameter(Mandatory)]$Automation, [Parameter(Mandatory)][string]$SolutionPath, [switch]$IncludeCanvasApp)
    $solutionPath = Join-Path $SolutionPath 'Other/Solution.xml'
    [xml]$solution = Get-Content -LiteralPath $solutionPath -Raw
    $components = $solution.SelectSingleNode('//RootComponents')
    foreach ($component in @($components.SelectNodes("RootComponent[@type='29' or @type='300']"))) { $null = $components.RemoveChild($component) }
    $flow = $solution.CreateElement('RootComponent')
    $flow.SetAttribute('type', '29')
    $flow.SetAttribute('id', "{$($Automation.flow.workflowId)}")
    $flow.SetAttribute('behavior', '0')
    $null = $components.AppendChild($flow)
    if ($IncludeCanvasApp) {
        $app = $solution.CreateElement('RootComponent')
        $app.SetAttribute('type', '300')
        $app.SetAttribute('schemaName', [string]$Automation.app.logicalName)
        $app.SetAttribute('behavior', '0')
        $null = $components.AppendChild($app)
    }
    $solution.Save($solutionPath)
}

function Invoke-PacJson {
    param([Parameter(Mandatory)][string]$Pac, [Parameter(Mandatory)][string[]]$Arguments)
    $output = (& $Pac @Arguments 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'La consulta pac fallo. Ejecuta el comando individual para ver el diagnostico.' }
    if ([string]::IsNullOrWhiteSpace($output)) { return $null }
    try { return ($output | ConvertFrom-Json) } catch { throw "pac no devolvio JSON valido: $($_.Exception.Message)" }
}

function Resolve-CanvasAppId {
    param([Parameter(Mandatory)][string]$Pac, [Parameter(Mandatory)]$Automation, [Parameter(Mandatory)]$Environment)
    $name = [Security.SecurityElement]::Escape([string]$Automation.app.logicalName)
    $fetch = "<fetch><entity name='canvasapp'><attribute name='canvasappid' /><filter><condition attribute='name' operator='eq' value='$name' /></filter></entity></fetch>"
    $output = (& $Pac env fetch --environment $Environment.environmentId --xml $fetch 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar la app canvas por nombre logico.' }
    try { [xml]$result = $output } catch { throw 'La consulta de app canvas no devolvio XML valido.' }
    $ids = @($result.SelectNodes('//result/canvasappid') | ForEach-Object { $_.'#text' } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($ids.Count -ne 1) { throw "Se esperaba una sola app canvas con nombre '$($Automation.app.logicalName)' y se encontraron $($ids.Count)." }
    return [string]$ids[0]
}

Export-ModuleMember -Function Get-AutomationConfig,Get-EnvironmentConfig,Get-PacExecutable,Resolve-RepositoryPath,New-AutomationStage,Write-AutomationFlowSource,Update-SolutionManifestIdentity,Set-SolutionRootComponents,Invoke-PacJson,Resolve-CanvasAppId
