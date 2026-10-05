# Contrato Power Apps / Power Automate

## Entrada y salida

La app nativa llama a `AutomatizacionPruebaConexion.Run(varMensaje)`.
`varMensaje` es `PRUEBA-` mas un GUID nuevo. La alternativa manual recibe el
texto de `txtMensaje`. Ambas invocan el mismo contrato.

| Direccion | Campo | Tipo | Regla |
| --- | --- | --- | --- |
| App -> disparador | `text` | string | Requerido; titulo visible `Mensaje`; unico argumento de Run |
| Flujo -> app | `estado` | string | `OK` cuando responde esta prueba |
| Flujo -> app | `mensaje` | string | Mismo valor que `triggerBody()?['text']` |
| Flujo -> app | `ejecucionid` | string | `workflow()?['run']?['name']` |
| Flujo -> app | `fechautc` | string | `utcNow()`; fecha UTC |

El disparador es `Request / PowerAppV2`; la respuesta es
`Response / PowerApp`, HTTP 200. Los nombres de salida en minusculas son
parte del contrato. Cambiar titulos visibles no cambia automaticamente las
claves internas. No incluir secretos en entradas, resultados ni ejemplos.

## Conexion nativa

El servicio `shared_logicflows` expone la accion `Run`. El generador escribe
tres representaciones de la referencia, que deben permanecer alineadas:

| Representacion | Ubicacion generada | Relacion |
| --- | --- | --- |
| Connection | `Connections/Connections.json` | dataSources contiene nombre de la fuente; appActions contiene Run |
| DataSource | `DataSources/AutomatizacionPruebaConexion.json` | FlowNameId usa el ID local de conexion; WorkflowEntityId usa workflowId |
| Metadatos ALM | CanvasApp `.meta.xml` | parameterHints y parameterHintsV2 vinculan ambos IDs remotos |

`workflowEntityId = workflowId` Dataverse; `workflowName = resourceId` Power
Automate. El ID local de conexion no es ninguno de ellos. El WADL expresa un
input `text` y las cuatro salidas para que Power Fx conozca la firma de Run.
Una importacion aceptada no demuestra que el WADL y la respuesta coincidan:
hay que verificar el contrato y ejecutar el boton.

## Comportamiento de pantalla

`App.OnStart` inicializa espera, error y un record con las cuatro salidas vacias.
El boton limpia resultados anteriores, genera mensaje y llama al flujo.
`IfError` captura el error; al terminar se desactiva `varEjecutando`.
El boton se deshabilita durante la espera. La etiqueta muestra la respuesta
real; no calcula OK localmente. No hay reintento automatico ni idempotencia
operativa; no trasladar este comportamiento sin mas a una accion financiera.

## Cambiar el contrato

Actualizar juntos `flow.clientdata.json`, las fuentes canvas, el WADL en
`Build-CanvasTest.ps1` y `docs/automation-spec.json`. Si se usa la alternativa
manual, actualizar tambien sus formulas. Construir/importar el flujo antes
de regenerar la app para resolver su referencia real. Validar localmente y
repetir la prueba de ida y vuelta cuando el cambio se despliegue.
