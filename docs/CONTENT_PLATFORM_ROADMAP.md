# Plataforma de contenido: estado, arquitectura y fases

## Decisión principal

`Workspace → WorkspacePage → BaseBlock` es el modelo canónico. Los modelos
legados de notas y `StructuredDocument` solo deben actuar como adaptadores de
compatibilidad mientras se completa su migración. Ningún importador debe crear
un modelo paralelo.

Un elemento de biblioteca necesita tres dimensiones independientes:

1. Clase: Workspace editable, archivo externo, plantilla o carpeta.
2. Presentación: documento, Canvas, whiteboard u otra proyección.
3. Formato físico: nativo, PDF, DOCX, Markdown, texto, imagen, video o código.

La extensión del archivo nunca debe decidir por sí sola qué operaciones son
seguras. Cada formato declara capacidades, limitaciones y posibles pérdidas.

## Capacidades integradas en esta fase

- Importación TXT y Markdown como texto editable, conservando el original.
- Importación de código común como `CodeBlock` con lenguaje identificado.
- Importación DOCX limitada a texto compatible y conservación del original.
- PDF preservado como adjunto, con previsualización/impresión y sin prometer
  edición destructiva del original.
- Imágenes como bloques, captura con cámara y OCR local Android/iOS.
- Video local como recurso reproducible dentro del editor.
- Exportación a TXT, Markdown, HTML y PDF.
- Detección por firma básica, límites de tamaño y defensa inicial ante DOCX
  excesivamente expandido.
- Registro de formato, MIME, checksum, fecha y origen en metadatos.

## Límites explícitos

- DOCX no conserva todavía todos los estilos, encabezados, notas, gráficos ni
  objetos avanzados de Word.
- Un PDF importado no se edita como si fuera un documento de texto. La futura
  reconstrucción editable será un artefacto derivado ligado al original.
- OCR conserva en esta fase el texto agregado; deben añadirse regiones,
  confianza, motor y correcciones para trazabilidad completa.
- Exportar Canvas a formatos de texto conserva contenido, no su composición
  espacial. La exportación visual se implementará por mosaicos.
- Web requiere adaptadores sin `dart:io`; ML Kit está limitado a Android/iOS.

## Bloqueadores de escalabilidad

### Persistencia

La biblioteca aún carga el JSON completo de cada Workspace y cada guardado
reescribe el snapshot. Antes de documentos grandes se necesita:

- Proyección ligera `library_items` con título, formato, resumen, tamaño,
  miniatura y fechas.
- Paginación, índices y SQLite FTS.
- Journal de cambios y recuperación de borradores.
- Separación de páginas/bloques guiada por métricas, manteniendo snapshots para
  migración y respaldo.

### Assets

Los adjuntos todavía se resuelven recorriendo un directorio. La siguiente
migración debe introducir `assets` y `asset_references`, con MIME validado,
checksum, propietario, bloque, dimensiones, conteo de referencias, papelera y
recolección segura. Los respaldos deben incluir base, blobs y manifest.

### Extensiones

`BlockType` es un enum cerrado. Debe evolucionar a `typeId` estable,
`payloadVersion` y payload preservable. `UnknownBlock` es el mecanismo de
compatibilidad durante esa transición.

## Contratos objetivo

- `FormatProbe`: detección por firma/MIME.
- `ContentImporter`: original + bloques derivados + diagnósticos.
- `ContentExporter`: formatos, compatibilidad y pérdidas previstas.
- `AssetStore`: blobs privados y referencias transaccionales.
- `OcrService`: texto y regiones con procedencia.
- `PreviewService`: páginas y miniaturas persistentes.
- `BackgroundJobRunner`: progreso, cancelación, límites y reintentos.
- `ConversionArtifact`: relación versionada entre original y derivado.

Los contratos de formato viven en `lib/domain/content_io`; las implementaciones
de plataforma viven en `features/content_io`. El editor consume servicios y no
debe contener parsers de archivo.

## Orden de entrega

1. AssetStore, recuperación/autosave y respaldos completos.
2. Proyección de biblioteca, búsqueda FTS y paginación.
3. TXT/Markdown/código maduros y exportación visual de Canvas.
4. OCR con regiones y escáner multipágina.
5. PDF: visor por páginas, anotaciones y extracción.
6. DOCX compatible por subconjuntos documentados.
7. Multimedia, miniaturas y trabajos en segundo plano.
8. Sincronización, conflictos y colaboración.

Cada fase debe conservar el original, producir diagnósticos y dejar la
aplicación utilizable aun cuando una conversión no sea posible.
