# Composite Blocks

Versión 1.0

## Introducción

Workspace utiliza el patrón Composite como mecanismo oficial para construir estructuras de contenido complejas a partir de bloques independientes. Este documento establece las categorías de bloques, las reglas del árbol de contenido y los contratos conceptuales que deben respetar las futuras implementaciones.

El objetivo es permitir que Workspace crezca mediante composición. Cuando una nueva capacidad pueda construirse reuniendo bloques existentes, debe preferirse esta estrategia antes que crear un tipo especializado que replique datos, reglas o comportamientos ya disponibles.

## 1. Modelo de bloques

Workspace reconoce dos grandes categorías: **Leaf Blocks** y **Composite Blocks**. Ambas son bloques y participan en el mismo modelo de contenido, pero tienen responsabilidades distintas.

```text
Workspace
└── WorkspacePage
    ├── Leaf Block
    ├── Leaf Block
    └── Composite Block
        ├── Leaf Block
        └── Leaf Block
```

### Leaf Blocks

Los Leaf Blocks son bloques simples. Representan una única unidad de contenido y no pueden contener otros bloques. Su responsabilidad es encapsular su contenido y las propiedades necesarias para interpretarlo dentro del modelo de Workspace.

Ejemplos de Leaf Blocks son:

- TextBlock
- ImageBlock
- ChecklistBlock
- CodeBlock
- TableBlock
- AttachmentBlock
- DividerBlock
- QuoteBlock
- CalloutBlock
- InkBlock
- AudioBlock
- VideoBlock
- PdfBlock

Un Leaf Block no debe adquirir capacidad de contención por conveniencia de una interfaz o de una funcionalidad concreta. Si una estructura necesita reunir varios bloques, debe utilizarse un Composite Block.

### Composite Blocks

Los Composite Blocks son bloques contenedores. Su responsabilidad principal es organizar otros bloques y expresar una estructura reutilizable; no representan únicamente una pieza de contenido aislada. Cada Composite Block puede definir reglas propias para sus hijos y seguir participando, frente al usuario, como una sola unidad de trabajo.

Ejemplos futuros de Composite Blocks son:

- GroupBlock
- SectionBlock
- TemplateBlock
- MeetingBlock
- ProjectBlock
- FlashcardBlock
- ScanBlock
- CanvasBlock
- MindMapBlock
- DiagramBlock

La composición permite construir capacidades complejas sin duplicar los bloques que ya expresan contenido básico. Por ejemplo:

```text
MeetingBlock
├── TextBlock
├── ChecklistBlock
├── TableBlock
└── TextBlock

FlashcardBlock
├── TextBlock (pregunta)
└── TextBlock (respuesta)

ScanBlock
├── ImageBlock
├── PdfBlock
└── TextBlock (OCR)

ProjectBlock
├── ChecklistBlock
├── TableBlock
├── CodeBlock
├── ImageBlock
└── AttachmentBlock
```

## 2. Árbol de bloques

Los bloques de una WorkspacePage se organizan como un árbol. La página contiene bloques raíz; un bloque compuesto puede contener hijos; y los Leaf Blocks terminan una rama porque no pueden contener otros bloques.

```text
Workspace
└── WorkspacePage
    ├── TextBlock
    ├── ImageBlock
    ├── GroupBlock
    │   ├── ChecklistBlock
    │   ├── CodeBlock
    │   └── ImageBlock
    ├── TableBlock
    └── AttachmentBlock
```

El árbol debe conservar identidades estables, relaciones padre-hijo explícitas y el orden necesario para cada contenedor. Las estructuras complejas no deben dispersarse entre modelos paralelos ni depender de la jerarquía visual de una interfaz.

El sistema debe recorrer el árbol mediante el patrón Visitor o una estrategia equivalente, centralizada y extensible. No deben existir múltiples recorridos manuales con condicionales distribuidos por el código para operaciones como validar, exportar, duplicar o eliminar. La estrategia elegida debe permitir incorporar nuevos tipos de bloques sin duplicar la lógica de recorrido.

## 3. Reglas del patrón Composite

### 3.1 Capacidad de contención

No todos los bloques pueden contener hijos. Únicamente los Composite Blocks tienen esa capacidad. Los Leaf Blocks nunca pueden tener bloques hijos.

Esta regla mantiene claro el significado de cada categoría y evita árboles ambiguos. La necesidad de agrupar contenido es una razón para usar o definir un Composite Block, no para ampliar arbitrariamente un bloque simple.

### 3.2 Relaciones de los hijos

Un bloque hijo conoce únicamente a su padre inmediato. No conoce el Workspace completo, otras páginas ni bloques hermanos. No debe asumir rutas de navegación, estructuras externas o estados de interfaz para cumplir su función.

Toda comunicación y coordinación entre entidades ocurre mediante Workspace Engine. Esta restricción evita dependencias laterales, permite mover subárboles sin romper su semántica y preserva el modelo de contenido como una estructura controlada.

```text
Workspace Engine
       │
       ▼
Composite Block
 ├── Child A  ── conoce solo a su padre
 └── Child B  ── conoce solo a su padre
```

### 3.3 Profundidad limitada

La profundidad del árbol debe ser limitada para proteger rendimiento, mantenibilidad y comprensión del contenido. La profundidad máxima recomendada es:

```text
Workspace
└── WorkspacePage
    └── CompositeBlock
        └── CompositeBlock
            └── LeafBlock
```

No deben permitirse estructuras recursivas profundas o indefinidas. La implementación concreta debe validar este límite antes de aceptar una inserción o transformación que incremente la profundidad. Si una necesidad de producto exige una excepción, debe definirse de forma explícita a nivel arquitectónico, no como un caso especial local.

### 3.4 Movimiento de un compuesto

Mover un Composite Block mueve automáticamente toda su jerarquía. La operación debe conservar los identificadores existentes, las referencias internas, el orden de hijos y las propiedades de cada nodo. No debe descomponer el grupo ni recrear sus bloques como efecto secundario.

```text
Antes                         Después
Page A                        Page B
└── GroupBlock                └── GroupBlock
    ├── Child 1                   ├── Child 1
    └── Child 2                   └── Child 2
```

### 3.5 Duplicación de un compuesto

Duplicar un Composite Block duplica toda la jerarquía descendiente. Cada bloque de la copia debe recibir un UUID nuevo, incluido el bloque compuesto raíz. Las referencias internas de la copia deben actualizarse para apuntar exclusivamente a las nuevas entidades, mientras que la jerarquía, el orden, las propiedades y el contenido se conservan de forma equivalente.

Las referencias externas no deben copiarse de manera ciega. Cualquier referencia cuyo destino esté fuera del subárbol debe tratarse según una política explícita del tipo de bloque o de la operación de duplicación, para evitar vínculos inválidos o inesperados.

### 3.6 Eliminación de un compuesto

Eliminar un Composite Block elimina toda la jerarquía asociada. La operación debe tratar el subárbol como una unidad consistente y conservar la información necesaria para que Undo pueda restaurarlo exactamente.

La restauración debe recuperar posición, orden, IDs, propiedades, contenido y selección. Esto exige que la eliminación no se implemente como una pérdida irreversible de datos mientras la operación pueda ser deshecha. La definición concreta de Undo pertenece a documentación posterior, pero este requisito de integridad es obligatorio para el modelo de bloques compuestos.

### 3.7 Exportación

Exportar un Composite Block exporta automáticamente todos sus hijos. Cada exportador decide cómo representar la jerarquía según el formato de destino, pero no puede ignorar contenido descendiente por el hecho de estar contenido.

La exportación debe partir del árbol de datos y de sus relaciones, no de una captura de una interfaz. Esto permite conservar significado estructural cuando el formato de destino lo soporte y aplicar una degradación documentada cuando no lo soporte.

### 3.8 Tipos de hijos admitidos

Cada Composite Block puede definir reglas sobre los tipos de bloques que acepta. Esta validación evita estructuras inconsistentes y hace explícita la finalidad de cada compuesto.

Ejemplos:

```text
FlashcardBlock
└── acepta únicamente TextBlock

MeetingBlock
├── TextBlock
├── ChecklistBlock
├── TableBlock
└── AttachmentBlock

ScanBlock
├── ImageBlock
├── PdfBlock
└── TextBlock
```

Las restricciones de admisión deben validarse antes de modificar el árbol. Un Composite Block que no declare reglas especiales puede utilizar una política general documentada, pero no debe aceptar contenido incompatible de forma implícita.

### 3.9 Comportamiento configurable

Cada Composite Block puede decidir, como parte de su contrato, si permite:

- agregar hijos;
- eliminar hijos;
- reordenar hijos;
- colapsar contenido;
- expandir contenido;
- duplicar hijos;
- bloquear edición.

Estas capacidades deben expresarse como reglas de dominio configurables, no como comportamientos codificados exclusivamente en la interfaz. Una capa de presentación puede reflejar las reglas, pero no debe ser la única encargada de impedir operaciones inválidas.

### 3.10 Unidad de trabajo para el usuario

Un Composite Block debe poder actuar como un único bloque desde la perspectiva del usuario. El usuario debe poder moverlo, duplicarlo, eliminarlo, exportarlo y compartirlo sin tener que manipular individualmente cada bloque interno.

El hecho de que el compuesto sea una unidad de operación no elimina la independencia de sus hijos. Significa que Workspace Engine debe poder aplicar operaciones al subárbol completo de forma atómica y consistente.

## 4. Colapsado y expansión

Los Composite Blocks pueden soportar estados expandido y colapsado. En estado expandido, su jerarquía puede presentarse para permitir la interacción permitida por sus reglas. En estado colapsado, la interfaz muestra únicamente un resumen visual de la estructura o de su contenido relevante.

El colapsado es una decisión de presentación sobre una jerarquía que sigue existiendo íntegramente en el modelo. No elimina hijos, no modifica sus IDs, no altera el orden ni cambia sus propiedades. Las operaciones del motor deben tratar el subárbol del mismo modo independientemente de que una interfaz lo muestre expandido o colapsado.

```text
Expandido                       Colapsado
GroupBlock                      GroupBlock
├── ChecklistBlock              └── resumen visual
├── CodeBlock
└── ImageBlock
```

## 5. Reutilización y extensibilidad

El objetivo principal del patrón Composite es construir nuevas funcionalidades mediante bloques ya existentes. Una composición adecuada permite que una capacidad nueva añada estructura y reglas sin duplicar la representación del texto, listas, archivos, imágenes u otros contenidos básicos.

Ejemplos futuros que deben preferir composición cuando sea posible:

- TemplateBlock
- MeetingBlock
- UniversityNoteBlock
- ResearchBlock
- ProjectBlock
- KanbanBlock
- CalendarBlock
- FlashcardBlock
- TimelineBlock
- MindMapBlock

La creación de un nuevo Composite Block no debe requerir modificar la arquitectura del sistema. Debe integrarse a través de los contratos de bloque, las reglas de admisión y la estrategia central de recorrido. Su valor proviene de organizar y especializar bloques existentes, no de duplicar sus modelos o de introducir dependencias hacia una interfaz concreta.

## 6. Principio oficial

Workspace utilizará el patrón Composite como mecanismo oficial para construir estructuras complejas. Siempre que una nueva funcionalidad pueda componerse reutilizando bloques existentes, deberá preferirse esta estrategia antes de crear nuevos tipos especializados.

Este principio garantiza mayor reutilización, menor duplicación de código, mejor mantenibilidad y una escalabilidad compatible con futuras capacidades como IA, OCR, Canvas, plantillas y handwriting. También mantiene el modelo coherente: los bloques simples conservan una responsabilidad clara, mientras que los bloques compuestos proporcionan las estructuras necesarias para combinar esas unidades sin fragmentar la arquitectura.

La decisión final para cualquier extensión debe responder a una pregunta: ¿puede esta capacidad expresarse como una composición de bloques existentes con reglas adicionales? Si la respuesta es sí, la composición es la solución arquitectónicamente preferida.
