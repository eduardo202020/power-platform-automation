[CmdletBinding()]
param(
    [string]$AutomationConfig = 'config/automations/smoke-test.json',
    [Parameter(Mandatory)][string]$EnvironmentConfig,
    [string]$PacPath
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'AutomationConfig.psm1') -Force

$automation = Get-AutomationConfig -Path $AutomationConfig -Root $root
$environment = Get-EnvironmentConfig -Path $EnvironmentConfig -Root $root
$pac = Get-PacExecutable -Automation $automation -Environment $environment -PacPath $PacPath
$flowResult = Invoke-PacJson -Pac $pac -Arguments @('power-automate', 'list-cloud-flows', '--environment', $environment.environmentId, '--workflow-id', $automation.flow.workflowId, '--json')
$flow = @($flowResult.value)
if ($flow.Count -ne 1) { throw "No se encontro exactamente un flujo con workflowId $($automation.flow.workflowId)." }
if ([string]::IsNullOrWhiteSpace([string]$flow[0].resourceId)) { throw 'El flujo encontrado no tiene resourceId para la referencia de Power Apps.' }

$sampleSource = Join-Path $root 'artifacts/flow-reference-experimental'
if (-not (Test-Path (Join-Path $sampleSource 'CanvasManifest.json'))) {
    $sampleFile = Join-Path $root 'artifacts/FlowReferenceSample.msapp'
    $sampleUrl = 'https://raw.githubusercontent.com/microsoft/d365cc-fde/2498292232d1e265c9e3eea8445290fc20b74a01/tools/ai-disposition-codes/solution/CanvasApps/ccaasfde_dispositionrecommendation_d051d_DocumentUri.msapp'
    Invoke-WebRequest -Uri $sampleUrl -OutFile $sampleFile -UseBasicParsing
    if ((Get-FileHash $sampleFile -Algorithm SHA256).Hash -ne 'A78FAC5DE4CFFA9DD19F16530503B2F4D82E007F5383A81198932AE2F95A0843') {
        throw 'La plantilla Microsoft no coincide con la version verificada.'
    }
    & $pac canvas unpack --msapp $sampleFile --sources $sampleSource --layout Experimental
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo desempaquetar la plantilla Microsoft.' }
}

$stage = New-AutomationStage -Automation $automation -Root $root
$build = $stage.Canvas
foreach ($folder in @('', 'Src', 'Connections', 'DataSources', 'pkgs', 'pkgs/PcfControlTemplates', 'pkgs/Wadl')) {
    New-Item -ItemType Directory -Path (Join-Path $build $folder) -Force | Out-Null
}
$utf8 = [Text.UTF8Encoding]::new($false)
function Save-Json { param([string]$Path, $Value) [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 100), $utf8) }

$manifest = Get-Content (Join-Path $sampleSource 'CanvasManifest.json') -Raw | ConvertFrom-Json
$manifest.Properties.Name = $automation.app.displayName
$manifest.Properties.DocumentType = 'App'
$manifest.Properties.DocumentLayoutWidth = 800
$manifest.Properties.DocumentLayoutHeight = 600
$manifest.Properties.ContainsThirdPartyPcfControls = $false
$manifest.Properties.Id = $automation.app.manifestId
$manifest.Properties.FileID = $automation.app.manifestId
$manifest.PublishInfo.AppName = $automation.app.displayName
$manifest.PublishInfo.LogoFileName = ''
Save-Json (Join-Path $build 'CanvasManifest.json') $manifest
[IO.File]::WriteAllText((Join-Path $build 'ComponentReferences.json'), '[]', $utf8)

$templates = Get-Content (Join-Path $sampleSource 'ControlTemplates.json') -Raw | ConvertFrom-Json
$keptTemplates = @{}
foreach ($key in @('appinfo', 'screen', 'Button', 'Text')) { $keptTemplates[$key] = $templates.$key }
Save-Json (Join-Path $build 'ControlTemplates.json') $keptTemplates
foreach ($template in @('Button_0.0.45.json', 'Text_0.0.51.json')) {
    Copy-Item -LiteralPath (Join-Path $sampleSource "pkgs/PcfControlTemplates/$template") -Destination (Join-Path $build "pkgs/PcfControlTemplates/$template")
}
Copy-Item -LiteralPath (Join-Path $sampleSource 'Src/Themes.json') -Destination (Join-Path $build 'Src/Themes.json')
$canvasSource = Resolve-RepositoryPath -Root $root -Path $automation.sources.canvasDirectory -MustExist
Get-ChildItem -LiteralPath $canvasSource -Filter '*.fx.yaml' -File | ForEach-Object {
    $content = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    $content = $content.Replace([string]$automation.sources.flowReferenceInCanvas, [string]$automation.flow.displayName)
    [IO.File]::WriteAllText((Join-Path $build "Src/$($_.Name)"), $content, $utf8)
}

$connectionId = [string]$automation.app.connectionId
$flowName = [string]$automation.flow.displayName
$hints = @{
    workflowDisplayName = @{ value = $flowName }
    workflowEntityId = @{ value = $flow[0].workflowId }
    workflowName = @{ value = $flow[0].resourceId }
}
$connectionRef = @{
    id = '/providers/microsoft.powerapps/apis/shared_logicflows'
    displayName = 'Logic flows'
    apiTier = 'Standard'
    parameterHints = $hints
    parameterHintsV2 = $hints
}
$connections = @{}
$connections[$connectionId] = @{
    id = $connectionId
    appActions = @('Run')
    connectionRef = $connectionRef
    dataSources = @($flowName)
    dependencies = @{}
    dependents = @()
    datasets = @{}
}
Save-Json (Join-Path $build 'Connections/Connections.json') $connections
$dataSource = @{
    Name = $flowName
    ApiId = '/providers/microsoft.powerapps/apis/shared_logicflows'
    FlowNameId = $connectionId
    WorkflowEntityId = $flow[0].workflowId
    ServiceKind = 'ConnectedWadl'
    Type = 'ServiceInfo'
}
[IO.File]::WriteAllText((Join-Path $build "DataSources/$flowName.json"), ('[' + ($dataSource | ConvertTo-Json) + ']'), $utf8)

$endpoint = "https://$($environment.region).azure-apim.net/apim/logicflows"
$wadl = @"
<application xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:service="$endpoint" xmlns:siena="http://schemas.microsoft.com/MicrosoftProjectSiena/WADL/2014/11" siena:serviceId="$flowName" xmlns="http://wadl.dev.java.net/2009/02">
  <doc title="$flowName" />
  <grammars><jsonTypes targetNamespace="$endpoint" xmlns="http://schemas.microsoft.com/MicrosoftProjectSiena/WADL/2014/11">
    <object name="ManualTriggerInput"><property name="text" type="string" /></object>
    <object name="ResponseActionOutput"><property name="estado" type="string" /><property name="mensaje" type="string" /><property name="ejecucionid" type="string" /><property name="fechautc" type="string" /></object>
  </jsonTypes></grammars>
  <resources siena:authenticationProviderHref="#PowerAppAuth" base="$endpoint">
    <resource path="/{connectionId}/triggers/manual/run">
      <param style="template" name="connectionId" type="xs:string" required="true" />
      <method siena:requiresAuthentication="true" name="POST" id="Run">
        <request><param style="query" name="api-version" type="xs:string" required="true" fixed="2015-02-01-preview" />
          <representation mediaType="application/json"><param style="plain" name="text" path="/text" type="xs:string" required="true"><doc title="Mensaje" /></param></representation>
        </request>
        <response><representation mediaType="application/json" element="service:ResponseActionOutput" /></response>
      </method>
    </resource>
  </resources>
  <authenticationProviders xmlns="http://schemas.microsoft.com/MicrosoftProjectSiena/WADL/2014/11"><connectionProvider id="PowerAppAuth" siena:connectionProviderId="logicflows" /></authenticationProviders>
  <template xmlns="http://schemas.microsoft.com/MicrosoftProjectSiena/WADL/2014/11"><variable name="connectionId"><modifyParams style="template" name="connectionId" attribute="fixed" /></variable></template>
</application>
"@
[IO.File]::WriteAllText((Join-Path $build "pkgs/Wadl/$flowName.xml"), $wadl, $utf8)

Update-SolutionManifestIdentity -Automation $automation -SolutionPath $stage.Solution
Write-AutomationFlowSource -Automation $automation -Root $root -SolutionPath $stage.Solution | Out-Null
$appFolder = Join-Path $stage.Solution 'CanvasApps'
New-Item -ItemType Directory -Path $appFolder -Force | Out-Null
Get-ChildItem -LiteralPath $appFolder -File | Remove-Item -Force
$appLogicalName = [string]$automation.app.logicalName
$appFile = $appLogicalName + '_DocumentUri.msapp'
Add-Type -AssemblyName System.Drawing
$icon = [Drawing.Bitmap]::new(64, 64)
$graphics = [Drawing.Graphics]::FromImage($icon)
try {
    $graphics.Clear([Drawing.Color]::FromArgb(0, 120, 212))
    $icon.Save((Join-Path $appFolder ($appLogicalName + '_BackgroundImageUri')), [Drawing.Imaging.ImageFormat]::Png)
} finally { $graphics.Dispose(); $icon.Dispose() }
& $pac canvas pack --sources $build --msapp (Join-Path $appFolder $appFile) --layout Experimental --overwrite
if ($LASTEXITCODE -ne 0) { throw 'Fallo el empaquetado de la app canvas.' }

$references = @{}
$references[$connectionId] = @{
    id = $connectionRef.id
    displayName = 'Logic flows'
    dataSources = @($flowName)
    dependencies = @()
    dependents = @()
    parameterHints = $hints
    parameterHintsV2 = $hints
    isOnPremiseConnection = $false
    bypassConsent = $false
    dataSets = @{}
    apiTier = 'Standard'
    actions = @('Run')
}
$refsJson = [Security.SecurityElement]::Escape(($references | ConvertTo-Json -Compress -Depth 100))
$dependencies = @{ cdsdependencies = @(@{ id = [string]$automation.flow.workflowId; componenttype = 29; componenttypeplatformname = 'workflow' }) } | ConvertTo-Json -Compress
$dependencyJson = [Security.SecurityElement]::Escape($dependencies)
$displayName = [Security.SecurityElement]::Escape([string]$automation.app.displayName)
$logicalName = [Security.SecurityElement]::Escape($appLogicalName)
$appXml = @"
<CanvasApp>
  <Name>$logicalName</Name><AppVersion>$($automation.solution.version)</AppVersion><Status>Ready</Status>
  <CreatedByClientVersion>3.26091.1</CreatedByClientVersion><MinClientVersion>3.25091.1</MinClientVersion>
  <Tags>{"primaryDeviceWidth":"800","primaryDeviceHeight":"600","supportsPortrait":"true","supportsLandscape":"true","primaryFormFactor":"Tablet","hasComponent":"false","hasUnlockedComponent":"false","isUnifiedRootApp":"false"}</Tags>
  <IsCdsUpgraded>1</IsCdsUpgraded><BackgroundColor>RGBA(245,247,251,1)</BackgroundColor>
  <DisplayName>$displayName</DisplayName><Description>Prueba de conexion de Power Apps con Power Automate.</Description>
  <AuthorizationReferences>[]</AuthorizationReferences><ConnectionReferences>$refsJson</ConnectionReferences>
  <DatabaseReferences>{}</DatabaseReferences><AppComponents>[]</AppComponents><AppComponentDependencies>[]</AppComponentDependencies>
  <CanConsumeAppPass>1</CanConsumeAppPass><CanvasAppType>0</CanvasAppType><BypassConsent>0</BypassConsent><AdminControlBypassConsent>0</AdminControlBypassConsent>
  <IntroducedVersion>$($automation.solution.version)</IntroducedVersion><CdsDependencies>$dependencyJson</CdsDependencies>
  <IsCustomizable>1</IsCustomizable><BackgroundImageUri>/CanvasApps/${appLogicalName}_BackgroundImageUri</BackgroundImageUri><DocumentUri>/CanvasApps/$appFile</DocumentUri>
</CanvasApp>
"@
[IO.File]::WriteAllText((Join-Path $appFolder ($appLogicalName + '.meta.xml')), $appXml, $utf8)

$customPath = Join-Path $stage.Solution 'Other/Customizations.xml'
[xml]$custom = Get-Content -LiteralPath $customPath -Raw
if (-not $custom.SelectSingleNode('//CanvasApps')) { $null = $custom.DocumentElement.AppendChild($custom.CreateElement('CanvasApps')); $custom.Save($customPath) }
Set-SolutionRootComponents -Automation $automation -SolutionPath $stage.Solution -IncludeCanvasApp
$package = Join-Path $root ("artifacts/{0}-with-app.zip" -f $automation.solution.uniqueName)
& $pac solution pack --folder $stage.Solution --zipfile $package --packagetype Unmanaged
if ($LASTEXITCODE -ne 0) { throw 'Fallo el empaquetado de la solucion.' }
Write-Output "Paquete generado: $package"
