# Prueba minima: Power Apps -> Power Automate -> Power Apps

Primero instala y verifica `pac` siguiendo el [README del proyecto](../../README.md).

Objetivo: pulsar un boton, enviar un texto sintetico y recibir `OK`, el mismo
texto, el ID de ejecucion y la fecha UTC. La prueba acredita la conexion y la
ejecucion del flujo. Cada automatizacion futura podra agregar sus conectores
y acciones sobre esta base.

## Estado de los entregables

Ya se creo el flujo `AutomatizacionPruebaConexion` en Personal Productivity,
mediante la importacion de `AutomationConnectionTest` con pac. La lectura
remota confirmo su activacion y su definicion. Tambien se creo y publico la
app canvas `AutomatizacionPrueba`. Su referencia apunta al flujo correcto.
Para probarla en Personal Productivity abre la app desde el portal Power Apps
y pulsa **Probar flujo**. La version generada envia `PRUEBA-<GUID>` distinto
en cada llamada. Debe mostrar `OK`, ese mismo mensaje, el ID y la fecha UTC.
El usuario ejecuto el boton y confirmo `OK` el 5 de octubre de 2026.
Esa confirmacion valida la llamada de extremo a extremo de esta prueba.

- `flow.clientdata.json`: definicion para crear el flujo mediante Dataverse.
- `app.es.powerfx`: formulas de cada propiedad de una app canvas con controles clasicos.
- `app.en.powerfx`: las mismas formulas para un editor con separador decimal punto.
- `Deploy-SmokeTest.ps1`: valida localmente o crea y activa el flujo en una
  solucion existente de desarrollo cuando se proporcionan acceso y entorno.

La carpeta `canvas/` contiene las fuentes de la version nativa con controles
modernos; `Build-CanvasTest.ps1` genera su `.msapp` y el ZIP de solucion en
las carpetas locales de construccion. Los archivos `app.*.powerfx` son una
alternativa manual con entrada de texto y controles clasicos. La importacion
correcta no acredita una ejecucion real del boton.

El generador usa controles y estructura de un ejemplo publico de
[Microsoft d365cc-fde](https://github.com/microsoft/d365cc-fde/tree/2498292232d1e265c9e3eea8445290fc20b74a01/tools/ai-disposition-codes/solution/CanvasApps),
con version y SHA-256 fijos. Genera una app nueva; conserva solo los controles
Button y Text de Microsoft y reemplaza pantallas, fuentes de datos y conexiones.
No incluye las acciones ni las dependencias del caso de uso original.

## Crear la prueba sin Dataverse

Necesitas una cuenta con acceso a Power Apps y Power Automate y permiso para
crear una app canvas y un flujo. No necesitas crear una base de datos Dataverse
para esta ruta. Si tu organizacion ha restringido estos permisos, el administrador
debe habilitar un entorno de prueba; instalar pac no concede acceso.

1. Abre https://make.powerapps.com e identifica el entorno seleccionado.
   Abre https://make.powerautomate.com y selecciona **el mismo entorno**.
2. En Power Automate, crea un **flujo de nube instantaneo** llamado
   `AutomatizacionPruebaConexion`, con disparador **Power Apps (V2)**
   (puede aparecer como **Cuando Power Apps llama a un flujo (V2)**).
3. En el disparador, agrega una entrada de tipo **Texto** llamada `Mensaje`.
   Debe ser la primera y unica entrada de la prueba.
4. Agrega **Responder a Power Apps o a un flujo**. Configura estas cuatro
   salidas, todas de tipo **Texto**. Escribe los nombres en minusculas:

   | Nombre | Valor |
   | --- | --- |
   | `estado` | Texto literal `OK` |
   | `mensaje` | Contenido dinamico `Mensaje` del disparador |
   | `ejecucionid` | Expresion `workflow()?['run']?['name']` |
   | `fechautc` | Expresion `utcNow()` |

   En la pestana de expresiones se pegan las expresiones sin `@` inicial.
5. Guarda el flujo y verifica que este activado.
6. En Power Apps crea una **app de lienzo en blanco**, formato telefono,
   llamada `AutomatizacionPrueba`. Agrega estos **controles clasicos**:

   | Tipo | Nombre del control | Posicion sugerida X / Y / ancho / alto |
   | --- | --- | --- |
   | Etiqueta | `lblTitulo` | 24 / 24 / 590 / 60 |
   | Entrada de texto | `txtMensaje` | 24 / 100 / 590 / 60 |
   | Boton | `btnProbar` | 24 / 185 / 590 / 60 |
   | Etiqueta | `lblResultado` | 24 / 280 / 590 / 420 |

   Define `lblTitulo.Text` como `"Prueba de conexion de automatizaciones"`.
   Define `lblResultado.AutoHeight` como `true`.
7. Desde el panel **Power Automate** de Power Apps Studio, agrega el flujo
   `AutomatizacionPruebaConexion`. Este paso crea la referencia necesaria para `.Run()`.
8. Copia cada formula de `app.es.powerfx` a la propiedad indicada en su
   comentario. Los comentarios son separadores; no pegues todo el archivo
   en una sola propiedad. Si tu editor usa comas entre argumentos, usa
   `app.en.powerfx`. Usa el nombre real de la referencia si Studio lo cambia.
9. Guarda la app. Abre la vista previa (Play) y ejecuta la prueba.

## Como comprobar que funciona

1. Escribe `PRUEBA-001` y pulsa **Probar flujo**.
2. La etiqueta debe mostrar `Estado: OK`, `Mensaje: PRUEBA-001`, un ID de
   ejecucion no vacio y una fecha UTC.
3. Abre el historial del flujo en Power Automate. Localiza esa ejecucion y
   verifica que el disparador recibio `PRUEBA-001` y la respuesta lo devolvio.
4. Repite con `PRUEBA-002`: el texto debe cambiar y el ID debe ser diferente.
5. Deja el texto vacio: el boton debe estar deshabilitado.
6. Para probar el error, apaga temporalmente **este flujo de prueba**, pulsa
   el boton y espera la respuesta de error. La app debe mostrar `ERROR` y
   habilitar nuevamente el boton. Vuelve a activar el flujo al terminar.

Si no aparece el flujo, comprueba entorno y propietario. Si no reconoce
`.Run()` o las salidas, actualiza la referencia desde el panel Power Automate;
si persiste, quitala y agregala nuevamente, y revisa las formulas afectadas.

## Ruta opcional por codigo (requiere Dataverse)

Comprobacion local desde la raiz del repositorio, sin autenticacion:

```powershell
& ./examples/smoke-test/Deploy-SmokeTest.ps1
```

Para crear el flujo por codigo se requiere una solucion **no administrada**
existente, su nombre unico, la URL base Dataverse y una sesion autorizada.
Esta ruta usa la API documentada de Dataverse; no necesita pac instalado.
Puedes obtener el token con `Az.Accounts`, si tu organizacion permite este
cliente. El inicio de sesion es interactivo; no compartas el token en el chat.

```powershell
# Solo si el modulo no esta instalado y esta permitido por tu organizacion:
Install-Module Az.Accounts -Scope CurrentUser -Repository PSGallery
Connect-AzAccount -Tenant '<ID-DEL-TENANT>'
$dataverseUrl = 'https://<ORGANIZACION>.crm.dynamics.com'
$auth = Get-AzAccessToken -ResourceUrl $dataverseUrl
# Versiones recientes devuelven SecureString; normalizar versiones anteriores.
$secureToken = if ($auth.Token -is [Security.SecureString]) {
    $auth.Token
} else {
    ConvertTo-SecureString $auth.Token -AsPlainText -Force
}
& ./examples/smoke-test/Deploy-SmokeTest.ps1 -Publish `
    -EnvironmentUrl $dataverseUrl `
    -SolutionUniqueName '<NOMBRE_UNICO_SOLUCION>' `
    -AccessToken $secureToken
Remove-Variable auth,secureToken -ErrorAction SilentlyContinue
```

El script crea un flujo con ID estable, lo agrega a la solucion, lo activa y
lee su estado. En una segunda ejecucion reutiliza el flujo marcado como esta
prueba sin reemplazar su definicion. Si falla despues de crear el flujo,
conserva su ID para recuperar el despliegue parcial. La creacion remota y
la aceptacion de la definicion deben verificarse en el entorno real.

Luego crea la app con los pasos 6 a 9 anteriores. Una vez que existan ambos
componentes, agregalos a la misma solucion para exportarlos con pac:

```powershell
pac auth create --environment 'https://<ORGANIZACION>.crm.dynamics.com'
pac solution export --name '<NOMBRE_UNICO_SOLUCION>' --path '<RUTA_LOCAL>/prueba.zip' --managed false
pac solution unpack --zipfile '<RUTA_LOCAL>/prueba.zip' --folder '<RUTA_LOCAL>/prueba'
```

Mantener las exportaciones del entorno corporativo en una ubicacion local
autorizada fuera de Git. No contienen los mismos controles que los archivos
genericos de esta carpeta hasta que se hayan creado en el entorno.

## Siguiente integracion

Despues de aprobar esta prueba, definir el contrato de entrada y salida de
la automatizacion elegida y agregar sus conectores, acciones y rutas de error.
La prueba actual valida exclusivamente la llamada entre la app y el flujo.

Referencias oficiales:

- [Invocar un flujo desde una app canvas](https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/how-to/trigger-flow).
- [Crear y activar flujos con codigo](https://learn.microsoft.com/en-us/power-automate/manage-flows-with-code).
- [Comandos pac solution](https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/solution).
