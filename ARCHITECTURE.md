# Arquitectura base

La aplicación usa una variante pragmática de Clean Architecture organizada por
*features*. `app` compone el proceso Flutter; `core` contendrá detalles
técnicos reutilizables; `domain` contiene modelos independientes de framework y
persistencia; y cada carpeta bajo `features` será dueña de sus adaptadores,
casos de uso y presentación cuando éstos existan.

## Dependencias

`app` podrá depender de features. Una feature podrá depender de `domain` y de
abstracciones de `core`. `domain` sólo depende de Dart y de los tipos mínimos de
`core/shared`; nunca de Flutter, Drift, red ni UI. Los adaptadores futuros
implementarán interfaces definidas del lado interno, conservando los detalles
de Drift y sincronización fuera del dominio.

## Modelo de documentos

Todos los identificadores son `Uuid` (alias de `String`) para facilitar su
serialización. Las entidades declaradas exponen estado mediante campos `final` y tienen
`version`, `updatedAt` y `deletedAt`, por lo que pueden participar en soft
delete y conciliación futura. `Note` almacena un único `DocumentContent`: un
objeto JSON autocontenido junto a `schemaVersion`. El editor podrá interpretar
su árbol de nodos para texto enriquecido, listas, tablas, enlaces, código,
imágenes o dibujos sin cambiar el esquema de las tablas.

`NoteVersion` y `Template` también usan `DocumentContent`, evitando que el
historial y las plantillas dependan de la implementación de la base de datos.

## Persistencia local

`AppDatabase` agrupa las tablas Drift de notas, carpetas, etiquetas, relaciones
nota-etiqueta, adjuntos y configuración. La fuente local sólo traduce filas a
entidades; `NoteRepository` es el contrato de dominio y `LocalNoteRepository`
su implementación local. No existe fuente remota ni sincronización.

Cada fila principal tiene UUID, marcas de creación y actualización, soft delete
y versión. Una futura sincronización podrá consumir el repositorio, comparar
`version` y `updatedAt`, y conservar los registros eliminados hasta confirmar
su propagación. El remoto será otro adaptador, no una dependencia del dominio.
