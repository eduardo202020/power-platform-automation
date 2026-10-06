# Runbook de construccion y validacion

Los comandos parten de la raiz del proyecto. Este runbook reproduce el piloto;
no autoriza ejecutarlo sobre cualquier entorno. Usar el entorno indicado por
el usuario y la autorizacion vigente. Elegir nuevas identidades para otro caso.

## Preparacion y autenticacion

```powershell
& ./scripts/Install-Pac.ps1
pac help
pac auth list
pac env list
pac env select --environment '<ID_ENTORNO>'
```

Solo si no existe una sesion util: `pac auth create --name AutomatizacionesDev
--deviceCode`. El usuario completa el login Microsoft. Una sesion existente
no demuestra permisos de escritura; el piloto los comprobo mediante importacion.
No imprimir `pac auth token`: su audiencia observada es Power Platform API,
no Dataverse. La ruta que funciono usa pac solution import y su sesion existente.

## Primera construccion: flujo antes que app

Las fuentes de solucion ya existen en el repositorio. `pac solution init` se
uso inicialmente con publisher AutomationLab y prefijo autolab; no repetirlo
sobre esta carpeta existente. Inicializar otra carpeta para un proyecto nuevo.

```powershell
# Crear una configuracion de entorno local, excluida de Git.
Copy-Item ./config/environments/development.example.json ./config/environments/development.local.json
# Editar development.local.json con el entorno autorizado.

# Fase 1: paquete e importacion del flujo.
powershell -ExecutionPolicy Bypass -File ./scripts/Build-ConnectionTest.ps1 `
  -AutomationConfig config/automations/smoke-test.json
pac solution import --environment '<ID_ENTORNO>' --path './artifacts/AutomationConnectionTest.zip'
pac env fetch --environment '<ID_ENTORNO>' --xmlFile './examples/smoke-test/verify-flow.fetch.xml'

# Fase 2: la construccion consulta el flujo YA existente en ese entorno.
powershell -ExecutionPolicy Bypass -File ./scripts/Build-CanvasTest.ps1 `
  -AutomationConfig config/automations/smoke-test.json `
  -EnvironmentConfig config/environments/development.local.json
pac solution import --environment '<ID_ENTORNO>' --path './artifacts/AutomationConnectionTest-with-app.zip'
```

El generador canvas descarga una plantilla publica Microsoft fijada por commit
y verifica SHA-256 antes de desempaquetarla. Selecciona solo Button/Text;
genera pantallas propias, Connections, DataSource y WADL. Empaqueta `.msapp`
y agrega el componente canvas a la solucion. `BackgroundImageUri` y
`DocumentUri` deben apuntar a archivos presentes; omitir el primero provoco
un fallo de empaquetado que se corrigio con un icono generado.

El primer import produjo inicialmente Draft durante el procesamiento y luego
Activated. Esperar la finalizacion y leer el estado; no asumir fallo ni lanzar
reimportaciones mientras el proceso siga activo.

## Actualizacion de una construccion existente

Editar las fuentes canonicas y la configuracion de automatizacion, luego
reconstruir. Los scripts trabajan sobre una copia en `artifacts/build/` y
sustituyen solamente los componentes flujo/app de esa copia. Para recuperar el
paquete combinado tras ejecutar el primero, ejecutar tambien el segundo.
Inspeccionar el manifest generado antes de importar; los componentes fuera del
alcance del piloto se conservan en la copia, pero esa conducta debe volver a
probarse antes de ampliar una solucion real.

Una reimportacion puede reemplazar la definicion activa del flujo existente.
La version no aumenta automaticamente. Conservar un export previo cuando el
cambio de una app existente lo justifique; no importar para un cambio de docs.

## Verificacion

```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/Validate-Harness.ps1
powershell -ExecutionPolicy Bypass -File ./scripts/Verify-ConnectionTest.ps1 `
  -AutomationConfig config/automations/smoke-test.json `
  -EnvironmentConfig config/environments/development.local.json
```

`Verify` consulta el ID real de app mediante FetchXML filtrado por el nombre
logico configurado; `-AppId` queda disponible como alternativa puntual.
Comprueba Published y los dos IDs de referencia. No abre el reproductor ni pulsa botones.
Abrir la app, pulsar Probar flujo y registrar OK o error. Contrastar mensaje,
fecha e ID con el historial si estan disponibles. Un historial CLI vacio no
desmiente una prueba de UI confirmada.

## Portabilidad actual

La version de pac y las identidades viven en la configuracion de automatizacion.
La region WADL, ruta opcional de pac y destino viven en la configuracion de
entorno local. Revisar ambos archivos antes de construir otro caso o region.

`Deploy-SmokeTest.ps1` es una alternativa Dataverse que requiere solucion
existente y token de audiencia correcta; no fue la ruta usada en el piloto.
El formato SourceCode rechazo la plantilla por DocVersion 1.347 inferior al
minimo 1.348; Experimental funciono. No alterar una version de documento para
simular compatibilidad. Evaluar el soporte oficial antes de cambiar tooling.

Referencias oficiales para verificar cambios del producto:

- [Comandos de soluciones](https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/solution).
- [Canvas: pack/unpack obsoletos](https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/canvas).
- [Flujos mediante codigo](https://learn.microsoft.com/en-us/power-automate/manage-flows-with-code).
