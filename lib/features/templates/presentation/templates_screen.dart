import 'package:allministrator/app/theme/app_icons.dart';
import 'package:allministrator/app/theme/app_radius.dart';
import 'package:allministrator/app/theme/app_spacing.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/domain/services/starter_document_service.dart';
import 'package:allministrator/features/shared/presentation/app_empty_state.dart';
import 'package:allministrator/features/shared/presentation/main_navigation_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({required this.repository, super.key});

  final DocumentRepository repository;

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  late final StarterDocumentService _starterDocuments;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _category;
  String? _creatingId;

  @override
  void initState() {
    super.initState();
    _starterDocuments = StarterDocumentService(widget.repository);
    _searchController.addListener(_searchChanged);
  }

  void _searchChanged() => setState(() => _query = _searchController.text);

  @override
  void dispose() {
    _searchController
      ..removeListener(_searchChanged)
      ..dispose();
    super.dispose();
  }

  List<_StarterTemplate> get _visibleTemplates {
    final query = _query.trim().toLowerCase();
    return _templates.where((template) {
      if (_category != null && template.group != _category) return false;
      return query.isEmpty ||
          template.name.toLowerCase().contains(query) ||
          template.description.toLowerCase().contains(query) ||
          template.group.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleTemplates = _visibleTemplates;
    return MainNavigationScaffold(
      title: 'Plantillas',
      selectedPath: '/templates',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TemplatesHero(count: _templates.length),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar una plantilla',
                      prefixIcon: const Icon(AppIcons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.clear_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Todas'),
                          selected: _category == null,
                          onSelected: (_) => setState(() => _category = null),
                        ),
                        for (final group in _templateGroups) ...[
                          const SizedBox(width: AppSpacing.sm),
                          ChoiceChip(
                            label: Text(group),
                            selected: _category == group,
                            onSelected: (_) =>
                                setState(() => _category = group),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (visibleTemplates.isEmpty)
                    SizedBox(
                      height: 380,
                      child: AppEmptyState(
                        icon: AppIcons.search,
                        title: 'No encontramos esa plantilla',
                        message:
                            'Prueba con otra búsqueda o explora todas las categorías.',
                        actionLabel: 'Ver todas',
                        onAction: () => setState(() {
                          _searchController.clear();
                          _category = null;
                        }),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) => GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visibleTemplates.length,
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: constraints.maxWidth < 420
                              ? 420
                              : 340,
                          mainAxisExtent: 296,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                        ),
                        itemBuilder: (context, index) {
                          final template = visibleTemplates[index];
                          return _TemplateCard(
                            template: template,
                            creating: _creatingId == template.id,
                            enabled: _creatingId == null,
                            onPreview: () => _preview(template),
                            onCreate: () => _create(template),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(_StarterTemplate template) async {
    if (_creatingId != null) return;
    setState(() => _creatingId = template.id);
    try {
      final document = await _starterDocuments.create(
        title: template.name,
        blocks: _buildTemplateBlocks(template.id),
        categoryId: template.categoryId,
        layoutType: template.layoutType,
      );
      if (mounted) context.go('/editor/${document.id}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo crear la plantilla: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingId = null);
    }
  }

  Future<void> _preview(_StarterTemplate template) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(template.name),
      content: _TemplatePreview(template: template),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: _creatingId == null
              ? () {
                  Navigator.pop(context);
                  _create(template);
                }
              : null,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Usar plantilla'),
        ),
      ],
    ),
  );
}

class _TemplatesHero extends StatelessWidget {
  const _TemplatesHero({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.secondaryContainer,
            Color.alphaBlend(
              colors.primary.withValues(alpha: .13),
              colors.surfaceContainerLow,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No empieces desde cero',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$count puntos de partida listos para personalizar en Documento o Canvas.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSecondaryContainer.withValues(alpha: .82),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Icon(
            AppIcons.templatesSelected,
            size: 56,
            color: colors.onSecondaryContainer,
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.creating,
    required this.enabled,
    required this.onPreview,
    required this.onCreate,
  });

  final _StarterTemplate template;
  final bool creating;
  final bool enabled;
  final VoidCallback onPreview;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: enabled ? onPreview : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: template.color.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(
                    template.layoutType == WorkspaceLayoutType.canvas
                        ? Icons.dashboard_customize_outlined
                        : template.icon,
                    color: template.color,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: template.color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        template.layoutType == WorkspaceLayoutType.canvas
                            ? 'Canvas · ${template.group}'
                            : template.group,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(template.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Text(
                template.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: enabled ? onCreate : null,
                icon: creating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(creating ? 'Creando…' : 'Usar plantilla'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TemplatePreview extends StatelessWidget {
  const _TemplatePreview({required this.template});
  final _StarterTemplate template;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 420),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: template.layoutType == WorkspaceLayoutType.canvas ? 188 : 150,
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: template.color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: template.layoutType == WorkspaceLayoutType.canvas
              ? Stack(
                  children: [
                    _note('Idea principal', Alignment.topLeft),
                    _note('Siguiente paso', Alignment.bottomRight),
                    Center(
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: template.color,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 130,
                      height: 10,
                      color: template.color.withValues(alpha: .72),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final width in const [1.0, .82, .92, .64])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FractionallySizedBox(
                          widthFactor: width,
                          child: Container(height: 7, color: Colors.black12),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(template.description),
      ],
    ),
  );

  Widget _note(String text, Alignment alignment) => Align(
    alignment: alignment,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text),
    ),
  );
}

class _StarterTemplate {
  const _StarterTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.group,
    required this.categoryId,
    required this.icon,
    required this.color,
    this.layoutType = WorkspaceLayoutType.document,
  });

  final String id;
  final String name;
  final String description;
  final String group;
  final String categoryId;
  final IconData icon;
  final Color color;
  final WorkspaceLayoutType layoutType;
}

const _templates = <_StarterTemplate>[
  _StarterTemplate(
    id: 'class-notes',
    name: 'Apuntes de clase',
    description:
        'Organiza tema, conceptos clave, ejemplos y preguntas para repasar.',
    group: 'Estudio',
    categoryId: 'estudio',
    icon: Icons.school_outlined,
    color: Color(0xFF278A75),
  ),
  _StarterTemplate(
    id: 'research',
    name: 'Investigación',
    description:
        'Define la pregunta, reúne fuentes, registra hallazgos y conclusiones.',
    group: 'Estudio',
    categoryId: 'estudio',
    icon: Icons.science_outlined,
    color: Color(0xFF4F7FD7),
  ),
  _StarterTemplate(
    id: 'meeting',
    name: 'Reunión de equipo',
    description:
        'Conserva contexto, asistentes, decisiones y próximos pasos en un solo lugar.',
    group: 'Trabajo',
    categoryId: 'trabajo',
    icon: Icons.groups_outlined,
    color: Color(0xFF8065B7),
  ),
  _StarterTemplate(
    id: 'weekly-plan',
    name: 'Plan semanal',
    description:
        'Aclara prioridades, compromisos y notas importantes para la semana.',
    group: 'Trabajo',
    categoryId: 'proyectos',
    icon: Icons.calendar_view_week_outlined,
    color: Color(0xFFC85D6A),
  ),
  _StarterTemplate(
    id: 'rfc',
    name: 'RFC técnico',
    description:
        'Documenta contexto, propuesta, alternativas, riesgos y plan de adopción.',
    group: 'Programación',
    categoryId: 'proyectos',
    icon: Icons.code_rounded,
    color: Color(0xFF4F7FD7),
  ),
  _StarterTemplate(
    id: 'bug-report',
    name: 'Reporte de bug',
    description:
        'Registra comportamiento, pasos, resultado esperado y evidencia.',
    group: 'Programación',
    categoryId: 'trabajo',
    icon: Icons.bug_report_outlined,
    color: Color(0xFFC85D6A),
  ),
  _StarterTemplate(
    id: 'journal',
    name: 'Diario personal',
    description:
        'Un espacio tranquilo para registrar el día, aprendizajes y gratitud.',
    group: 'Personal',
    categoryId: 'personal',
    icon: Icons.auto_stories_outlined,
    color: Color(0xFFD4892F),
  ),
  _StarterTemplate(
    id: 'brainstorm',
    name: 'Lluvia de ideas',
    description:
        'Empieza con un reto, genera posibilidades y elige las ideas a explorar.',
    group: 'Creatividad',
    categoryId: 'ideas',
    icon: Icons.lightbulb_outline_rounded,
    color: Color(0xFFD4892F),
  ),
  _StarterTemplate(
    id: 'canvas-project-map',
    name: 'Mapa visual de proyecto',
    description:
        'Objetivo central, etapas, riesgos y próximos pasos distribuidos en el lienzo.',
    group: 'Proyectos',
    categoryId: 'proyectos',
    icon: Icons.account_tree_outlined,
    color: Color(0xFF4F7FD7),
    layoutType: WorkspaceLayoutType.canvas,
  ),
  _StarterTemplate(
    id: 'canvas-mind-map',
    name: 'Mapa mental',
    description:
        'Una idea central rodeada de ramas temáticas listas para desarrollar.',
    group: 'Creatividad',
    categoryId: 'ideas',
    icon: Icons.hub_outlined,
    color: Color(0xFFD4892F),
    layoutType: WorkspaceLayoutType.canvas,
  ),
  _StarterTemplate(
    id: 'canvas-retrospective',
    name: 'Retrospectiva visual',
    description:
        'Panel espacial para aprendizajes, dificultades, acciones y acuerdos.',
    group: 'Trabajo',
    categoryId: 'trabajo',
    icon: Icons.view_kanban_outlined,
    color: Color(0xFF278A75),
    layoutType: WorkspaceLayoutType.canvas,
  ),
];

List<BaseBlock> _buildTemplateBlocks(String templateId) => switch (templateId) {
  'class-notes' => [
    _richText(0, const [_RichLine('Tema de la clase', size: 30, bold: true)]),
    _callout(
      1,
      'Objetivo de aprendizaje',
      'Escribe qué deberías poder explicar al terminar la sesión.',
      BlockCalloutType.info,
    ),
    _richText(2, const [
      _RichLine('Conceptos clave', size: 21, bold: true),
      _RichLine('Resume aquí las ideas centrales con tus propias palabras.'),
    ]),
    _checklist(3, const [
      'Concepto principal',
      'Concepto relacionado',
      'Ejemplo que debo practicar',
    ]),
    _table(4, const [
      ['Concepto', 'Definición', 'Ejemplo'],
      ['Idea 1', '', ''],
      ['Idea 2', '', ''],
    ]),
    _richText(5, const [
      _RichLine('Preguntas para repasar', size: 21, bold: true),
      _RichLine('¿Qué parte necesito volver a estudiar?'),
    ]),
  ],
  'research' => [
    _richText(0, const [_RichLine('Investigación', size: 30, bold: true)]),
    _callout(
      1,
      'Pregunta central',
      'Formula una pregunta concreta, verificable y delimitada.',
      BlockCalloutType.tip,
    ),
    _richText(2, const [
      _RichLine('Hipótesis', size: 21, bold: true),
      _RichLine('Describe el resultado que esperas encontrar y por qué.'),
    ]),
    _checklist(3, const [
      'Localizar fuentes primarias',
      'Contrastar autores y fechas',
      'Registrar citas y enlaces',
    ]),
    _table(4, const [
      ['Fuente', 'Hallazgo', 'Confiabilidad'],
      ['', '', 'Alta / media / baja'],
      ['', '', 'Alta / media / baja'],
    ]),
    _richText(5, const [
      _RichLine('Conclusiones', size: 21, bold: true),
      _RichLine('Relaciona la evidencia con la pregunta inicial.'),
    ]),
  ],
  'meeting' => [
    _richText(0, const [_RichLine('Reunión de equipo', size: 30, bold: true)]),
    _callout(
      1,
      'Objetivo',
      'Define la decisión o resultado que debe producir esta reunión.',
      BlockCalloutType.info,
    ),
    _table(2, const [
      ['Participante', 'Responsabilidad'],
      ['', ''],
      ['', ''],
    ]),
    _checklist(3, const [
      'Tema de agenda 1',
      'Tema de agenda 2',
      'Tema de agenda 3',
    ]),
    _callout(
      4,
      'Decisiones',
      'Registra acuerdos concretos y evita que se pierdan en las notas.',
      BlockCalloutType.success,
    ),
    _table(5, const [
      ['Próximo paso', 'Responsable', 'Fecha'],
      ['', '', ''],
      ['', '', ''],
    ]),
  ],
  'weekly-plan' => [
    _richText(0, const [_RichLine('Plan semanal', size: 30, bold: true)]),
    _callout(
      1,
      'Resultado principal',
      'Si solo completas una cosa esta semana, ¿cuál debería ser?',
      BlockCalloutType.tip,
    ),
    _checklist(2, const ['Prioridad 1', 'Prioridad 2', 'Prioridad 3']),
    _table(3, const [
      ['Día', 'Enfoque', 'Estado'],
      ['Lunes', '', 'Pendiente'],
      ['Martes', '', 'Pendiente'],
      ['Miércoles', '', 'Pendiente'],
      ['Jueves', '', 'Pendiente'],
      ['Viernes', '', 'Pendiente'],
    ]),
    _richText(4, const [
      _RichLine('Notas y aprendizajes', size: 21, bold: true),
      _RichLine('Registra bloqueos, cambios de prioridad y aprendizajes.'),
    ]),
  ],
  'rfc' => [
    _richText(0, const [_RichLine('RFC técnico', size: 30, bold: true)]),
    _callout(
      1,
      'Estado de la propuesta',
      'Borrador · Abierto a comentarios',
      BlockCalloutType.note,
    ),
    _richText(2, const [
      _RichLine('Contexto y problema', size: 21, bold: true),
      _RichLine(
        'Explica el problema observable, sus límites y a quién afecta.',
      ),
      _RichLine('Propuesta', size: 21, bold: true),
      _RichLine('Describe la solución y las decisiones arquitectónicas clave.'),
    ]),
    _table(3, const [
      ['Alternativa', 'Ventaja', 'Costo'],
      ['Opción A', '', ''],
      ['Opción B', '', ''],
    ]),
    CodeBlock(
      id: generateUuid(),
      orderKey: 4,
      languageId: 'dart',
      showLineNumbers: true,
      code: '// Incluye aquí una interfaz, esquema o ejemplo relevante.\n',
      caption: 'Ejemplo técnico',
    ),
    _checklist(5, const [
      'Validar riesgos',
      'Planificar adopción',
      'Definir reversión',
    ]),
  ],
  'bug-report' => [
    _richText(0, const [_RichLine('Reporte de bug', size: 30, bold: true)]),
    _callout(
      1,
      'Resumen',
      'Describe el problema observable en una sola frase.',
      BlockCalloutType.warning,
    ),
    _table(2, const [
      ['Entorno', 'Valor'],
      ['Dispositivo / SO', ''],
      ['Versión', ''],
      ['Frecuencia', 'Siempre / intermitente'],
    ]),
    _checklist(3, const ['Paso 1', 'Paso 2', 'Paso 3']),
    _richText(4, const [
      _RichLine('Resultado actual', size: 21, bold: true),
      _RichLine('¿Qué sucede?'),
      _RichLine('Resultado esperado', size: 21, bold: true),
      _RichLine('¿Qué debería suceder?'),
    ]),
    CodeBlock(
      id: generateUuid(),
      orderKey: 5,
      code: 'Pega aquí los registros relevantes',
      caption: 'Logs o traza',
      showLineNumbers: true,
    ),
  ],
  'journal' => [
    _richText(0, const [_RichLine('Diario personal', size: 30, bold: true)]),
    _callout(
      1,
      'Pausa consciente',
      'No necesitas escribir perfecto; solo registrar lo que importa hoy.',
      BlockCalloutType.tip,
    ),
    _richText(2, const [
      _RichLine('¿Cómo me siento hoy?', size: 21, bold: true),
      _RichLine('Describe tu energía, emociones y contexto.'),
      _RichLine('Lo más importante del día', size: 21, bold: true),
      _RichLine('Una experiencia, conversación o idea que quieras conservar.'),
    ]),
    DividerBlock(id: generateUuid(), orderKey: 3),
    _checklist(4, const [
      'Algo que agradezco',
      'Algo que aprendí',
      'Algo que soltaré',
    ]),
    _richText(5, const [
      _RichLine('Intención para mañana', size: 21, bold: true),
      _RichLine('Escribe un siguiente paso pequeño y realista.'),
    ]),
  ],
  'brainstorm' => [
    _richText(0, const [_RichLine('Lluvia de ideas', size: 30, bold: true)]),
    _callout(
      1,
      'Reto o pregunta',
      'Escribe una pregunta abierta que invite a generar posibilidades.',
      BlockCalloutType.info,
    ),
    _checklist(2, const [
      'Idea espontánea 1',
      'Idea espontánea 2',
      'Idea espontánea 3',
    ]),
    _richText(3, const [
      _RichLine('Conexiones', size: 21, bold: true),
      _RichLine('Agrupa patrones, combinaciones o ideas complementarias.'),
    ]),
    _table(4, const [
      ['Idea', 'Impacto', 'Esfuerzo'],
      ['', 'Alto / medio / bajo', 'Alto / medio / bajo'],
      ['', 'Alto / medio / bajo', 'Alto / medio / bajo'],
    ]),
    _callout(
      5,
      'Siguiente experimento',
      'Elige una idea y define la forma más pequeña de probarla.',
      BlockCalloutType.success,
    ),
  ],
  'canvas-project-map' => [
    _canvasText(0, 480, 80, 640, const [
      _RichLine('Mapa visual del proyecto', size: 30, bold: true),
      _RichLine('Una vista completa para alinear al equipo.'),
    ]),
    _canvasCallout(
      1,
      560,
      280,
      480,
      'Objetivo central',
      '¿Qué resultado concreto debe producir este proyecto?',
      BlockCalloutType.info,
    ),
    _canvasText(2, 80, 560, 360, const [
      _RichLine('1 · Descubrimiento', size: 21, bold: true),
      _RichLine('Problema, usuarios, evidencia y restricciones.'),
    ]),
    _canvasChecklist(3, 80, 760, 360, const [
      'Validar el problema',
      'Reunir evidencia',
      'Definir alcance',
    ]),
    _canvasText(4, 600, 560, 360, const [
      _RichLine('2 · Construcción', size: 21, bold: true),
      _RichLine('Entregables, responsables y decisiones clave.'),
    ]),
    _canvasChecklist(5, 600, 760, 360, const [
      'Preparar la primera versión',
      'Revisar con interesados',
      'Medir resultados',
    ]),
    _canvasText(6, 1120, 560, 360, const [
      _RichLine('3 · Lanzamiento', size: 21, bold: true),
      _RichLine('Adopción, comunicación y seguimiento.'),
    ]),
    _canvasCallout(
      7,
      1120,
      760,
      360,
      'Riesgos y señales',
      'Anota qué puede fallar y cómo sabrás que debes reaccionar.',
      BlockCalloutType.warning,
    ),
  ],
  'canvas-mind-map' => [
    _canvasCallout(
      0,
      590,
      390,
      440,
      'Idea central',
      'Escribe aquí la pregunta o concepto que quieres explorar.',
      BlockCalloutType.tip,
    ),
    _canvasText(1, 120, 100, 360, const [
      _RichLine('Contexto', size: 22, bold: true),
      _RichLine('¿De dónde surge esta idea?'),
    ]),
    _canvasText(2, 1120, 100, 360, const [
      _RichLine('Personas', size: 22, bold: true),
      _RichLine('¿A quién afecta o beneficia?'),
    ]),
    _canvasChecklist(3, 80, 680, 400, const [
      'Posibilidad 1',
      'Posibilidad 2',
      'Posibilidad 3',
    ]),
    _canvasText(4, 1120, 680, 360, const [
      _RichLine('Preguntas abiertas', size: 22, bold: true),
      _RichLine('¿Qué falta entender o comprobar?'),
    ]),
    _canvasCallout(
      5,
      600,
      900,
      420,
      'Siguiente conexión',
      'Combina dos ramas y define una idea nueva para explorar.',
      BlockCalloutType.success,
    ),
  ],
  'canvas-retrospective' => [
    _canvasText(0, 420, 70, 760, const [
      _RichLine('Retrospectiva visual', size: 30, bold: true),
      _RichLine('Observa el periodo, encuentra patrones y acuerda acciones.'),
    ]),
    _canvasCallout(
      1,
      80,
      320,
      400,
      'Funcionó bien',
      'Registra prácticas y decisiones que vale la pena repetir.',
      BlockCalloutType.success,
    ),
    _canvasChecklist(2, 80, 560, 400, const [
      'Fortaleza 1',
      'Fortaleza 2',
      'Momento destacado',
    ]),
    _canvasCallout(
      3,
      600,
      320,
      400,
      'Fue difícil',
      'Describe bloqueos y causas sin buscar culpables.',
      BlockCalloutType.warning,
    ),
    _canvasChecklist(4, 600, 560, 400, const [
      'Bloqueo 1',
      'Señal ignorada',
      'Aprendizaje',
    ]),
    _canvasCallout(
      5,
      1120,
      320,
      400,
      'Probemos ahora',
      'Convierte los aprendizajes en experimentos pequeños.',
      BlockCalloutType.info,
    ),
    _canvasChecklist(6, 1120, 560, 400, const [
      'Acción y responsable',
      'Fecha de revisión',
      'Señal de éxito',
    ]),
  ],
  _ => [
    _richText(0, const [_RichLine('Nuevo documento', size: 30, bold: true)]),
  ],
};

TextBlock _richText(double order, List<_RichLine> lines) => TextBlock(
  id: generateUuid(),
  orderKey: order,
  paragraphs: [
    for (final line in lines)
      BlockParagraph(
        id: generateUuid(),
        text: line.text,
        spans: line.text.isEmpty || (!line.bold && line.size == null)
            ? const []
            : [
                TextSpanMark(
                  start: 0,
                  end: line.text.length,
                  attributes: {
                    if (line.bold) 'bold': true,
                    if (line.size != null) 'fontSize': line.size,
                  },
                ),
              ],
      ),
  ],
);

ChecklistBlock _checklist(double order, List<String> items) => ChecklistBlock(
  id: generateUuid(),
  orderKey: order,
  items: [
    for (final item in items)
      BlockChecklistItem(id: generateUuid(), text: item),
  ],
);

TextBlock _canvasText(
  double order,
  double x,
  double y,
  double width,
  List<_RichLine> lines,
) => _richText(order, lines).copyWith(
  geometry: BlockGeometry(x: x, y: y, width: width),
);

ChecklistBlock _canvasChecklist(
  double order,
  double x,
  double y,
  double width,
  List<String> items,
) => _checklist(order, items).copyWith(
  geometry: BlockGeometry(x: x, y: y, width: width),
);

CalloutBlock _canvasCallout(
  double order,
  double x,
  double y,
  double width,
  String title,
  String text,
  BlockCalloutType type,
) => _callout(order, title, text, type).copyWith(
  geometry: BlockGeometry(x: x, y: y, width: width),
);

CalloutBlock _callout(
  double order,
  String title,
  String text,
  BlockCalloutType type,
) => CalloutBlock(
  id: generateUuid(),
  orderKey: order,
  title: title,
  text: text,
  calloutType: type,
);

TableBlock _table(double order, List<List<String>> values) {
  final columnCount = values.fold<int>(
    0,
    (count, row) => row.length > count ? row.length : count,
  );
  return TableBlock(
    id: generateUuid(),
    orderKey: order,
    columnIds: List.generate(columnCount, (_) => generateUuid()),
    hasHeaderRow: true,
    rows: [
      for (var rowIndex = 0; rowIndex < values.length; rowIndex++)
        BlockTableRow(
          id: generateUuid(),
          cells: [
            for (var columnIndex = 0; columnIndex < columnCount; columnIndex++)
              BlockTableCell(
                id: generateUuid(),
                text: columnIndex < values[rowIndex].length
                    ? values[rowIndex][columnIndex]
                    : '',
                spans:
                    rowIndex == 0 &&
                        columnIndex < values[rowIndex].length &&
                        values[rowIndex][columnIndex].isNotEmpty
                    ? [
                        TextSpanMark(
                          start: 0,
                          end: values[rowIndex][columnIndex].length,
                          attributes: const {'bold': true},
                        ),
                      ]
                    : const [],
              ),
          ],
        ),
    ],
  );
}

class _RichLine {
  const _RichLine(this.text, {this.size, this.bold = false});

  final String text;
  final double? size;
  final bool bold;
}

const _templateGroups = [
  'Estudio',
  'Trabajo',
  'Proyectos',
  'Programación',
  'Personal',
  'Creatividad',
];
