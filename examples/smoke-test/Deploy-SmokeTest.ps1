[CmdletBinding()]
param(
    [switch]$Publish,
    [uri]$EnvironmentUrl,
    [string]$SolutionUniqueName,
    [Security.SecureString]$AccessToken
)

$ErrorActionPreference = 'Stop'
$flowId = '6e19f7d8-3550-48c2-a4d6-e9764302e973'
$flowName = 'AutomatizacionPruebaConexion'
$marker = 'power-platform-automation/smoke-test/v1'
$clientData = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'flow.clientdata.json') -Raw -Encoding UTF8
$definition = $clientData | ConvertFrom-Json
if ($definition.properties.definition.triggers.manual.kind -ne 'PowerAppV2') {
    throw 'El flujo debe tener un disparador Power Apps V2.'
}
$payload = @{
    workflowid = $flowId
    category = 5
    name = $flowName
    type = 1
    primaryentity = 'none'
    description = $marker
    clientdata = $clientData
}
$payloadJson = $payload | ConvertTo-Json -Depth 100
if (-not $Publish) {
    # Comprobacion local: no crea archivos ni realiza llamadas a Microsoft.
    $roundTrip = ($payloadJson | ConvertFrom-Json).clientdata | ConvertFrom-Json
    if ($roundTrip.properties.definition.actions.Responder_a_Power_Apps.inputs.body.estado -ne 'OK') {
        throw 'Respuesta de prueba invalida.'
    }
    Write-Output 'Definicion y payload Dataverse validos como JSON. Despliegue remoto pendiente.'
    return
}
if (-not $EnvironmentUrl -or -not $SolutionUniqueName -or -not $AccessToken) {
    throw 'Publish requiere EnvironmentUrl, SolutionUniqueName y AccessToken (SecureString).'
}
if ($EnvironmentUrl.Scheme -ne 'https' -or $EnvironmentUrl.AbsolutePath -ne '/' -or
    $EnvironmentUrl.Query -or $EnvironmentUrl.Fragment -or $EnvironmentUrl.UserInfo) {
    throw 'Usa la URL base HTTPS del entorno Dataverse, sin rutas ni parametros.'
}
if ($SolutionUniqueName -notmatch '^[A-Za-z][A-Za-z0-9_]*$') {
    throw 'Nombre unico de solucion invalido.'
}
$base = $EnvironmentUrl.AbsoluteUri.TrimEnd('/') + '/api/data/v9.2'
$tokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken)
try {
    $headers = @{
        Authorization = 'Bearer ' + [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPointer)
        Accept = 'application/json'
        'OData-MaxVersion' = '4.0'
        'OData-Version' = '4.0'
    }
    function Invoke-Dataverse {
        param([string]$Method, [string]$Path, [object]$Body)
        $request = @{
            Method = $Method
            Uri = "$base/$Path"
            Headers = $headers
            ErrorAction = 'Stop'
        }
        if ($null -ne $Body) {
            $request.ContentType = 'application/json; charset=utf-8'
            $request.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 100))
        }
        Invoke-RestMethod @request
    }
    # Resolver la solucion ANTES de crear el flujo. No crea soluciones ni editores.
    $solution = Invoke-Dataverse GET "solutions?`$select=solutionid,ismanaged&`$filter=uniquename eq '$SolutionUniqueName'" $null
    if ($solution.value.Count -ne 1 -or $solution.value[0].ismanaged) {
        throw 'Se requiere una solucion existente no administrada en el entorno de desarrollo.'
    }
    $existing = Invoke-Dataverse GET "workflows?`$select=workflowid,name,description,statecode&`$filter=workflowid eq $flowId" $null
    if ($existing.value.Count -gt 0) {
        if ($existing.value[0].description -ne $marker -or $existing.value[0].name -ne $flowName) {
            throw 'El identificador pertenece a otro flujo; no se modificara.'
        }
        # Una segunda ejecucion recupera un despliegue parcial sin crear duplicados.
        # No reemplaza ni apaga un flujo existente.
        Write-Output "Flujo de prueba existente: $flowId"
    } else {
        $null = Invoke-Dataverse POST 'workflows' $payload
        Write-Output "Flujo de prueba creado (apagado): $flowId"
    }
    $solutionId = $solution.value[0].solutionid
    $membership = Invoke-Dataverse GET "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $solutionId and objectid eq $flowId and componenttype eq 29" $null
    if ($membership.value.Count -eq 0) {
        $null = Invoke-Dataverse POST 'AddSolutionComponent' @{
            ComponentId = $flowId
            ComponentType = 29
            SolutionUniqueName = $SolutionUniqueName
            AddRequiredComponents = $false
        }
    }
    $null = Invoke-Dataverse PATCH "workflows($flowId)" @{ statecode = 1 }
    $verified = Invoke-Dataverse GET "workflows($flowId)?`$select=workflowid,name,statecode,clientdata" $null
    if ($verified.statecode -ne 1) { throw 'El flujo no quedo activado.' }
    $remoteData = $verified.clientdata | ConvertFrom-Json
    if ($remoteData.properties.definition.triggers.manual.kind -ne 'PowerAppV2') {
        throw 'La definicion remota no coincide con la prueba esperada.'
    }
    Write-Output "Verificado: $($verified.name), activado, ID $flowId. Falta ejecutarlo desde la app."
} finally {
    if ($headers) { $headers.Clear() }
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPointer)
}
