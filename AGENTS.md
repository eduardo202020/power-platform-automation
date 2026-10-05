# Instrucciones para agentes

Este proyecto construye automatizaciones Power Platform desde codigo. Es
independiente de `auto-tasacion` y de `auto-automatizaciones`; sus instrucciones
y reglas de negocio no se heredan aqui. El piloto prueba una app canvas y un
flujo cloud. No ejecuta operaciones financieras, PAD ni IBM.

## Entrada al contexto

Lee [README.md](README.md), [docs/AI_CONTEXT.md](docs/AI_CONTEXT.md) y el
contrato [docs/INTERACTION_CONTRACT.md](docs/INTERACTION_CONTRACT.md).
Para construir, importar o diagnosticar, lee la skill local
[skills/power-platform-build/SKILL.md](skills/power-platform-build/SKILL.md).
El detalle de comandos esta en [docs/BUILD_RUNBOOK.md](docs/BUILD_RUNBOOK.md).
Para planificar o retomar mejoras, consulta
[docs/FEATURE_ROADMAP.md](docs/FEATURE_ROADMAP.md): distingue pendientes de
capacidades implementadas y no autoriza despliegues por sí mismo.

## Fuentes y cambios

- Logica del flujo: `examples/smoke-test/flow.clientdata.json`.
- App publicada: `examples/smoke-test/canvas/*.fx.yaml`, controles modernos.
- `app.es.powerfx` y `app.en.powerfx`: alternativa manual de controles clasicos;
  no son las fuentes de la app publicada.
- `scripts/Build-*.ps1`: generan metadatos y paquetes. Un cambio al contrato
  puede requerir actualizar el WADL de `Build-CanvasTest.ps1`.
- `solutions/AutomationConnectionTest/src`: manifest y componentes de solucion;
  incluye archivos generados. No corregir la logica solo en esas copias.
- `artifacts/`: paquetes y fuentes temporales, excluidos de Git.

## Invariantes de integracion

1. La app y el flujo se resuelven en el mismo entorno explicitamente elegido.
2. `workflowId` es el ID Dataverse; `resourceId` es el ID Power Automate.
   Vincular `workflowEntityId` al primero y `workflowName` al segundo.
   Consultar los IDs remotos; no inferirlos por el nombre visible.
3. Crear/importar primero el flujo y luego construir la app: el generador
   consulta el recurso remoto. Una construccion completamente offline de la
   app no esta implementada.
4. Un import correcto no prueba el boton. Distinguir estado publicado,
   referencia verificada, resultado confirmado por usuario y prueba automatica.
5. `list-flow-runs` vacio no prueba ausencia de ejecuciones ni un fallo.
6. Los IDs fijos de este piloto sirven para actualizarlo. Para una nueva
   automatizacion elegir nuevas identidades; no sobrescribir este ejemplo.

## Autonomia y alcance

La documentacion historica no autoriza nuevas importaciones. Ejecutar las
mutaciones necesarias cuando esten comprendidas en la solicitud actual o en
la autorizacion vigente; no pedir otra confirmacion por rutina. La lectura y
la construccion local permiten preparar resultados revisables. No extender
una prueba de desarrollo a operaciones financieras ni a otros entornos.

No imprimir tokens, codigos de login ni entradas de clientes. `pac auth token`
devuelve un token para Power Platform API; no tratarlo como token Dataverse.
No volcar listados completos del tenant: consultar el componente del piloto.

## Verificacion y cierre

Ejecuta `scripts/Validate-Harness.ps1` tras cambios de contrato o del harness.
Para cambios desplegados, usa `scripts/Verify-ConnectionTest.ps1` con el entorno
y AppId correctos. Registra evidencia y limites en `docs/TEST_RESULTS.md`.
No reimportes ni repitas pruebas remotas por un cambio exclusivamente documental.

Los generadores actuales fijan pac 2.12.2, nombres del piloto y endpoint WADL
europeo. `pac canvas pack/unpack` Experimental esta obsoleto. Su funcionamiento
en este piloto no demuestra portabilidad ni idoneidad para produccion.
