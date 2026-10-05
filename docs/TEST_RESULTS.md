# Resultado de la prueba de conexion

Fecha: 5 de octubre de 2026, America/Lima.
Entorno: Personal Productivity.

| Comprobacion | Evidencia | Resultado |
| --- | --- | --- |
| Autenticacion Microsoft y acceso a Dataverse | pac selecciono el entorno y consulto datos | Correcto |
| Crear flujo desde codigo | Importacion de AutomationConnectionTest con pac | Correcto |
| Estado del flujo | API: Published / Dataverse: Activated | Correcto |
| Crear app nativa desde codigo | pac canvas pack y posterior importacion de solucion | Correcto |
| Estado de la app | API: ClassicCanvasApp, lifeCycleId Published | Correcto |
| Referencia app-flujo | API: workflowEntityId y workflowName coinciden con el flujo creado | Correcto |
| Ejecutar boton y recibir respuesta | Usuario abrio la app, pulso Probar flujo y reporto que muestra OK | Correcto, confirmado por el usuario |
| Correlacionar ID de ejecucion con historial | La consulta pac list-flow-runs no devolvio ejecuciones | No verificado por CLI |
| Visibilidad en Aplicaciones | Usuario inicialmente la vio solo en Soluciones; despues confirmo que aparecia en Aplicaciones | Correcto, confirmado por el usuario; causa del retraso no determinada |

La app invoca el flujo real mediante `.Run()`. Genera `PRUEBA-<GUID>`, muestra
la respuesta y maneja errores. No simula el valor OK en la pantalla.
La confirmacion del usuario valida la llamada de ida y vuelta; no es una
prueba automatizada de navegador. El ID, texto completo y hora mostrados
no fueron aportados por el usuario para contrastarlos con el historial.

No se probaron los casos de flujo apagado, doble pulsacion, permisos de otros
usuarios ni conectores de procesos financieros. Los artefactos locales siguen
siendo un prototipo de construccion con el empaquetador canvas Experimental
obsoleto; la importacion y la prueba del usuario funcionaron en este entorno.

Para repetir: abrir AutomatizacionPrueba, pulsar Probar flujo y comprobar OK,
el mensaje enviado, la fecha UTC y el ID. Una segunda llamada debe devolver
otro mensaje e ID. El script Verify-ConnectionTest.ps1 comprueba publicacion
y vinculacion; no pulsa el boton.
