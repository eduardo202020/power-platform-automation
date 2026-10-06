[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'AutomationConfig.psm1') -Force
$spec = Get-Content (Join-Path $root 'docs/automation-spec.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$automation = Get-AutomationConfig -Path $spec.automationConfig -Root $root
foreach ($configFile in (Get-ChildItem -LiteralPath (Join-Path $root 'config/automations') -Filter '*.json' -File)) {
    $rootPrefix = ([IO.Path]::GetFullPath($root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar)
    $relativePath = $configFile.FullName.Substring($rootPrefix.Length).Replace('\', '/')
    $candidate = Get-AutomationConfig -Path $relativePath -Root $root -AllowTemplate
    if (-not $candidate.isTemplate -and $candidate.automationId -ne $automation.automationId) {
        if ($candidate.solution.uniqueName -eq $automation.solution.uniqueName -or
            $candidate.flow.workflowId -eq $automation.flow.workflowId -or
            $candidate.app.logicalName -eq $automation.app.logicalName -or
            $candidate.app.manifestId -eq $automation.app.manifestId -or
            $candidate.app.connectionId -eq $automation.app.connectionId) {
            throw "La configuracion '$relativePath' reutiliza una identidad estable del piloto."
        }
    }
}
$flow = Get-Content (Resolve-RepositoryPath -Root $root -Path $automation.sources.flow -MustExist) -Raw -Encoding UTF8 | ConvertFrom-Json
$trigger = $flow.properties.definition.triggers.manual
if ($trigger.type -ne $spec.contract.triggerType -or $trigger.kind -ne $spec.contract.triggerKind) { throw 'El disparador difiere del contrato.' }
$inputKey = $spec.contract.input.key
if ($trigger.inputs.schema.properties.$inputKey.type -ne $spec.contract.input.type -or $inputKey -notin $trigger.inputs.schema.required) { throw 'La entrada requerida difiere del contrato.' }
$response = $flow.properties.definition.actions.Responder_a_Power_Apps
if ($response.type -ne $spec.contract.responseType -or $response.kind -ne $spec.contract.responseKind -or $response.inputs.statusCode -ne $spec.contract.statusCode) { throw 'La respuesta difiere del contrato.' }
$expectedOutputs = @($spec.contract.outputs.PSObject.Properties.Name | Sort-Object)
$actualOutputs = @($response.inputs.schema.properties.PSObject.Properties.Name | Sort-Object)
if (Compare-Object $expectedOutputs $actualOutputs) { throw 'Las salidas del flujo difieren del contrato.' }
$screen = Get-Content (Join-Path (Resolve-RepositoryPath -Root $root -Path $automation.sources.canvasDirectory -MustExist) 'Screen1.fx.yaml') -Raw -Encoding UTF8
$app = Get-Content (Join-Path (Resolve-RepositoryPath -Root $root -Path $automation.sources.canvasDirectory -MustExist) 'App.fx.yaml') -Raw -Encoding UTF8
foreach ($field in $expectedOutputs) {
    if ($response.inputs.schema.properties.$field.type -ne $spec.contract.outputs.$field -or $field -notin $response.inputs.body.PSObject.Properties.Name) { throw "Salida inconsistente: $field" }
    if ($screen -notmatch ('varResultado\.' + [regex]::Escape($field) + '\b') -or $app -notmatch ('\b' + [regex]::Escape($field) + '\s*:')) { throw "La app no consume/inicializa la salida: $field" }
}
if ($screen -notmatch ([regex]::Escape($automation.flow.displayName) + '\.Run\(')) { throw 'La app llama a una fuente distinta.' }
$solutionPath = Join-Path (Resolve-RepositoryPath -Root $root -Path $automation.sources.solutionTemplate -MustExist) 'Other/Solution.xml'
[xml]$solution = Get-Content $solutionPath -Raw
if ($solution.ImportExportXml.SolutionManifest.UniqueName -ne $automation.solution.uniqueName) { throw 'Nombre unico de solucion inconsistente.' }
$flowComponent = @($solution.SelectNodes('//RootComponent[@type="29"]') | Where-Object { $_.id.Trim('{}') -eq $automation.flow.workflowId })
if ($flowComponent.Count -ne 1) { throw 'El manifest no contiene exactamente el flujo del contrato.' }
foreach ($scriptName in @('Build-CanvasTest.ps1', 'Build-ConnectionTest.ps1', 'Verify-ConnectionTest.ps1')) {
    $scriptContent = Get-Content (Join-Path $root "scripts/$scriptName") -Raw -Encoding UTF8
    if ($scriptContent -match '6e19f7d8-3550-48c2-a4d6-e9764302e973|5ff47c3f-6729-4fed-867a-682f1b04d639') {
        throw "$scriptName conserva una identidad remota fijada del piloto."
    }
}
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
Write-Output 'Harness valido: configuraciones, contrato, fuentes Power Fx, manifest, skill, enlaces y sintaxis PowerShell. Sin llamadas remotas.'
