# Diagnostico de construccion e interaccion

| Sintoma | Comprobacion | Accion proporcionada |
| --- | --- | --- |
| pac no se reconoce | PATH de usuario y terminal abierta antes de instalar | Abrir terminal nueva o usar ruta del ejecutable instalado |
| Sesion existe pero entorno no seleccionado | auth list / env list | Seleccionar explicitamente el entorno correcto |
| Build-Canvas no encuentra flujo | Consultar workflowId en ese entorno | Importar primero el paquete del flujo; no inventar resourceId |
| Error BackgroundImageUri al empaquetar | XML canvas y archivo del icono | Regenerar con Build-Canvas; mantener referencias a archivos presentes |
| SourceCode rechaza DocVersion 1.347 | Plantilla y minimo 1.348 informado por herramienta | El piloto uso Experimental; no falsear DocVersion |
| FetchXML falla con top y page | pac agrega paginacion | Evitar top en las consultas pac env fetch del piloto |
| Draft justo despues de crear | Import aun en curso | Esperar finalizacion y leer estado; no duplicar import |
| App en Soluciones pero no en Aplicaciones | Entorno, filtros, propietario, estado y listado canvas | Quitar filtros/recargar; revisar registro antes de recrear |
| Run o sus salidas no aparecen en Studio | Nombre de fuente y referencia del flujo | Revisar contrato; actualizar referencia si se trabaja manualmente |
| App dice ERROR | Mensaje de IfError, publicacion, IDs y permisos | Registrar el error y corregir su causa; no sustituir respuesta por OK local |
| list-flow-runs vacio pero usuario ve OK | Separar evidencia CLI y evidencia de UI | No declarar fallo; contrastar ID si se dispone del historial |

En el incidente de visibilidad del 5 de octubre de 2026 se confirmo por API
una app ClassicCanvasApp publicada, propietario coincidente con la cuenta
autenticada y presencia en `pac canvas list`. El usuario despues confirmo que
aparecia en Aplicaciones. No se determino si la causa fue un filtro, cache o
propagacion; no documentar ninguna como causa establecida. No fue necesario
recrear la app, cambiar propietario ni otorgar acceso adicional.

Filtrar consultas por la app/flujo del piloto. Evitar listar miles de soluciones
o exponer metadata de otras automatizaciones. No usar un token Power Platform
API en una solicitud Dataverse como si tuviera la audiencia requerida.
