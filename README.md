# Construccion de automatizaciones con Power Platform

Proyecto independiente para construir, revisar y transportar automatizaciones
de Power Apps, Power Automate y PAD desde codigo, usando Power Platform CLI
(`pac`). Los ejemplos son genericos y no dependen de `auto-tasacion`.

El [registro de próximos features](docs/FEATURE_ROADMAP.md) conserva el orden
de evolución y los criterios de aceptación. La próxima tarea es parametrizar
identidades y entorno; las siguientes etapas todavía están pendientes.

## Contexto para agentes de IA

Empieza por [AGENTS.md](AGENTS.md) y [contexto operativo](docs/AI_CONTEXT.md).
El harness incluye un [runbook de construccion](docs/BUILD_RUNBOOK.md), el
[contrato app-flujo](docs/INTERACTION_CONTRACT.md),
[diagnostico](docs/TROUBLESHOOTING.md),
[especificacion legible por maquinas](docs/automation-spec.json) y una
[skill local](skills/power-platform-build/SKILL.md). La skill se descubre
desde AGENTS.md; no necesita una instalacion global.

```powershell
& ./scripts/Validate-Harness.ps1
```

Esta comprobacion valida coherencia local y enlaces sin tocar Microsoft.

## Estructura

```text
power-platform-automation/
  examples/smoke-test/    # Primera prueba: app -> flujo -> respuesta
  scripts/               # Instalacion y comprobacion local de pac
  solutions/             # Fuentes desempaquetadas de soluciones
  artifacts/             # Exportaciones locales, excluidas de Git
```

## 1. Instalar y comprobar pac

En este equipo se instalo y verifico **pac 2.12.2** el 5 de octubre de 2026.
La carpeta del ejecutable se agrego al PATH del usuario. Abre una terminal
nueva y ejecuta `pac help` para comprobarlo en tu sesion de VS Code.

La instalacion para este equipo utiliza la distribucion oficial
`Microsoft.PowerApps.CLI` de NuGet, descomprimida para el usuario actual.
El script comprueba la firma Microsoft del ejecutable antes de agregar su
carpeta al PATH del usuario. No necesita .NET SDK ni instala un MSI.

```powershell
& ./scripts/Install-Pac.ps1
pac help
```

Abre una terminal nueva si `pac` no se reconoce en una terminal ya abierta.
Si PowerShell bloquea los scripts, utiliza la instalacion de la extension
oficial Power Platform Tools de VS Code conforme a las politicas corporativas.
La distribucion Windows incluye las herramientas basadas en .NET Framework;
su ejecucion debe comprobarse en el equipo.

## 2. Conectar tu cuenta

La instalacion de pac es local. El acceso al tenant requiere que inicies
sesion con tu cuenta Microsoft autorizada:

```powershell
pac auth create --name AutomatizacionesDev --deviceCode
pac env list
```

Selecciona un entorno de desarrollo disponible. Estos comandos no crean un
entorno ni una base Dataverse. Si no tienes acceso a uno, necesitas habilitacion
del administrador o un entorno Developer conforme a los requisitos de Microsoft.
No pegues codigos de autenticacion ni tokens en el chat.

## 3. Ejecutar la primera prueba

El 5 de octubre de 2026 se importo con exito la solucion de prueba
`AutomationConnectionTest` en Personal Productivity. Se leyo desde Dataverse
el flujo `AutomatizacionPruebaConexion` y se verifico que esta activado, con
disparador Power Apps V2 y respuesta a Power Apps. Tambien se creo y publico
la app canvas `AutomatizacionPrueba` mediante una solucion importada con pac.
La API de Microsoft confirmo `Published` y la referencia al ID real del flujo.
El usuario ejecuto el boton y confirmo que la app muestra `OK`: la llamada
Power Apps -> Power Automate -> Power Apps funciona. Consulta los
[resultados de la prueba](docs/TEST_RESULTS.md) para distinguir la evidencia
de UI de las comprobaciones por API.

Las fuentes de la solucion estan en `solutions/AutomationConnectionTest/src`.
Para reconstruir el paquete local con la definicion del ejemplo:

```powershell
& ./scripts/Build-ConnectionTest.ps1
# El flujo debe existir remotamente antes de construir la app:
pac solution import --environment '<ID_ENTORNO>' --path './artifacts/AutomationConnectionTest.zip'
# Construir tambien la app nativa (resuelve el flujo en el entorno):
& ./scripts/Build-CanvasTest.ps1 -EnvironmentId '<ID_ENTORNO>'
```

Para importarlo en un entorno autorizado y verificar exclusivamente este flujo:

```powershell
pac solution import --environment '<ID_ENTORNO>' --path './artifacts/AutomationConnectionTest.zip'
pac env fetch --environment '<ID_ENTORNO>' --xmlFile './examples/smoke-test/verify-flow.fetch.xml'
# El paquete que incluye la app se importa por separado:
pac solution import --environment '<ID_ENTORNO>' --path './artifacts/AutomationConnectionTest-with-app.zip'
& ./scripts/Verify-ConnectionTest.ps1 -EnvironmentId '<ID_ENTORNO>'
```

Una reimportacion actualiza el flujo de prueba existente. No ejecutar contra
produccion ni usar nombres o IDs de otros flujos.

Sigue [examples/smoke-test/README.md](examples/smoke-test/README.md).
La app llama a `AutomatizacionPruebaConexion` y muestra el texto recibido,
`OK`, el ID de ejecucion y la fecha UTC. La guia incluye una ruta en el
disenador y otra para crear el flujo por la API de Dataverse.

La app generada incluye los controles y la referencia del flujo. El ejemplo
de formulas para controles clasicos se conserva como alternativa manual.
El generador nativo utiliza `pac canvas pack` en formato Experimental, una
funcion obsoleta que funciono para esta prueba y requiere validar el resultado
en el reproductor. No constituye una validacion de UI ni de ejecucion.

## 4. Mantener una solucion desde codigo

Con Dataverse disponible, crea una solucion no administrada de desarrollo,
agrega la app y el flujo de prueba, y utiliza su nombre unico:

```powershell
pac solution export --name '<NOMBRE_UNICO>' --path './artifacts/prueba.zip' --managed false
pac solution unpack --zipfile './artifacts/prueba.zip' --folder './solutions/prueba'
# Editar las fuentes y revisar los cambios.
pac solution pack --folder './solutions/prueba' --zipfile './artifacts/prueba-editada.zip'
# Importar exclusivamente en el entorno de desarrollo seleccionado:
pac solution import --environment '<ID_ENTORNO>' --path './artifacts/prueba-editada.zip'
```

`pac` administra soluciones; la definicion del flujo aporta su logica.
Las conexiones, permisos, politicas y licencias siguen perteneciendo al entorno.
Revisa las fuentes exportadas antes de agregarlas a Git: pueden contener URLs,
identificadores o valores propios del entorno. Usa datos sinteticos para pruebas.

Documentacion oficial:

- [Power Platform CLI](https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction).
- [Distribucion oficial Microsoft.PowerApps.CLI](https://www.nuget.org/packages/Microsoft.PowerApps.CLI).
- [Comandos de soluciones](https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/solution).
