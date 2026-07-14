# Persistencia local

La base SQLite se abre con `drift_flutter` como `allministrator.sqlite` en el
directorio de documentos de la aplicación. Drift genera código tipado a partir
de las tablas declaradas en `lib/core/database/tables`.

## Tablas del MVP

| Tabla | Propósito |
| --- | --- |
| `notes` | Documento JSON versionado y su carpeta opcional. |
| `folders` | Organización jerárquica de notas. |
| `tags` | Catálogo de etiquetas. |
| `note_tags` | Relación many-to-many entre notas y etiquetas. |
| `attachments` | Metadatos de archivos asociados a una nota o nodo documental. |
| `settings` | Preferencias versionadas por clave. |

Todas utilizan UUID como clave primaria, salvo que `note_tags` además impide
duplicar el par nota-etiqueta. Las claves foráneas protegen la integridad de
relaciones físicas; los borrados funcionales son siempre soft delete.

## Documento extensible

`notes.document_json` guarda un objeto JSON completo y
`notes.document_schema_version` indica cómo debe leerlo el editor. Una futura
migración del formato del documento puede traducir en memoria una versión vieja
al abrirla, o actualizarla de forma controlada, sin tocar la estructura
relacional. `attachments.document_node_id` permite conectar recursos futuros a
nodos concretos sin imponer un modelo de bloques a SQLite.

## Sincronización futura

La tabla no necesita red para operar. Cuando exista un adaptador remoto, éste
se compondrá detrás del contrato de repositorio. Los campos `version`,
`updated_at` y `deleted_at` permiten detectar cambios y propagar tombstones.
Antes de implementarla habrá que definir la estrategia de conflictos, el actor
que origina un cambio y una cola local de operaciones; esos conceptos no se han
implementado en este MVP.
