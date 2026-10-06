# Registro de próximos features

Actualizado: 6 de octubre de 2026, America/Lima.
Propósito: conservar el orden de evolución y el punto de reanudación del
proyecto. Los features descritos están pendientes; este registro no inicia
su implementación ni autoriza despliegues adicionales.

## Punto de partida al cerrar la sesión

El piloto ya construye e importa una solución con app canvas y flujo cloud.
Microsoft confirmó ambos publicados y la referencia app-flujo correcta.
El usuario ejecutó el botón y confirmó `OK`; también confirmó que la app
aparece en Aplicaciones. El harness, los contratos y la skill están documentados.
La correlación del ID de ejecución con el historial sigue sin verificarse.

Los scripts actuales son específicos del piloto: fijan identidades, versión
de pac, región WADL y versiones de solución. La construcción canvas necesita
consultar un flujo previamente importado. No es aún un generador general.

## Orden de trabajo

| Orden | ID | Feature | Estado | Dependencia |
| --- | --- | --- | --- | --- |
| 1 | F01 | Parametrizar identidades y entorno | En curso: configuración y validación local implementadas | Piloto actual |
| 2 | F02 | Mejorar construcción y validación | Pendiente | F01 |
| 3 | F03 | Probar una integración real | Pendiente; integración por elegir | F02 y acceso autorizado |
| 4 | F04 | Generalizar referencias y variables | Pendiente | Contrato y experiencia de F03 |
| 5 | F05 | Unificar la CLI | Pendiente | F01–F04 |
| 6 | F06 | Automatizar despliegues | Pendiente | F05 y pruebas repetibles |

Secuencia: **identidades y entorno → construcción y validación → integración
real → referencias y variables → CLI → despliegues automatizados**.

## F01 — Parametrizar identidades y entorno

Objetivo: construir otro ejemplo sin editar GUIDs y nombres dentro de scripts
ni sobrescribir el piloto existente.

Trabajo previsto:

- Definir configuración de automatización: nombre único de solución,
  publisher/prefijo, nombres de app/flujo y sus identidades estables.
- Separar configuración de entorno: EnvironmentId, región, ubicación de pac
  y valores que pertenecen a cada despliegue.
- Resolver AppId y resourceId consultando el entorno; conservar la distinción
  entre workflowId Dataverse e ID del recurso Power Automate.
- Mantener el piloto con su configuración actual como ejemplo de regresión.
- Versionar plantillas sin secretos; mantener valores privados locales fuera
  de Git cuando corresponda. No almacenar tokens en la configuración.

Criterios de aceptación: una segunda configuración produce nombres e
identidades propios; los scripts no dependen del AppId original para consultar
otra app; el piloto mantiene su identidad y contrato. Registrar por separado
lo comprobado localmente y lo comprobado en Microsoft.

Evidencia local del 6 de octubre de 2026: se agregaron configuraciones
versionadas para el piloto y una segunda identidad, una plantilla de entorno
sin secretos y validación que rechaza identidades duplicadas. Los paquetes se
generan desde una copia en `artifacts/build/`. Falta importar y verificar la
segunda configuración en un entorno autorizado; F01 permanece en curso.

## F02 — Mejorar construcción y validación

Objetivo: generar paquetes de forma repetible y detectar incompatibilidades
antes de importar.

Trabajo previsto:

- Preservar componentes del manifest: sustituir el reinicio de RootComponents
  por una actualización controlada de los componentes correspondientes.
- Gestionar versiones sin volver siempre a 1.0.0.0 / 1.0.0.1.
- Separar generación local, resolución de referencias remotas e importación.
  Documentar cuándo se necesita la consulta al entorno; no prometer un build
  totalmente offline mientras esa capacidad no exista.
- Validar JSON, XML, Power Fx, firma Run y WADL como un contrato coordinado.
- Comprobar identidad y entorno destino antes de una importación.
- Evaluar una vía mantenida de authoring canvas frente al empaquetador
  Experimental obsoleto. Documentar la decisión y validar compatibilidad.

Criterios de aceptación: reconstruir no elimina componentes ajenos; una
inconsistencia de contrato impide continuar; las fases y dependencias son
explícitas; existe una decisión documentada sobre el tooling canvas. Las
comprobaciones locales no realizan importaciones implícitas.

## F03 — Probar una integración real

Objetivo: ampliar la prueba app-flujo con un servicio real y un contrato pequeño,
usando datos sintéticos en una ubicación autorizada de prueba.

Trabajo previsto:

- Elegir una sola integración según la necesidad y el acceso disponible.
  OneDrive for Business es un candidato por el contexto actual; no está elegido.
- Definir una operación verificable, preferiblemente una consulta o lectura
  antes de incorporar escrituras.
- Documentar entradas, salida, errores, permisos y evidencia de ejecución.
- Utilizar el conector existente cuando corresponda y la configuración mínima
  de conexión/referencia que la operación requiera.
- Separar prueba del conector y prueba app-flujo-conector; registrar el resultado
  real y el manejo de errores sin simular respuestas exitosas.

Criterios de aceptación: el resultado proviene del servicio real, el usuario
puede verificarlo y el error se presenta de forma comprensible. La prueba no
opera sobre clientes, seguros ni sistemas bancarios.

F03 no posterga referencias obligatorias: crea las mínimas necesarias para
su integración. F04 generaliza y configura su transporte entre entornos.

## F04 — Generalizar referencias y variables

Objetivo: transportar una automatización sin editar su lógica para cada entorno.

Trabajo previsto:

- Incluir Connection References y Environment Variables como componentes de
  solución, no solo como archivos JSON descriptivos.
- Mapear referencias a conexiones existentes del entorno, sin versionar
  credenciales ni asumir que la importación realiza un login por el usuario.
- Introducir deployment settings para los valores y referencias necesarios.
- Crear plantillas de configuración DEV/QA/PROD cuando existan esos destinos;
  no asumir que los entornos ya están aprovisionados o autorizados.
- Validar únicamente las dependencias declaradas por la automatización.

Criterios de aceptación: el paquete declara sus dependencias; los valores de
despliegue se proporcionan por configuración; una referencia sin resolver o
una variable necesaria ausente genera un diagnóstico concreto. El traslado
real a otro entorno se registra como pendiente hasta que se pruebe allí.

## F05 — Unificar la CLI

Objetivo: ofrecer una entrada consistente para las operaciones ya implementadas.

Interfaz propuesta, aún no creada:

```powershell
./automation.ps1 build <automatizacion>
./automation.ps1 deploy <automatizacion> <entorno>
./automation.ps1 verify <automatizacion> <entorno>
./automation.ps1 test <automatizacion> <entorno>
./automation.ps1 status <automatizacion> <entorno>
```

Trabajo previsto: reutilizar los scripts existentes, validar argumentos y
configuración, definir códigos de salida y diferenciar consulta, construcción
y mutación. `verify` comprueba estado y referencias; `test` solo acredita una
ejecución cuando realmente la ejecuta o registra su evidencia.

Criterios de aceptación: comandos documentados y repetibles; build/status no
despliegan; deploy especifica el destino; los errores no se convierten en éxito.

## F06 — Automatizar despliegues

Objetivo: repetir los pasos comprobados mediante un pipeline, con destinos y
autorizaciones explícitos.

Trabajo previsto:

- Ejecutar validaciones locales, empaquetado, preflight, importación y lectura
  posterior de estado como fases diferenciadas.
- Configurar autenticación del pipeline sin secretos en el repositorio.
- Incorporar pruebas por capas y registro de artefactos, versión y resultado.
- Definir recuperación ante fallo parcial y actualización de un recurso existente.
- Automatizar primero el entorno de desarrollo autorizado; diseñar la promoción
  a otros destinos cuando estos existan y tengan responsables definidos.

Criterios de aceptación: el pipeline reproduce una construcción conocida,
detiene fallos antes de avanzar y deja evidencia de qué se importó y dónde.
La política de publicación y recuperación está documentada; producción no se
habilita por heredar los permisos de la prueba.

## Features condicionados a una necesidad

| Feature | Condición para incorporarlo |
| --- | --- |
| SharePoint | Una automatización requiere bibliotecas/listas o almacenamiento compartido; no reemplazar OneDrive solo por ampliar el catálogo |
| Custom connector para Cloud Run | Una API y sus operaciones justifican reutilización; verificar contrato binario, autenticación y formato OpenAPI admitido |
| Registro de conectores | Varias automatizaciones necesitan declarar y validar integraciones; evitar un catálogo de servicios aún no usados |
| Interfaz Power Apps integrada con PAD | Existe un caso atendido concreto y un entorno/máquina adecuados; la integración no está implementada en este piloto |
| Orquestación financiera / IBM 3270 | Contratos, reglas operativas, controles y autorización propios del proceso; no se deriva de este roadmap |

Cloud Run de tasaciones permanece en `auto-tasacion`. Este proyecto puede
describir y construir su integración sin duplicar ese servicio ni asumir
endpoints nuevos. La plataforma general y cada proceso conservan sus contratos.

## Cómo retomar y mantener este registro

La próxima tarea es **F01**. Leer [AI_CONTEXT.md](AI_CONTEXT.md),
[BUILD_RUNBOOK.md](BUILD_RUNBOOK.md) y los generadores antes de diseñar la
configuración. Preparar un cambio local revisable; reutilizar el piloto como
referencia y no modificar el entorno solo para comenzar la parametrización.

Actualizar estados a `En curso`, `Completado` o `Bloqueado` cuando exista
evidencia, registrar fecha y enlazar commit/prueba relevantes. No marcar un
feature como completo por crear su carpeta o escribir su diseño. Mantener las
ideas futuras separadas de las capacidades actualmente verificadas.
