# Block SDK Extensions

Versión 1.0

## 1. Introducción

El Block SDK amplía el modelo de contenido de Workspace mediante dos clases arquitectónicas de bloques: Leaf Blocks y Composite Blocks. Ambos participan en el mismo sistema de identidad, versionado y persistencia, pero cumplen responsabilidades diferentes dentro de una estructura de contenido.

Los Leaf Blocks representan contenido simple e indivisible. Los Composite Blocks representan estructuras reutilizables compuestas por otros bloques organizados con significado. El objetivo de esta separación es reutilizar componentes existentes para construir capacidades complejas sin duplicar modelos, lógica de contenido ni comportamientos básicos.

Esta extensión no define implementaciones visuales. Define el contrato conceptual con el que una futura implementación deberá representar, validar, recorrer, exportar y evolucionar estructuras de bloques.

## 2. ¿Por qué existen los Composite Blocks?

Muchas funcionalidades que parecen productos o tipos de contenido independientes son, en realidad, una organización con propósito de bloques ya existentes. Una reunión puede reunir texto, participantes, pendientes y conclusiones. Una plantilla puede definir una estructura inicial. Una flashcard puede separar una pregunta de una respuesta. Una nota universitaria, un proyecto, un escaneo, un tablero Kanban o un calendario pueden expresarse como composiciones con reglas específicas.

No deben implementarse como tipos completamente independientes cuando puedan construirse reutilizando bloques existentes. Crear modelos aislados para cada caso produce duplicación, dificulta exportar y migrar contenido, y obliga a repetir capacidades que ya pertenecen a los bloques simples.

Los Composite Blocks permiten expresar estas estructuras sin perder la independencia del contenido interno. Un bloque compuesto añade organización, semántica y reglas de validación; no sustituye innecesariamente los bloques que contiene.

```text
Funcionalidad compleja
          │
          ▼
Composite Block
 ├── estructura y reglas
 └── bloques reutilizables
     ├── texto
     ├── listas
     ├── tablas
     └── adjuntos
```

## 3. Leaf Blocks

Los Leaf Blocks representan contenido indivisible dentro del árbol de Workspace. Cada uno encapsula una unidad de información y las propiedades necesarias para conservar su significado. No pueden contener otros bloques.

Los tipos previstos incluyen:

- TextBlock
- ImageBlock
- ChecklistBlock
- TableBlock
- CodeBlock
- DividerBlock
- AttachmentBlock
- QuoteBlock
- CalloutBlock
- InkBlock
- AudioBlock
- VideoBlock
- PdfBlock

Un Leaf Block puede tener una estructura interna propia para representar su contenido, pero no puede adquirir hijos del sistema de bloques. Esta regla protege la claridad del árbol: cuando un caso de uso requiere reunir varias unidades, debe emplearse un Composite Block o un Slot de uno existente.

```text
Leaf Block
├── identidad
├── propiedades del bloque
└── contenido

No contiene otros bloques.
```

## 4. Composite Blocks

Los Composite Blocks representan estructuras de contenido. Cada uno administra internamente una colección organizada de bloques mediante Slots, no mediante una lista plana sin significado. El compuesto define qué regiones lógicas existen, qué contenido admite cada una y qué operaciones están permitidas.

Ejemplos futuros incluyen:

- GroupBlock
- SectionBlock
- TemplateBlock
- MeetingBlock
- ProjectBlock
- FlashcardBlock
- ResearchBlock
- ScanBlock
- CanvasBlock
- MindMapBlock
- DiagramBlock
- TimelineBlock
- CalendarBlock
- KanbanBlock

Un Composite Block puede actuar como una unidad frente al usuario —por ejemplo, para mover, duplicar, exportar o compartir— y, al mismo tiempo, conservar la identidad y la estructura de cada bloque hijo. El compuesto no elimina la autonomía de los hijos; proporciona el contexto en el que su contenido adquiere una función conjunta.

```text
Composite Block
├── identidad y propiedades propias
├── definición de Slots
│   ├── Slot A
│   └── Slot B
└── reglas de estructura y acciones
```

## 5. Sistema de Slots

Los Slots son el mecanismo oficial para organizar bloques hijos en un Composite Block. Un Composite Block no contiene simplemente una lista de hijos: contiene regiones lógicas, cada una con un propósito explícito. Los bloques se asignan a un Slot y adquieren contexto mediante ese Slot.

Cada Slot debe definir conceptualmente:

- **id:** identificador estable dentro de la definición del Composite Block.
- **nombre:** etiqueta legible que expresa la función de la región.
- **descripción:** explicación opcional de su propósito y de las expectativas sobre el contenido.
- **tiposPermitidos:** tipos de bloques que pueden insertarse en el Slot.
- **cantidad mínima:** número mínimo de bloques requerido para que la estructura sea válida.
- **cantidad máxima:** número máximo de bloques que el Slot puede contener.
- **obligatorio:** indicador de si la ausencia de contenido invalida o incompleta la estructura.
- **orden:** posición lógica del Slot respecto de otros Slots del mismo compuesto.
- **metadata:** información extensible y documentada que complementa el contrato del Slot.

Un Slot expresa significado, no solo ubicación. Dos TextBlock pueden tener la misma forma de contenido, pero un Slot puede identificarlos como "Pregunta" y "Respuesta", o como "Título" y "Conclusiones". Esta semántica hace que la estructura sea comprensible para personas, para el sistema y para capacidades futuras.

### Ejemplos de Slots

```text
FlashcardBlock
├── Slot: Pregunta
│   └── TextBlock
└── Slot: Respuesta
    └── TextBlock
```

```text
MeetingBlock
├── Slot: Título
│   └── TextBlock
├── Slot: Objetivos
│   └── TextBlock
├── Slot: Participantes
│   └── TableBlock
├── Slot: Pendientes
│   └── ChecklistBlock
└── Slot: Conclusiones
    └── TextBlock
```

```text
ProjectBlock
├── Slot: Descripción
│   └── TextBlock
├── Slot: Archivos
│   └── AttachmentBlock
├── Slot: Checklist
│   └── ChecklistBlock
├── Slot: Código
│   └── CodeBlock
└── Slot: Diagramas
    └── ImageBlock
```

```text
ResearchBlock
├── Slot: Resumen
│   └── TextBlock
├── Slot: Referencias
│   └── AttachmentBlock
├── Slot: Observaciones
│   └── TextBlock
└── Slot: Experimentos
    └── TableBlock
```

## 6. Reglas de Slots

Cada Slot establece el contrato que regula su contenido. Como mínimo, debe definir qué tipos de bloques acepta, cuántos bloques puede contener y si es obligatorio. Un Slot también puede definir si su contenido puede reordenarse, colapsarse, editarse o participar en una exportación.

Las reglas del Slot deben evaluarse como reglas de dominio. Una interfaz puede mostrar controles compatibles o impedir una acción antes de solicitarla, pero la validez no puede depender únicamente de la interfaz. Esto evita que una importación, una sincronización o una herramienta externa cree estructuras que la aplicación visual no habría permitido.

La cardinalidad se interpreta de forma explícita. Un Slot con cantidad mínima de uno y cantidad máxima de uno requiere exactamente un bloque admisible. Un Slot con máximo mayor puede aceptar una colección ordenada, siempre dentro de los tipos autorizados. Un Slot no obligatorio puede permanecer vacío sin invalidar el Composite Block.

La capacidad de reordenar, colapsar, editar o exportar se aplica al contenido dentro del contexto del Slot. Estas opciones no cambian la identidad de los bloques ni eliminan la responsabilidad del Composite Block de preservar la integridad de la jerarquía.

## 7. Validación

Antes de insertar un bloque dentro de un Composite Block, Workspace Engine debe validar la operación. La validación debe comprobar, como mínimo:

- que el tipo de bloque esté permitido por el Slot de destino;
- que no se exceda la cantidad máxima del Slot;
- que se cumplan las restricciones específicas del Slot;
- que se respeten las reglas propias del Composite Block;
- que la jerarquía conserve su integridad.

La integridad incluye evitar ciclos, evitar que un Leaf Block obtenga hijos y respetar el límite de profundidad definido para el árbol de Workspace. También debe preservarse la relación padre-hijo inmediata: los hijos no deben mantener dependencias directas hacia bloques hermanos, otras páginas o el Workspace completo.

No deben existir estructuras inválidas persistidas. Si un Slot obligatorio queda vacío por una operación permitida temporalmente, el sistema debe poder identificar de manera explícita el estado incompleto y aplicar una política de validación antes de considerar la estructura final válida, exportable o sincronizable.

```text
Solicitud de inserción
          │
          ▼
Validar Slot y Composite Block
          │
     ┌────┴────┐
     │         │
  válida    inválida
     │         │
     ▼         └── Rechazar sin alterar el árbol
Actualizar árbol
```

## 8. Jerarquía

La estructura conceptual de un bloque compuesto se organiza como un árbol donde el Slot media entre el Composite Block y sus hijos. El Slot no es un bloque de contenido; es una región semántica definida por el compuesto.

```text
Workspace
└── WorkspacePage
    └── CompositeBlock
        ├── Slot: región lógica A
        │   └── LeafBlock
        └── Slot: región lógica B
            └── LeafBlock
```

Un Slot puede contener varios bloques cuando su cardinalidad lo permita. Un hijo conoce solamente a su padre inmediato según el modelo de árbol y no debe usar el Slot como una vía para depender de elementos externos. Workspace Engine coordina cualquier operación que requiera comprender el contexto completo.

La profundidad debe mantenerse limitada. La ruta recomendada es Workspace → WorkspacePage → CompositeBlock → CompositeBlock opcional → LeafBlock. No deben permitirse anidamientos recursivos profundos que degraden el rendimiento, vuelvan ambigua la experiencia o dificulten las operaciones de migración y exportación.

## 9. Colapsado

Todo Composite Block puede soportar estados expandido, colapsado y parcialmente expandido. Estos estados permiten que una interfaz gestione la densidad de información sin modificar la estructura persistida.

En modo expandido se presenta el contenido de los Slots según sus reglas. En modo colapsado se muestra únicamente un resumen visual del compuesto. En modo parcialmente expandido se pueden mostrar regiones seleccionadas conforme al contrato del bloque. En todos los casos, los hijos continúan existiendo, conservan su orden, sus IDs, sus propiedades y su contenido.

```text
Expandido                    Colapsado
MeetingBlock                 MeetingBlock
├── Título                   └── resumen de reunión
├── Participantes
├── Pendientes
└── Conclusiones
```

El colapsado no elimina contenido ni es una forma de serialización alternativa. Es un estado de presentación aplicable sobre un árbol cuyo significado permanece intacto.

## 10. Acciones

Cada Composite Block puede definir acciones propias según sus reglas y capacidades. Entre las acciones posibles se encuentran agregar hijo, eliminar hijo, duplicar, mover, expandir, colapsar, convertir, exportar, compartir, bloquear y desbloquear.

Las acciones deben operar sobre el Composite Block como unidad y respetar todos sus Slots y descendientes. Mover un compuesto conserva su jerarquía; duplicarlo crea nuevas identidades para todo el subárbol y actualiza referencias internas; eliminarlo trata la jerarquía completa como una sola operación reversible; exportarlo incluye automáticamente el contenido de todos los Slots que participen en la exportación.

Cada acción puede aparecer automáticamente en la Toolbar Inteligente cuando una capa de interfaz determine que el compuesto está seleccionado y la acción está habilitada. La Toolbar no define las acciones: solo descubre y presenta capacidades declaradas por el modelo de bloque y autorizadas por sus reglas.

```text
Composite Block
├── acciones declaradas por el dominio
└── interfaz descubre acciones habilitadas
    └── Toolbar Inteligente las presenta cuando corresponde
```

## 11. Smart Blocks

Un Smart Block es un Composite Block con comportamiento propio. Además de organizar Slots y bloques hijos, define reglas de estructura, acciones y significado especializado para resolver un caso de uso reconocible.

MeetingBlock, UniversityNoteBlock, ResearchBlock, FlashcardBlock, ProjectBlock, KanbanBlock y CalendarBlock son ejemplos de Smart Blocks. Todos reutilizan bloques existentes: un Smart Block no debe duplicar la función de un TextBlock, una tabla, una lista, un adjunto o cualquier otro Leaf Block ya definido.

El comportamiento propio de un Smart Block debe residir en su contrato de estructura y en las reglas que aplica a sus Slots. Esto permite evolucionar el caso de uso sin crear una arquitectura paralela para cada tipo de contenido complejo.

```text
Smart Block
├── Composite Block
├── Slots con significado
├── reglas propias
└── acciones propias
```

## 12. Preparación para IA

Los Slots preparan el contenido para capacidades de IA porque aportan significado estructural. Sin Slots, dos TextBlock pueden ser indistinguibles en una jerarquía. Con Slots, el sistema puede reconocer que uno representa una pregunta y el otro una respuesta, o que un conjunto corresponde a la descripción, checklist, archivos y código de un proyecto.

```text
Sin Slots                       Con Slots
TextBlock                       FlashcardBlock
TextBlock                       ├── Pregunta: TextBlock
                                └── Respuesta: TextBlock
```

Esta semántica permite que una capacidad futura de IA interprete el propósito de cada región sin depender de inferencias frágiles sobre la apariencia o la posición visual. La IA podrá identificar automáticamente secciones de un proyecto, partes de una flashcard o componentes de una investigación a partir de los contratos de Slots.

La preparación para IA no significa que el modelo de bloque dependa de un proveedor o de una función específica. Significa que el contenido conserva estructura explícita, verificable y portable para que herramientas futuras puedan trabajar con él de manera confiable.

## 13. Preparación para Plantillas

Las plantillas oficiales del sistema deben construirse utilizando Composite Blocks. Nunca deben depender de pantallas especiales que codifiquen una estructura solo en la interfaz. Una plantilla es una composición reutilizable de Slots y bloques con reglas conocidas.

Las plantillas universitaria, de reunión, de proyecto, de diario y técnica son ejemplos de estructuras que deben poder expresarse mediante Composite Blocks. Al instanciar una plantilla, se crea una jerarquía de bloques independiente que conserva la forma definida por la plantilla y recibe nuevas identidades según las reglas de duplicación.

```text
Plantilla oficial
        │
        ▼
Composite Block con Slots
        │
        ▼
Instancia independiente de contenido
```

Este enfoque mantiene las plantillas exportables, migrables, comprensibles para IA y compatibles con cualquier interfaz que pueda interpretar el modelo de bloques.

## 14. Beneficios

La arquitectura de Composite Blocks, Smart Blocks y Slots aporta beneficios directos al crecimiento de Workspace:

- **Mayor reutilización:** las capacidades nuevas combinan bloques existentes en lugar de recrear contenido básico.
- **Menor duplicación:** se evita repetir modelos, reglas de datos y lógica de exportación para cada caso de uso.
- **Escalabilidad:** pueden incorporarse nuevos compuestos mediante contratos de bloques y Slots sin modificar el fundamento del árbol.
- **Compatibilidad con IA:** los Slots proporcionan semántica explícita para interpretar cada región del contenido.
- **Compatibilidad con Canvas:** las estructuras pueden preservar organización y relaciones aunque una interfaz las presente en una superficie espacial.
- **Compatibilidad con OCR:** los resultados de reconocimiento pueden ocupar Slots con significado, como texto extraído, fuente o evidencia asociada.
- **Compatibilidad con Handwriting:** el contenido manuscrito puede formar parte de una composición sin requerir un modelo paralelo.
- **Compatibilidad con futuras funciones:** la independencia entre estructura, contenido y presentación facilita migración, exportación, sincronización y evolución del producto.

## 15. Principios oficiales

Los siguientes principios son obligatorios para cualquier extensión del Block SDK:

- **Los Composite Blocks representan estructuras.** Su responsabilidad es organizar contenido y definir reglas de composición.
- **Los Leaf Blocks representan contenido.** Su responsabilidad es expresar una unidad indivisible y no contener hijos.
- **Los Slots representan significado.** Definen regiones lógicas con propósito, cardinalidad y tipos permitidos.
- **Nunca utilizar listas desordenadas de hijos cuando el contenido tenga semántica.** Si la función de los hijos importa, debe expresarse mediante Slots.
- **Toda estructura debe ser comprensible para usuarios, desarrolladores e IA.** El significado debe estar en los datos y contratos, no solo en una convención visual.
- **Siempre preferir composición antes que crear nuevos tipos de bloques.** Un tipo especializado solo se justifica cuando una estructura y reglas reutilizables no pueden expresar correctamente la necesidad.

La conclusión es que el Block SDK debe crecer mediante composición semántica. Los bloques simples conservan contenido reutilizable, los Composite Blocks construyen estructuras y los Slots hacen explícito el significado de cada región. Este modelo preserva la coherencia de Workspace mientras habilita capacidades futuras sin comprometer su arquitectura.
