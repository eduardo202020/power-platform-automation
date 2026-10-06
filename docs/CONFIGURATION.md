# Configuración de automatizaciones

La identidad funcional de una automatización y la ubicación donde se ejecuta
son configuraciones diferentes. Esta separación permite preparar otro ejemplo
sin copiar GUIDs, nombres ni datos de un entorno anterior.

## Configuración de automatización

Los archivos de `config/automations/` se versionan y no contienen secretos.
Cada uno define:

- solución, publisher, prefijo y versión;
- nombre e `workflowId` estable del flujo;
- nombre lógico, identificador de manifiesto e identificador local de conexión
  de la app;
- fuentes reutilizables y versión de `pac` requerida.

`smoke-test.json` representa el piloto publicado. `smoke-test-secondary.json`
demuestra una segunda identidad independiente. Ambos usan las mismas fuentes
de ejemplo, pero los generadores reemplazan la referencia del flujo dentro de
una copia de trabajo en `artifacts/build/`; las fuentes del piloto no se
modifican.

Para iniciar una automatización, copia `automation.template.json`, asigna
identidades nuevas y cambia `isTemplate` a `false`. Los GUID de flujo, app y
conexión deben ser distintos de toda automatización existente.

## Configuración de entorno

`config/environments/development.example.json` es una plantilla segura.
Copiarla, por ejemplo, a `config/environments/development.local.json`, y
completar únicamente:

- `environmentId`: GUID o URL HTTPS base del entorno autorizado;
- `region`: región usada para el endpoint WADL del conector de flujos;
- `pacPath`: ruta opcional de `pac.exe`; en blanco usa la versión definida por
  la automatización bajo `%LOCALAPPDATA%`.

Los archivos `*.local.json` están excluidos de Git. No guardar tokens,
credenciales ni resultados de consultas de Microsoft en ellos.

## Construir y verificar

```powershell
# Validación local de todas las configuraciones versionadas.
powershell -ExecutionPolicy Bypass -File ./scripts/Validate-Harness.ps1

# Empaqueta solo el flujo de una configuración, sin importar nada.
powershell -ExecutionPolicy Bypass -File ./scripts/Build-ConnectionTest.ps1 `
  -AutomationConfig config/automations/smoke-test-secondary.json

# Requiere que el flujo de esa configuración ya exista en el entorno.
powershell -ExecutionPolicy Bypass -File ./scripts/Build-CanvasTest.ps1 `
  -AutomationConfig config/automations/smoke-test.json `
  -EnvironmentConfig config/environments/development.local.json

# Resuelve el AppId por nombre lógico si no se proporciona -AppId.
powershell -ExecutionPolicy Bypass -File ./scripts/Verify-ConnectionTest.ps1 `
  -AutomationConfig config/automations/smoke-test.json `
  -EnvironmentConfig config/environments/development.local.json
```

`Build-CanvasTest.ps1` consulta el flujo en Microsoft para obtener su
`resourceId`. `Verify-ConnectionTest.ps1` consulta la app por nombre lógico.
Ambas operaciones son de lectura hasta que se ejecute explícitamente un
`pac solution import` separado.
