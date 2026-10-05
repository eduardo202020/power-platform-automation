---
name: power-platform-build
description: Construir, actualizar y diagnosticar la app canvas y el flujo cloud del proyecto power-platform-automation con pac, manteniendo contratos e IDs correctos y verificando publicacion e interaccion. Usar para continuar este harness; no para operar PAD ni ejecutar procesos financieros.
---

# Construir e integrar Power Apps y Power Automate

Skill local del proyecto, descubierta mediante AGENTS.md. No requiere ni
presupone instalacion global. Resolver enlaces desde esta carpeta.

Lee [contexto](../../docs/AI_CONTEXT.md) y
[contrato](../../docs/INTERACTION_CONTRACT.md). Para construir/importar usa
[runbook](../../docs/BUILD_RUNBOOK.md); para incidencias usa
[diagnostico](../../docs/TROUBLESHOOTING.md). No cargar exportaciones completas
del entorno para adquirir contexto.

## Decisiones que preservan el flujo

- Elegir la tarea: docs, cambio local, consulta remota o importacion autorizada.
  No convertir una solicitud de documentacion en un nuevo despliegue.
- Modificar JSON de ejemplo y YAML canvas como fuentes de logica; los metadatos
  y paquetes se regeneran. Las formulas clasicas son una ruta alternativa.
- Flujo remoto antes de app: el builder necesita consultar workflowId y
  resourceId. Una conexion usa workflowEntityId para el primero y workflowName
  para el segundo. No usar el mismo GUID para ambas propiedades.
- Si cambia la firma Run, alinear trigger, respuesta, record Power Fx, WADL
  y automation-spec.json. Validar con Validate-Harness antes de importar.
- Los scripts son especificos del piloto. Para otro proceso separar fuentes,
  nombres e identidades; verificar region y version de pac. No copiar los IDs
  del piloto a una automatizacion distinta.
- Tras una importacion leer publicacion y referencias. La prueba del boton
  es una comprobacion separada y puede requerir confirmacion del usuario.
  Un estado Published no demuestra ejecucion. Historial CLI vacio no demuestra
  fallo. Registrar el origen de cada evidencia en TEST_RESULTS.md.
- Diagnosticar una app ausente en la lista antes de recrearla: el piloto tuvo
  una incidencia de visibilidad que desaparecio sin mutacion adicional.

## Limites operativos

Respetar la autorizacion vigente sin pedir confirmaciones rutinarias. No ampliar
el entorno, componentes ni operaciones de la tarea. No imprimir credenciales
ni tokens; la sesion pac basta para la ruta de importacion comprobada.

No reimportar en bucle: ante un rechazo revisar causa y estado remoto; corregir
el paquete concreto si corresponde. Si requiere permisos o autenticacion que
no estan disponibles, explicar lo que falta y conservar el resultado local.

El empaquetador canvas Experimental esta obsoleto: funciono en este piloto,
pero no garantiza otro formato o version. Mantener esa limitacion visible.
