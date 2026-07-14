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

## Modelo

Todos los identificadores son `Uuid` (alias de `String`) para facilitar su
serialización. Las entidades declaradas exponen estado mediante campos `final` y tienen
`version`, `updatedAt` y `deletedAt`, por lo que pueden participar en soft
delete y conciliación futura. `Note` no almacena contenido: el documento se
forma con `Block`, que admite jerarquía mediante `parentBlockId`. Sus cuatro
payloads JSON están separados explícitamente.

`NoteVersion` y `Template` conservan instantáneas de bloques para que el
historial y las plantillas no dependan de una futura implementación de base de
datos. `BlockSnapshot` es un value object necesario para ello, no una entidad
adicional de negocio.

No se añaden dependencias: UUID, serialización, Drift, inyección de
dependencias, estado, rutas y sincronización se decidirán al implementar sus
respectivas fronteras.
