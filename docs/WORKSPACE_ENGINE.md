# Workspace Engine

Versión 1.0

## Introducción

Workspace Engine es el núcleo de datos de Workspace. Este documento define su responsabilidad conceptual, el modelo que administra y los límites que deben preservarse en cualquier implementación futura. Su finalidad es permitir que el conocimiento de un usuario permanezca estructurado, durable y portable aunque evolucionen las interfaces, los dispositivos o los mecanismos concretos de almacenamiento.

El motor no es una interfaz ni un sistema de presentación. Es la capa que representa qué existe dentro de Workspace, cómo se organiza, cómo se relaciona y cómo puede conservarse a lo largo del tiempo. Toda implementación debe respetar este documento como contrato arquitectónico.

## Objetivos

Workspace Engine debe proporcionar un modelo consistente para organizar espacios de trabajo, páginas y bloques; preservar la integridad y evolución de los datos; y ofrecer los límites necesarios para que persistencia, migraciones y sincronización puedan incorporarse sin acoplar el contenido a tecnologías específicas.

No define elementos visuales, interacciones de usuario ni reglas de renderizado. Es deliberadamente independiente de cualquier framework de interfaz.

## 1. ¿Qué es Workspace Engine?

Workspace Engine es el núcleo del sistema que define el dominio de Workspace. Es responsable de describir qué información existe, cómo se estructura, cómo se almacena mediante abstracciones, cómo se organiza y cómo se relaciona. Su trabajo consiste en preservar significado e identidad de los datos, no en decidir cómo se muestran.

El motor conoce entidades de dominio, sus propiedades, relaciones, versiones y reglas de evolución. Por ejemplo, conoce que un Workspace posee páginas y que una página contiene bloques; conoce también los identificadores, la metadata y el estado necesario para conservar estas entidades. No interpreta esos datos como componentes visuales.

Workspace Engine no conoce Flutter, Widgets, RenderObjects, gestos ni pantallas. Tampoco debe introducir dependencias hacia conceptos de ciclo de vida de interfaz, coordenadas de componentes visuales o estados temporales de navegación. Estas preocupaciones pertenecen a capas externas que consumen los datos del motor.

La separación es obligatoria: una interfaz puede crear, consultar o actualizar contenido mediante el motor, pero no puede definir la semántica del contenido. De este modo, el mismo Workspace puede sobrevivir a un rediseño, a una nueva plataforma o a una forma alternativa de acceso.

## 2. Responsabilidades

Workspace Engine administra el ciclo de vida lógico de las entidades de Workspace y establece las reglas que permiten conservarlas con estabilidad.

- **Workspaces:** crea, identifica, consulta, actualiza y clasifica los espacios de trabajo como unidades principales de organización.
- **Workspace Pages:** administra las superficies que pertenecen a un Workspace, su orden lógico y la información necesaria para interpretarlas.
- **Blocks:** mantiene las unidades independientes de contenido, sus identidades, su pertenencia a una página y sus relaciones con el contenido que representan.
- **Historial:** conserva la información de cambios necesaria para comprender la evolución del contenido y habilitar políticas futuras de recuperación o auditoría, sin definir una interfaz de historial.
- **Persistencia:** coordina la lectura y escritura a través de contratos de repositorio, preservando el dominio frente a detalles de infraestructura.
- **Versionado:** asigna y valida versiones de entidad y de esquema para que los cambios puedan evolucionar sin destruir datos existentes.
- **Metadata:** administra datos complementarios extensibles que no deben alterar la identidad o la semántica base de una entidad.
- **Templates:** representa estructuras reutilizables que pueden servir como punto de partida para nuevos Workspaces o páginas, manteniendo la independencia entre la plantilla y sus instancias.
- **Autosave:** define la necesidad de persistir cambios de manera segura y oportuna mediante los repositorios, sin depender de eventos o componentes de interfaz concretos.
- **Migraciones:** transforma datos de esquemas anteriores hacia versiones compatibles de forma explícita, verificable y no destructiva.
- **Preparación para sincronización:** mantiene identificadores estables, versiones, marcas temporales y metadatos necesarios para que una capa futura pueda sincronizar contenido sin redefinir el modelo de dominio.

Workspace Engine no administra zoom, scroll, gestos, animaciones ni renderizado. Puede conservar datos que una capa externa necesite interpretar, como un layout o un viewport conceptual, pero no calcula transformaciones visuales, no responde a eventos de puntero y no produce componentes de pantalla.

El siguiente límite resume la responsabilidad:

```text
Entrada de datos y acciones de dominio
                │
                ▼
        Workspace Engine
                │
                ├── Modelo y reglas de datos
                ├── Versionado y migraciones
                └── Repositorios abstractos

Interfaz, gestos y renderizado permanecen fuera del motor.
```

## 3. Modelo general

El modelo conceptual de Workspace se organiza en cuatro niveles: Workspace, WorkspacePage, Block y Content. Cada nivel tiene una responsabilidad distinta y evita que el contenido se convierta en una estructura monolítica.

```text
Workspace
    │
    ├── WorkspacePage
    │       │
    │       ├── Block
    │       │      └── Content
    │       └── Block
    │              └── Content
    │
    └── WorkspacePage
            └── Block
                   └── Content
```

**Workspace** es el contenedor principal y representa un contexto de trabajo identificable. Agrupa páginas, define información global y conserva la identidad del conjunto.

**WorkspacePage** es una superficie lógica perteneciente a un Workspace. Determina el contexto de organización de sus bloques y el modo conceptual en que esa superficie será interpretada por una interfaz.

**Block** es una unidad independiente y componible dentro de una página. Tiene identidad propia, puede ubicarse u ordenarse según el layout de la página y encapsula un tipo de contenido sin depender de la representación visual que se use para mostrarlo.

**Content** es la información específica que porta un bloque. Su estructura depende de la naturaleza del bloque, pero su existencia siempre se entiende dentro de un contrato de datos y nunca como un widget o una pantalla.

Este modelo permite que el contenedor, la superficie, la unidad de composición y el contenido evolucionen por separado. Una modificación del modo de presentación no debe alterar la relación fundamental entre estos niveles.

## 4. Workspace

Workspace representa la entidad raíz del dominio. Es el contexto durable que agrupa páginas, conserva información global y permite reconocer un conjunto de trabajo a través del tiempo. No debe confundirse con una vista, una pestaña o una pantalla: puede ser presentado de muchas maneras sin dejar de ser la misma entidad.

Sus propiedades conceptuales son las siguientes:

- **id:** identificador único, estable y no reutilizable del Workspace. Debe permitir referenciarlo sin depender de su título, ubicación visual o mecanismo de almacenamiento.
- **title:** nombre legible para las personas. Puede cambiar sin modificar la identidad del Workspace.
- **description:** contexto descriptivo opcional que ayuda a comprender el propósito del espacio de trabajo.
- **workspaceType:** clasificación que indica el tipo conceptual de Workspace y permite seleccionar reglas compatibles de organización y presentación.
- **createdAt:** marca temporal de creación. Es parte del registro de procedencia y no debe reinterpretarse como fecha de última modificación.
- **updatedAt:** marca temporal de la última modificación significativa persistida. Sirve para ordenamiento, trazabilidad y preparación para sincronización.
- **deletedAt:** marca temporal opcional de eliminación lógica. Su presencia indica que la entidad no debe aparecer como activa, pero puede ser recuperable o tratable según las políticas futuras.
- **favorite:** indicador de prioridad personal. No cambia el contenido ni la pertenencia de las páginas; únicamente expresa una preferencia de organización del usuario.
- **archived:** indicador que separa un Workspace activo de uno conservado para consulta. Archivar no equivale a eliminar.
- **tags:** colección de etiquetas semánticas para clasificación y búsqueda. Las etiquetas complementan la organización, pero no sustituyen la estructura de páginas.
- **metadata:** información adicional con namespace y significado documentado. Debe ser extensible sin convertirla en un depósito de datos esenciales no modelados.
- **version:** versión de la entidad para controlar cambios y preparar mecanismos de concurrencia o sincronización. Es distinta de la versión del esquema general.
- **pages:** colección ordenada de WorkspacePage que pertenecen al Workspace. La relación de pertenencia debe conservarse aunque una interfaz las muestre mediante pestañas, listas u otros mecanismos.

La responsabilidad de Workspace es preservar la identidad y el contexto global. No debe contener detalles de componentes de interfaz ni asumir un modo único de visualización para sus páginas.

```text
Workspace
├── Identidad y contexto global
├── Estado organizativo: favorito, archivado, etiquetas
├── Trazabilidad: creación, actualización, eliminación lógica, versión
└── Páginas pertenecientes al Workspace
```

## 5. WorkspacePage

WorkspacePage representa una superficie lógica dentro de un Workspace. Es el nivel donde se reúnen bloques que comparten un contexto de organización y un layout. Una página puede interpretarse como una página documental, una superficie libre o cualquier otro modo compatible con su tipo, pero su identidad no depende de la pantalla donde se muestre.

Sus propiedades conceptuales son:

- **id:** identificador único y estable de la página.
- **workspaceId:** referencia explícita al Workspace propietario. Esta relación debe ser válida y no depender del orden en que una interfaz cargue las entidades.
- **title:** nombre legible que permite distinguir la página dentro de su Workspace.
- **layout:** definición conceptual del modo en que los bloques se organizan e interpretan. Indica reglas de disposición, no componentes ni instrucciones de renderizado.
- **blocks:** colección de bloques que pertenecen a la página. La colección debe conservar el orden o la información espacial que requiera el layout correspondiente.
- **viewport:** estado conceptual persistible de referencia para una superficie cuando resulte necesario. No representa un controlador visual ni un gesto; es información de dominio que una interfaz puede decidir utilizar o ignorar de forma compatible.
- **metadata:** información complementaria extensible con significado definido, sin sustituir propiedades fundamentales.
- **version:** versión de la entidad para evolución, detección de cambios y preparación para sincronización.
- **createdAt:** marca temporal de creación de la página.
- **updatedAt:** marca temporal de la última modificación significativa persistida.

Una página nunca debe contener Widgets. Un Widget es una decisión temporal de Flutter para construir una interfaz; una WorkspacePage es un dato durable del dominio. Incluir Widgets en la página haría imposible conservarla sin Flutter, dificultaría la persistencia, la exportación, las migraciones y cualquier implementación futura en otra plataforma. La página describe qué bloques existen y cómo se organizan conceptualmente; una capa de presentación decide cómo convertir esa información en una experiencia visual.

## 6. Workspace Types

Workspace Engine reconoce una clasificación extensible de tipos de Workspace. Estos tipos describen la intención estructural del espacio de trabajo, no una implementación cerrada de pantalla.

- **Document:** espacio orientado a contenido en flujo y organizado secuencialmente. Es el único tipo activo inicialmente y establece la primera experiencia funcional de la plataforma.
- **Canvas:** espacio preparado para contenido con posición libre, donde las relaciones espaciales pueden ser relevantes.
- **Whiteboard:** espacio orientado a diagramas, exploración visual y conexiones entre elementos.
- **MindMap:** espacio orientado a relaciones jerárquicas o radiales entre ideas.
- **Timeline:** espacio orientado a eventos, secuencias y relaciones temporales.
- **Presentation:** espacio orientado a una secuencia de unidades destinadas a comunicar contenido de forma progresiva.

Los tipos distintos de Document existen desde el modelo conceptual para permitir crecimiento futuro con compatibilidad arquitectónica. Su presencia no autoriza a implementar sus interfaces, comportamientos o capacidades antes de que se definan formalmente. En la etapa inicial, únicamente Document estará activo; los demás tipos deben permanecer como posibilidades de evolución del dominio.

```text
WorkspaceType
├── Document      ← activo inicialmente
├── Canvas        ← preparado para evolución futura
├── Whiteboard    ← preparado para evolución futura
├── MindMap       ← preparado para evolución futura
├── Timeline      ← preparado para evolución futura
└── Presentation  ← preparado para evolución futura
```

## 7. Layouts

El layout define las reglas conceptuales para organizar bloques dentro de una WorkspacePage. No es una pantalla ni una implementación visual; establece la información que el modelo debe conservar para que una capa externa pueda interpretar la página de forma coherente.

**Document Layout** organiza los bloques en un flujo vertical. La secuencia es significativa: los bloques se leen y se procesan en orden, y la estructura debe poder expresar inserciones, reordenamientos y continuidad sin depender de posiciones absolutas de pantalla.

```text
Document Layout
┌─────────────────────┐
│ Block 1             │
├─────────────────────┤
│ Block 2             │
├─────────────────────┤
│ Block 3             │
└─────────────────────┘
           ↓
     flujo vertical
```

**Canvas Layout** organiza los bloques mediante posición libre dentro de una superficie conceptual. La relación espacial de cada bloque forma parte de los datos del layout, de manera que la disposición pueda persistir e interpretarse en distintos entornos. El motor conserva la información espacial necesaria, pero no calcula zoom, scroll ni transformaciones de interfaz.

```text
Canvas Layout
┌───────────────────────────────┐
│  [Block 1]                    │
│                    [Block 2]  │
│        [Block 3]              │
└───────────────────────────────┘
              posición libre
```

**Whiteboard Layout** está pensado para diagramas. Debe permitir representar elementos visuales y sus relaciones conceptuales, conservando la información necesaria para que una capa externa exprese conexiones y agrupaciones. A diferencia del Canvas general, su intención principal es estructurar pensamiento visual y diagramático; sus reglas futuras deben mantener esta finalidad sin acoplarse a un motor de renderizado concreto.

```text
Whiteboard Layout
┌───────────────────────────────┐
│  [Idea A] ────────> [Idea B]  │
│       │                       │
│       └──────────> [Idea C]   │
└───────────────────────────────┘
       pensado para diagramas
```

La diferencia central es la siguiente: Document Layout prioriza el flujo vertical; Canvas Layout prioriza la posición libre; Whiteboard Layout prioriza relaciones diagramáticas. Estas diferencias deben resolverse mediante datos y contratos de layout, nunca mediante dependencias directas de la interfaz.

## 8. Versionado

El versionado protege la continuidad del contenido de Workspace. El motor debe distinguir, como mínimo, entre la versión del esquema de datos y la versión de cada entidad. La versión de esquema, usualmente expresada como `schemaVersion`, identifica cómo debe interpretarse la estructura persistida. La versión de entidad identifica cambios sobre un Workspace, una página o un bloque particular.

`schemaVersion` es esencial porque el modelo evolucionará. Cuando se agreguen propiedades, se refinen formatos o se introduzcan nuevas reglas, el motor debe saber qué estructura originó un conjunto de datos antes de interpretarlo. No debe suponer que todos los datos almacenados tienen la forma más reciente.

Los Workspaces antiguos nunca deben romperse. Una actualización no puede convertir contenido previo en información ilegible, ambigua o descartable. La compatibilidad debe tratarse como una responsabilidad del motor: cada cambio de esquema debe incluir una ruta de interpretación o transformación para los datos existentes.

Las migraciones deben ser explícitas, incrementales, deterministas y verificables. Una estrategia adecuada identifica la versión de origen, aplica transformaciones ordenadas hacia versiones posteriores, conserva información que no pueda interpretarse de inmediato y registra errores de forma recuperable. Las migraciones no deben depender de la interfaz ni requerir que el usuario reconstruya manualmente su contenido.

Cuando un cambio no pueda representarse sin pérdida, la arquitectura debe preferir la conservación y la trazabilidad antes que la eliminación silenciosa. Exportar o respaldar datos antes de una transformación relevante es una medida compatible con este principio, siempre que se mantenga el contrato de repositorios y la independencia del dominio.

```text
Datos persistidos
       │
       ▼
Leer schemaVersion
       │
       ├── Versión actual ─────────────► Interpretar
       │
       └── Versión anterior ───────────► Migrar paso a paso
                                             │
                                             ▼
                                        Validar y persistir
```

## 9. Persistencia

Workspace Engine requiere que los datos puedan sobrevivir entre sesiones, pero no conoce la tecnología que lo hace posible. Su relación con la persistencia se limita a repositorios definidos por contratos de dominio: el motor solicita guardar, obtener, listar, actualizar o eliminar lógicamente entidades sin saber dónde ni cómo se ejecutan esas operaciones.

El motor nunca conoce SQLite, Drift ni SharedPreferences. Estas son decisiones de infraestructura y pueden cambiar según la plataforma, el rendimiento, la estrategia de distribución o la evolución del producto. Ninguna de ellas debe filtrarse hacia las entidades de Workspace ni hacia sus reglas de negocio.

Los repositorios actúan como frontera arquitectónica:

```text
Workspace Engine
        │
        ▼
Contratos de repositorio
        │
        ▼
Infraestructura de persistencia
  (tecnología intercambiable)
```

Esta separación permite sustituir, combinar o adaptar mecanismos de almacenamiento sin redefinir qué es un Workspace, una página o un bloque. También facilita pruebas de las reglas de dominio con implementaciones controladas de repositorio y preserva la portabilidad del modelo de datos.

Autosave se apoya en esta misma frontera. El motor puede establecer que ciertos cambios deben persistirse de forma segura y consistente, pero la programación concreta de eventos de interfaz, temporizadores visuales o señales del sistema operativo no forma parte de su dominio. La persistencia debe ser localmente confiable y preparada para que una sincronización futura pueda operar sobre entidades identificables y versionadas.

## 10. Filosofía

Las siguientes reglas definen la orientación permanente de Workspace Engine:

- **Workspace es eterno.** El espacio de trabajo debe conservar su identidad, significado y contenido a través de rediseños, migraciones y cambios tecnológicos.
- **Las páginas son reutilizables.** Una página es una unidad de estructura que debe poder crearse desde patrones, duplicarse o adaptarse sin depender de una pantalla específica.
- **Los bloques son independientes.** Cada bloque debe tener identidad y contenido propios, de forma que pueda evolucionar, organizarse y tratarse sin convertir toda la página en una unidad indivisible.
- **Todo debe poder migrarse.** La evolución del modelo debe mantener rutas claras de compatibilidad para el contenido existente.
- **Todo debe poder exportarse.** Los datos deben conservar una semántica suficientemente clara para poder representarse o transferirse sin quedar encerrados en una interfaz o tecnología.
- **Todo debe poder sincronizarse.** Las entidades deben contar con identidad estable, versiones y trazabilidad suficientes para que una capacidad futura de sincronización pueda incorporarse sin reemplazar el modelo fundamental.

La conclusión arquitectónica es simple: Workspace Engine protege el contenido antes que cualquier implementación temporal. Su éxito se mide por la capacidad de conservar y hacer evolucionar los datos con coherencia, mientras otras capas se encargan de las formas concretas en que esos datos se presentan o interactúan.
