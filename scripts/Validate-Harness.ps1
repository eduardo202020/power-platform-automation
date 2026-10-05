[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$spec = Get-Content (Join-Path $root 'docs/automation-spec.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($source in $spec.sources.PSObject.Properties.Value) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $source) -PathType Leaf)) { throw "Fuente ausente: $source" }
}
$flow = Get-Content (Join-Path $root $spec.sources.flow) -Raw -Encoding UTF8 | ConvertFrom-Json
$trigger = $flow.properties.definition.triggers.manual
if ($trigger.type -ne $spec.contract.triggerType -or $trigger.kind -ne $spec.contract.triggerKind) { throw 'El disparador difiere del contrato.' }
$inputKey = $spec.contract.input.key
if ($trigger.inputs.schema.properties.$inputKey.type -ne $spec.contract.input.type -or $inputKey -notin $trigger.inputs.schema.required) { throw 'La entrada requerida difiere del contrato.' }
$response = $flow.properties.definition.actions.Responder_a_Power_Apps
if ($response.type -ne $spec.contract.responseType -or $response.kind -ne $spec.contract.responseKind -or $response.inputs.statusCode -ne $spec.contract.statusCode) { throw 'La respuesta difiere del contrato.' }
$expectedOutputs = @($spec.contract.outputs.PSObject.Properties.Name | Sort-Object)
$actualOutputs = @($response.inputs.schema.properties.PSObject.Properties.Name | Sort-Object)
if (Compare-Object $expectedOutputs $actualOutputs) { throw 'Las salidas del flujo difieren del contrato.' }
$screen = Get-Content (Join-Path $root $spec.sources.canvasScreen) -Raw -Encoding UTF8
$app = Get-Content (Join-Path $root $spec.sources.canvasApp) -Raw -Encoding UTF8
foreach ($field in $expectedOutputs) {
    if ($response.inputs.schema.properties.$field.type -ne $spec.contract.outputs.$field -or $field -notin $response.inputs.body.PSObject.Properties.Name) { throw "Salida inconsistente: $field" }
    if ($screen -notmatch ('varResultado\.' + [regex]::Escape($field) + '\b') -or $app -notmatch ('\b' + [regex]::Escape($field) + '\s*:')) { throw "La app no consume/inicializa la salida: $field" }
}
if ($screen -notmatch ([regex]::Escape($spec.identity.flowDisplayName) + '\.Run\(')) { throw 'La app llama a una fuente distinta.' }
$solutionPath = Join-Path $root 'solutions/AutomationConnectionTest/src/Other/Solution.xml'
[xml]$solution = Get-Content $solutionPath -Raw
if ($solution.ImportExportXml.SolutionManifest.UniqueName -ne $spec.identity.solutionUniqueName) { throw 'Nombre unico de solucion inconsistente.' }
$flowComponent = @($solution.SelectNodes('//RootComponent[@type="29"]') | Where-Object { $_.id.Trim('{}') -eq $spec.identity.workflowId })
if ($flowComponent.Count -ne 1) { throw 'El manifest no contiene exactamente el flujo del contrato.' }
$skillPath = Join-Path $root 'skills/power-platform-build/SKILL.md'
$skill = Get-Content $skillPath -Raw -Encoding UTF8
if ($skill -notmatch '(?s)^---\r?\nname: power-platform-build\r?\ndescription: .+?\r?\n---') { throw 'Frontmatter de skill incompleto.' }
foreach ($md in (Get-ChildItem -LiteralPath $root -Filter '*.md' -Recurse | Where-Object { $_.FullName -notmatch '[\\/]artifacts[\\/]|[\\/]\.git[\\/]' })) {
    $content = Get-Content -LiteralPath $md.FullName -Raw -Encoding UTF8
    foreach ($match in [regex]::Matches($content, '\[[^\]]+\]\(([^\s)]+)\)')) {
        $target = $match.Groups[1].Value
        if ($target -match '^[a-zA-Z]+:|^#') { continue }
        $target = ($target -split '#')[0]
        if (-not (Test-Path -LiteralPath (Join-Path $md.DirectoryName $target))) { throw "Enlace roto en $($md.Name): $target" }
    }
}
foreach ($script in (Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -Filter '*.ps1')) {
    $errors = $null; $tokens = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($script.FullName,[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw "Sintaxis invalida: $($script.Name)" }
}
Write-Output 'Harness valido: contrato, fuentes Power Fx, manifest, skill, enlaces y sintaxis PowerShell. Sin llamadas remotas.'
