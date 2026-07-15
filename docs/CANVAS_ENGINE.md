# Canvas Engine

Versión 1.0

## 1. Propósito y alcance

Canvas Engine es la estrategia de disposición espacial de Workspace. Permite organizar los mismos bloques del modo documento sobre una superficie bidimensional, sin crear un segundo modelo de contenido ni una ruta alternativa de interacción.

El motor se apoya en Workspace Engine, Block SDK, Interaction Engine, Transformation Engine y Viewport Engine. Su responsabilidad termina en la disposición, consulta espacial y presentación de elementos. El contenido, las capacidades, la selección, el historial, el autosave y los attachments conservan sus autoridades existentes.

La superficie de esta versión es virtual, amplia y finita. No pretende implementar un lienzo matemáticamente infinito.

## 2. Estrategia híbrida de layout

`WorkspacePage.layoutType` es la decisión tipada que selecciona la estrategia activa:

- `document`: flujo vertical estructurado y ordenado por `orderKey`;
- `canvas`: disposición libre mediante `CanvasLayoutState`;
- `whiteboard`: valor reservado, sin implementación visible en esta versión.

Una página contiene una sola lista de `BaseBlock`, pero el tipo de espacio se decide al crearlo. Un Documento permanece en layout `document` y un Canvas permanece en layout `canvas`; la interfaz de producto no ofrece conversión entre ambos. Los documentos antiguos que no declaran un layout continúan abriendo como Documento.

## 3. Modelo persistente

`CanvasLayoutState` pertenece a `WorkspacePage` y contiene:

- placements de bloque;
- configuración de rejilla y snapping;
- conectores;
- marcos.

`CanvasPlacement` identifica un bloque por UUID y almacena posición `x/y`, tamaño opcional, `zIndex`, contenedor opcional y estado de bloqueo. Solo acepta números finitos y dimensiones positivas. El placement es la autoridad de disposición en Canvas; `BaseBlock` sigue siendo la autoridad del contenido y las capacidades.

El estado se normaliza contra la lista real de bloques al deserializar y después de operaciones estructurales. Esto crea placements faltantes de forma determinista y elimina conectores cuyos extremos dejaron de existir.

## 4. Separación entre Documento y Canvas

Documento y Canvas comparten Workspace Engine y Block SDK, pero son tipos de archivo distintos desde la perspectiva del producto. La biblioteca “Mis documentos” solo presenta espacios lineales; la biblioteca “Canvas” solo presenta espacios espaciales. Crear un Canvas establece simultáneamente `WorkspaceType.canvas` y `WorkspaceLayoutType.canvas`.

No existe una acción visible para convertir un tipo en el otro. Esta regla evita adaptaciones ambiguas: el orden vertical no puede expresar toda la intención espacial de un Canvas y las coordenadas libres no definen por sí solas una secuencia documental correcta.

`WorkspaceEditorSession.convertLayout` se conserva únicamente como compatibilidad interna para datos y pruebas creados antes de esta decisión. No forma parte de la navegación, los menús ni los comandos disponibles para el usuario, y no debe utilizarse para nuevas funciones de producto.

## 5. Coordenadas y cámara

Canvas usa coordenadas lógicas de Workspace. Viewport Engine es la única autoridad para zoom y traslación, y `GeometryResolver` realiza las conversiones entre Workspace, viewport y pantalla.

Las operaciones persistentes reciben coordenadas de Workspace. En particular, el delta de un drag se divide por el zoom de cámara antes de modificar placements. El render no almacena coordenadas de pantalla ni incorpora el estado de cámara al documento.

La cámara admite zoom focal, pan, reset, encajar contenido y centrar una selección. Los límites de zoom continúan centralizados en `WorkspaceViewportController`.

## 6. Capas de renderizado

La composición mantiene el orden conceptual siguiente:

1. fondo y rejilla;
2. marcos;
3. conectores;
4. bloques de contenido;
5. decoración de selección y transformación;
6. overlays y controles modales.

Los bloques se renderizan con `BlockRegistry` y los widgets existentes. Canvas no contiene un switch central por tipo de bloque. Las claves se basan en UUID y los controladores internos conservan el ciclo de vida definido por cada renderer.

## 7. Selección y manipulación

Canvas reutiliza la selección simple, selección múltiple, marquee, prioridades de controles internos y edición nativa de texto de Interaction Engine.

El drag libre comienza desde el handle del bloque. Si el bloque pertenece a la selección múltiple, todos los placements seleccionados reciben el mismo delta dentro de una sola operación Undo/Redo. El modo Canvas no resuelve placeholders ni destinos ordinales propios del documento.

Resize reutiliza las sesiones y handles de Transformation Engine. Los límites se convierten nuevamente a Workspace antes del commit. Alineación en seis ejes y distribución horizontal o vertical actualizan placements mediante comandos atómicos.

## 8. Snapping y rejilla

La rejilla es una preferencia persistente por página. El snapping de movimiento opera en coordenadas de Workspace, por lo que no cambia de precisión al variar el zoom. El snapping puede deshabilitarse sin ocultar la rejilla, y ambos ajustes forman parte del historial.

Las guías inteligentes de resize continúan siendo transitorias: se calculan en el ciclo de interacción y nunca se serializan.

## 9. Orden visual

`zIndex` define el orden de pintura y hit testing. Las acciones traer al frente, enviar al fondo, adelantar y atrasar renormalizan los índices para evitar crecimiento ilimitado o empates ambiguos. Cada acción produce una sola entrada de historial.

El hit testing espacial elige primero el placement con mayor `zIndex` cuando dos bloques se superponen.

## 10. Inserción

Los bloques se crean mediante las mismas factories registradas del editor. En Canvas se insertan cerca del centro lógico visible, reciben UUID y un `zIndex` superior, y no dividen un `TextBlock` ni generan saltos de línea artificiales. En Documento se conserva la semántica de inserción y división textual existente.

## 11. Marcos

Los marcos son contenedores visuales planos persistidos en `CanvasLayoutState`. La pertenencia se expresa mediante `CanvasPlacement.containerId`; nunca se infiere por solapamiento geométrico.

Esta versión crea un marco alrededor de una selección y registra la membresía de sus bloques. No admite marcos anidados, edición directa del marco, resize del marco ni movimiento de marco con hijos. Al mantener una jerarquía plana, no existen ciclos de contención posibles en el alcance actual.

## 12. Conectores

Un conector persistente contiene UUID, bloque origen, bloque destino y tipo. Esta versión implementa conectores rectos dirigidos entre centros de placements. Se actualizan automáticamente al mover o redimensionar sus extremos y pueden eliminarse por selección de bloques.

No se implementan routing ortogonal, puntos de anclaje editables, selección independiente de líneas ni estilos avanzados. La herramienta solo se ofrece cuando dos bloques seleccionados pueden producir un conector real; no se crean placeholders.

## 13. Persistencia y migración

`DocumentContent` usa schema version 4. La evolución desde workspaces schema 3 es no destructiva: el JSON de Workspace se carga con los defaults tipados y se vuelve a guardar en la versión actual. La migración es idempotente y no borra tablas ni archivos.

Páginas antiguas continúan como Documento. Una página marcada como Canvas pero sin estado espacial recibe placements deterministas durante la deserialización. IDs, bloques, attachments, metadata, versiones y soft delete permanecen sin cambios.

## 14. Historial y autosave

Todas las mutaciones persistentes pasan por `WorkspaceEditorSession`. Conversión, movimiento libre simple o múltiple, resize, alineación, distribución, cambio de capa, creación de conectores, creación de marcos y preferencias Canvas son operaciones atómicas sobre el historial existente.

El autosave no conoce widgets ni cámara. Recibe el Workspace resultante mediante el callback de sesión, aplica el debounce vigente y persiste JSON versionado. Los estados transitorios de drag, marquee, snapping, foco y viewport no disparan persistencia.

## 15. Rendimiento

El renderer calcula el rectángulo visible en coordenadas de Workspace y monta placements que intersectan ese rectángulo más un área de overscan. `CanvasSpatialIndex` ofrece consultas de intersección e hit testing independientes de Flutter. La rejilla se pinta como una capa liviana y las claves de bloque permanecen estables.

No se crean controladores globales por bloque ni se serializa el Workspace durante cada actualización transitoria del puntero.

## 16. Accesibilidad y entrada

Selección y transformación mantienen handles semánticos. El teclado conserva Escape y Delete/Backspace, con prioridad para la edición nativa de texto. La herramienta Mano realiza pan con puntero primario; mouse central, gesto táctil de dos dedos y Ctrl/Cmd más rueda continúan disponibles a través de Viewport Engine.

Las acciones de Canvas se presentan con texto explícito y no exponen herramientas futuras sin comportamiento real.

## 17. No objetivos de esta versión

Quedan fuera de Canvas Engine 1.0:

- Ink, handwriting, pen, highlighter y eraser;
- rotación interactiva;
- selección o edición independiente de conectores;
- routing avanzado de conectores;
- marcos anidados y grouping general;
- selección múltiple de páginas;
- colaboración, sincronización e IA;
- un plano matemáticamente infinito.

Estas limitaciones son deliberadas. Las extensiones futuras deberán mantener un único modelo de bloques, una única cámara, una única selección y una única sesión de historial.
