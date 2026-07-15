# Ink & Annotation Engine

Versión 1.0

## 1. Propósito y alcance

Ink & Annotation Engine incorpora tinta vectorial y anotaciones al mismo Workspace que contiene bloques estructurados. No es un editor de dibujo independiente: reutiliza InputDispatcher, InteractionResolver, WorkspaceInteractionController, Selection Model, Viewport Engine, GeometryResolver, WorkspaceEditorSession, Undo/Redo y autosave.

La primera versión permite dibujar y anotar en los layouts Documento y Canvas. El contenido de tinta se conserva como datos vectoriales neutrales y nunca como Widgets, controladores, coordenadas de pantalla o imágenes rasterizadas.

## 2. Flujo arquitectónico

La entrada mantiene la canalización oficial:

```text
Pointer / touch / mouse / stylus
              ↓
      PointerInputAdapter
              ↓
    NormalizedInputEvent
              ↓
       InputDispatcher
              ↓
    InteractionResolver
              ↓
        Ink Intent
              ↓
WorkspaceInteractionController
              ↓
         InkSession
              ↓
   WorkspaceEditorSession
              ↓
 WorkspacePage.inkLayer
```

La herramienta activa determina el significado del puntero. La presencia de un stylus no cambia automáticamente a modo tinta. En Selección o Texto, los controles internos y la selección nativa conservan su prioridad; en Pluma, Resaltador, Borrador, Lasso o Forma, el gesto se resuelve como una sesión de tinta explícita.

## 3. Modelo de dominio

### 3.1 InkPoint

`InkPoint` almacena posición obligatoria en coordenadas de Workspace, tiempo relativo a la sesión y datos opcionales de presión, inclinación y azimuth. También define contratos para puntos predichos o coalescidos. Los valores no finitos se rechazan al deserializar y la presión se normaliza al intervalo de cero a uno.

Los identificadores de puntero y el tipo de dispositivo pertenecen a `InkSession`; no forman parte del contenido persistido.

### 3.2 InkBrushStyle

El estilo es neutral respecto de Flutter. Contiene tipo lógico de pincel, color ARGB, ancho base en Workspace, opacidad, uso de presión, perfil de suavizado, composición lógica, cap y join. Los valores se normalizan a límites seguros antes de persistirse o renderizarse.

Los perfiles oficiales son:

- `precise`: conserva cambios de dirección pequeños y se usa para formas;
- `balanced`: equilibrio predeterminado de la pluma;
- `smooth`: tolerancia mayor para el resaltador.

### 3.3 InkStroke e InkShape

`InkStroke` contiene UUID estable, `surfaceId`, estilo, puntos ordenados, anchor opcional, z-order, visibilidad, bloqueo y marcas temporales. El límite actual es de 20 000 puntos por trazo para impedir payloads malformados o consumo no acotado.

`InkShape` representa línea, flecha, rectángulo o elipse mediante puntos inicial y final, estilo y los mismos atributos de identidad, orden y anchor. Las formas siguen siendo entidades vectoriales seleccionables; no se convierten en trazos rasterizados.

### 3.4 InkLayerState

`WorkspacePage.inkLayer` es la autoridad durable de tinta de la página. Mantiene una colección ordenada de `InkElement` y un `formatVersion` propio. Selección, preview, cursores, puntos predichos y sesiones activas no se serializan.

La cantidad de elementos deserializados está limitada a 10 000 por página. Entidades desconocidas, no finitas o estructuralmente inválidas se omiten de forma controlada sin afectar los bloques de la página.

## 4. Anchors de anotación

Los anchors soportados por contrato son `freeCanvas`, `blockRelative`, `imageRelative` y `documentPageRelative`.

En esta versión son funcionales:

- `freeCanvas`: coordenadas absolutas de Workspace en Documento o Canvas;
- `imageRelative`: referencia al UUID y a los bounds estables de un `ImageBlock`.

El renderer transforma un punto anclado desde los bounds de referencia hacia los bounds actuales de la imagen. Por ello, mover o redimensionar la imagen mantiene la relación espacial de la anotación.

La política oficial para un target eliminado es `convertToFreeCanvas`: el elemento conserva sus coordenadas absolutas y se elimina únicamente el anchor. Esta decisión evita pérdida silenciosa de tinta. Los contratos `blockRelative` y `documentPageRelative` están preparados, pero no se exponen como funcionalidades mientras no exista una superficie estable que los necesite.

## 5. Tool System e InkSession

Las herramientas funcionales son:

- Selección y Mano, provistas por el sistema existente;
- Pluma;
- Resaltador;
- Borrador de tinta;
- Lasso de tinta;
- Línea;
- Flecha;
- Rectángulo;
- Elipse.

`InkSession` extiende la sesión de interacción existente y captura una sola herramienta, configuración de pincel, puntero, correlationId, anchor y stream provisional de puntos. Su ciclo es:

1. `BeginInkIntent`: crea la sesión y el primer punto.
2. `UpdateInkIntent`: agrega puntos o actualiza los IDs afectados por el borrador.
3. `CommitInkIntent`: entrega un único gesto lógico al sistema de comandos.
4. `CancelInkIntent`: descarta el preview sin persistencia ni historial.

Un segundo puntero durante una sesión de tinta se rechaza de forma controlada. El gesto de dos dedos de Viewport puede cancelar la sesión activa y continuar con pan o zoom sin guardar un trazo incompleto.

Las herramientas `textRecognition`, `shapeRecognition`, `laserPointer` y `ruler` solo existen como valores preparados del Tool System. No se muestran ni ejecutan.

## 6. Captura, suavizado y simplificación

Los puntos se capturan directamente en Workspace mediante `GeometryResolver`. El preview utiliza el stream recibido y aplica una curva cuadrática ligera al pintar, sin ejecutar procesamiento costoso dentro de `pointerMove`.

Al commit se ejecuta una simplificación Ramer-Douglas-Peucker. La tolerancia depende del perfil, ancho y zoom, con límites conservadores entre 0.08 y 1.4 unidades lógicas. Se preservan siempre los extremos. El objetivo es reducir datos redundantes sin degradar firmas, escritura pequeña ni esquinas deliberadas.

La presión funcional modifica el ancho por segmento de la pluma. El resaltador desactiva presión de forma predeterminada. Tilt, azimuth y flags de coalescing/prediction se conservan como contratos; Flutter no ofrece en todas las plataformas un stream seguro de puntos coalescidos o predichos, por lo que no se simulan.

## 7. Renderer y rendimiento

`InkCanvasLayer` es una capa especializada con `CustomPainter` y `RepaintBoundary`. Se ubica entre ContentLayer y las decoraciones de interacción. El contenido estructurado no se reconstruye por cada punto.

El renderer separa conceptualmente:

1. elementos persistidos;
2. trazo o forma provisional;
3. preview del borrador o polígono de lasso;
4. selección de tinta y handles visuales;
5. cursor o preview de hover.

Los elementos se consultan mediante `InkSpatialIndex` y se filtran contra el viewport visible. Puntos, anchos y tolerancias se transforman con la misma cámara utilizada por Canvas. El ancho del pincel se almacena en Workspace y escala visualmente con el zoom.

El resaltador usa composición `sourceOver` con opacidad controlada como fallback estable entre Android, escritorio y Web. No se emplea un blending dependiente de plataforma.

## 8. Borrador

El modo funcional obligatorio es borrado por elemento completo. Durante el gesto, el índice espacial identifica trazos y formas afectados usando una tolerancia de pantalla convertida a Workspace. El preview los resalta, pero no muta sus puntos.

Al levantar el puntero se emite una sola eliminación atómica. Undo restaura exactamente elementos, estilos, anchors y z-order. El borrador no opera sobre bloques, texto ni controles internos.

El borrado parcial queda preparado mediante el concepto de reemplazo, pero permanece pendiente hasta contar con división robusta de trazos y pruebas suficientes para garantizar rollback sin corrupción.

## 9. Lasso y selección de tinta

El lasso produce un polígono transitorio y consulta exclusivamente `InkElement`. El resultado se representa como `InkSelection`, una variante tipada de `WorkspaceSelection`; no existe un segundo controlador de selección.

Una selección de tinta permite:

- eliminar;
- duplicar;
- cambiar color, grosor u opacidad;
- mover mediante acciones direccionales accesibles.

Cada operación persistente genera una sola entrada de historial. La selección no forma parte de la persistencia. El movimiento libre directo y el escalado mediante drag quedan como mejora de UX posterior; los elementos ya exponen contratos de traslación y bounds combinados.

## 10. Formas básicas

Línea, flecha, rectángulo y elipse muestran preview durante el drag y se confirman como `InkShape`. Con Shift, línea y flecha se restringen a ángulos de 45 grados, mientras rectángulo y elipse conservan proporciones iguales.

No se realiza reconocimiento automático de formas. Una forma completa equivale a un único comando y una única mutación de autosave.

## 11. Persistencia, migración y autosave

`DocumentContent.currentSchemaVersion` es 5. La estrategia sigue siendo JSON versionado del Workspace dentro de la persistencia existente. No se agregan tablas, paquetes ni rutas de almacenamiento paralelas.

Las páginas de schema 4 o anteriores cargan un `InkLayerState` vacío. La migración es idempotente y no modifica bloques, Canvas placements, attachments, metadata ni el payload original de migraciones previas. Al volver a guardar, la página incorpora `inkLayer` únicamente cuando contiene elementos.

Los commits de dibujo, forma, borrado, duplicación, movimiento y estilo pasan por `WorkspaceEditorSession`. El callback existente activa el debounce de autosave. Ningún `pointerMove`, preview, selección o cambio de cámara persiste datos.

## 12. Undo y Redo

El historial actual trata cada acción como una mutación atómica del Workspace:

- agregar un trazo;
- agregar una forma;
- eliminar uno o varios elementos;
- duplicar una selección;
- trasladar una selección;
- actualizar estilo.

El historial restaura el snapshot estructural anterior, incluidos orden, anchors y geometría. Un gesto no crea entradas por punto ni por frame. Sesiones canceladas y comandos vacíos no entran al historial.

## 13. UX y accesibilidad

La toolbar inferior ofrece herramientas con icono, tooltip y semántica; paleta de colores; cinco presets de grosor; cuatro niveles de opacidad; Undo/Redo; acciones de selección; y salida explícita del modo tinta. En móvil también existe un acceso flotante independiente de la selección por área de bloques.

La herramienta activa se indica visualmente y el cursor de mouse cambia en modos de tinta. El hover compatible muestra un preview sin dibujar. Los controles no dependen únicamente del color y las acciones seleccionables tienen etiquetas accesibles.

La edición nativa de texto conserva prioridad en las herramientas Texto y Selección. Dibujar sobre texto requiere activar explícitamente una herramienta de tinta.

## 14. Debug, privacidad e integridad

El timeline técnico existente registra tipo de evento, hit target y resolución, nunca coordenadas completas ni contenido dibujado. Un panel compacto de tinta está disponible exclusivamente en builds debug mediante `--dart-define=WORKSPACE_INK_DEBUG=true`; permanece desactivado por defecto y muestra herramienta, correlationId, conteo provisional y número de elementos.

La tinta no sale del dispositivo, no ejecuta OCR y no utiliza servicios externos. La deserialización valida finitud, límites de puntos, dimensiones y estilos antes de admitir datos.

## 15. Estado real de la versión

### Funcional

- Pluma, resaltador y borrador por elemento.
- Lasso exclusivo de tinta.
- Línea, flecha, rectángulo y elipse.
- Color, grosor y opacidad.
- Touch, mouse y stylus a través de PointerEvent.
- Presión cuando la plataforma la entrega.
- Preview incremental y cancelación segura.
- Tinta en Documento y Canvas.
- Anchor relativo a imágenes con geometría estable.
- Persistencia vectorial schema 5.
- Undo/Redo y autosave por gesto.
- Selección, borrado, duplicación, movimiento accesible y estilo.
- Culling, hit testing y cursor de hover.

### Parcial

- El movimiento de selección usa acciones direccionales; no existe aún drag libre de tinta seleccionada.
- La presión usa variación por segmento, no una malla caligráfica avanzada.
- La entrada simultánea rechaza o cancela de forma segura el segundo puntero; no implementa dibujo y viewport concurrentes.
- Las anotaciones documentales libres son absolutas; solo ImageBlock dispone de anchor relativo funcional.

### Preparado

- Tilt, azimuth, puntos predichos y coalescidos.
- Anchors relativos a bloques y páginas.
- Reemplazo de trazos para borrado parcial.
- Herramientas de reconocimiento, laser pointer y ruler sin exposición funcional.
- Transformación de selección mediante handles.

### Pendiente o fuera de alcance

- OCR y reconocimiento de escritura.
- Conversión automática a texto.
- Reconocimiento automático de formas.
- Borrado parcial.
- Palm rejection nativo personalizado.
- Colaboración y sincronización de tinta.
- Exportación vectorial avanzada.
- Pinceles artísticos y rotación multitáctil avanzada.

## 16. Invariantes para evoluciones futuras

Toda evolución del motor debe conservar las siguientes reglas:

1. Las coordenadas persistidas pertenecen a Workspace.
2. Viewport Engine es la única cámara.
3. Interaction Engine es la única canalización de entrada.
4. `WorkspaceSelection` es la única fuente de verdad para selección.
5. Un gesto completo equivale a una operación lógica de historial.
6. Los previews nunca se persisten.
7. Los anchors no pueden causar pérdida silenciosa de tinta.
8. El contenido de tinta no depende de Flutter.
9. La edición nativa de texto conserva prioridad fuera del modo tinta explícito.
10. Funciones preparadas no deben mostrarse como si fueran funcionales.
