# Documentación de ADB Remote

Esta carpeta describe el comportamiento implementado en el commit base `cd6827e` (`first commit`). La documentación es deliberadamente técnica y se mantiene junto al código para que los cambios de producto, arquitectura y distribución queden trazables.

| Documento | Propósito |
| --- | --- |
| [Arquitectura C4](architecture-c4.md) | Contexto, contenedores, componentes y relaciones externas. |
| [Referencia funcional](functional-reference.md) | Funciones disponibles, comandos ADB y persistencia local. |
| [Operación y distribución](operations.md) | Requisitos, desarrollo, pruebas, empaquetado y limitaciones. |

## Convenciones de mantenimiento

- Actualizar `CHANGELOG.md` en cada cambio visible o relevante para mantenimiento.
- Actualizar la referencia funcional cuando cambien comandos, validaciones o permisos.
- Actualizar los diagramas C4 cuando cambien dependencias, límites del sistema o componentes principales.
