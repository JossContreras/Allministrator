import 'dart:async';

import 'package:allministrator/app/theme/app_spacing.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/domain/use_cases/document_use_cases.dart';
import 'package:allministrator/features/documents/presentation/category_catalog.dart';
import 'package:allministrator/features/documents/presentation/document_category_picker.dart';
import 'package:allministrator/features/content_io/data/image_text_extractor.dart';
import 'package:allministrator/features/content_io/data/document_export_service.dart';
import 'package:allministrator/features/content_io/presentation/document_export_sheet.dart';
import 'package:allministrator/features/content_io/presentation/pdf_attachment_preview.dart';
import 'package:allministrator/features/editor/data/local_attachment_storage.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_list_view.dart';
import 'package:allministrator/features/editor/presentation/blocks/canvas_block_view.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_registry.dart';
import 'package:allministrator/features/editor/presentation/smart_formatting_toolbar.dart';
import 'package:allministrator/features/editor/presentation/interaction/workspace_surface.dart';
import 'package:allministrator/features/editor/presentation/interaction/workspace_block_actions.dart';
import 'package:allministrator/features/editor/presentation/ink/ink_canvas_layer.dart';
import 'package:allministrator/features/editor/presentation/ink/ink_toolbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

enum EditorSaveStatus { editing, saving, saved, error }

class DocumentEditorScreen extends StatefulWidget {
  const DocumentEditorScreen({
    required this.repository,
    required this.documentId,
    super.key,
  });

  final DocumentRepository repository;
  final String documentId;

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen>
    with WidgetsBindingObserver {
  final TextEditingController _titleController = TextEditingController();
  final LocalAttachmentStorage _attachmentStorage = LocalAttachmentStorage();
  final ImagePicker _imagePicker = ImagePicker();
  final ImageTextExtractor _imageTextExtractor = ImageTextExtractor();
  final BlockRegistry _registry = BlockRegistry.standard();
  final WorkspaceInteractionController _interaction =
      WorkspaceInteractionController();
  final BlockGeometryRegistry _geometryRegistry = BlockGeometryRegistry();
  final ScrollController _scrollController = ScrollController();
  final WorkspaceViewportController _viewportController =
      WorkspaceViewportController();
  InputDispatcher? _inputDispatcher;
  InteractionOverlayController? _overlayController;
  final InteractionDebugTimeline _interactionTimeline =
      InteractionDebugTimeline(limit: 100);
  final ValueNotifier<EditorSaveStatus> _saveStatus = ValueNotifier(
    EditorSaveStatus.saved,
  );
  final Map<String, String> _attachmentPaths = {};
  final GlobalKey _inkToolbarKey = GlobalKey();

  Timer? _saveTimer;
  Future<void> _saveQueue = Future<void>.value();
  Document? _document;
  String? _categoryId;
  WorkspaceEditorSession? _session;
  bool _loading = true;
  bool _changed = false;
  bool _marqueeEnabled = false;
  bool _inkToolbarVisible = false;
  InkBrushStyle _penBrush = InkBrushStyle.pen();
  InkBrushStyle _highlighterBrush = InkBrushStyle.highlighter();
  InkBrushStyle _shapeBrush = InkBrushStyle.shape();
  bool _exiting = false;
  int _changeRevision = 0;
  SpatialPoint? _requestedCanvasInsertPosition;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleController.addListener(_scheduleSave);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _saveTimer?.cancel();
      unawaited(_save());
    }
  }

  Future<void> _load() async {
    try {
      final document = await GetDocumentById(widget.repository)(
        widget.documentId,
      );
      if (!mounted) return;
      if (document == null || document.deletedAt != null) {
        setState(() {
          _loading = false;
          _error = 'El documento no existe o fue eliminado.';
        });
        return;
      }

      final workspace = _workspaceForDocument(document);
      _document = document;
      _categoryId = document.categoryId;
      _titleController.text = document.title;
      await _resolveAttachmentPaths(workspace);
      _session = WorkspaceEditorSession(
        workspace: workspace,
        onChanged: _workspaceChanged,
      );
      _viewportController.attach(
        workspaceId: workspace.id,
        pageId: _session!.page.id,
      );
      _session!.addListener(_invalidateUnmountedSelection);
      _inputDispatcher = InputDispatcher(
        workspaceId: workspace.id,
        pageId: _session!.page.id,
        registry: _geometryRegistry,
        controller: _interaction,
        resolver: InteractionResolver(
          blockInfo: (blockId) {
            final block = _session?.blockById(blockId);
            return block == null
                ? null
                : BlockInteractionInfo(
                    capabilities: block.capabilities,
                    isLocked: block.isLocked,
                  );
          },
          visualOrder: () =>
              _session?.blocks.map((block) => block.id).toList() ?? const [],
          blockBounds: _blockTransformBounds,
          canStartMarquee: () => _marqueeEnabled,
          inkBrush: _inkBrushFor,
          inkAnchor: _inkAnchorFor,
        ),
        isModalActive: () =>
            _interaction.context.interactionMode == InteractionMode.contextMenu,
        onResult: kDebugMode ? _recordInteractionDebug : null,
        onCommand: _handleInteractionCommand,
        dropResolver: DropResolver(
          registry: _geometryRegistry,
          blockInfo: (blockId) {
            final block = _session?.blockById(blockId);
            return block == null
                ? null
                : BlockInteractionInfo(
                    capabilities: block.capabilities,
                    isLocked: block.isLocked,
                  );
          },
        ),
        isCanvasMode: () =>
            _session?.page.layoutType == WorkspaceLayoutType.canvas,
        camera: () => _viewportController.camera,
        inkHitTest: _hitTestInk,
        inkLasso: _lassoInk,
        inputBlocker: _isWorkspaceInputBlocked,
      );
      _overlayController = InteractionOverlayController(
        interaction: _interaction,
        registry: _geometryRegistry,
      );
      _changed = document.content.wasMigrated;
      _changeRevision = _changed ? 1 : 0;
      setState(() => _loading = false);

      if (document.content.migrationError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El documento anterior no pudo migrarse por completo. '
              'Se conservó una copia de sus datos originales.',
            ),
          ),
        );
      }
      if (_changed) _scheduleSave();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo cargar el documento.';
        });
      }
    }
  }

  Workspace _workspaceForDocument(Document document) {
    var workspace = document.content.workspace;
    if (workspace.pages.isEmpty) {
      workspace = DocumentContent.forNewWorkspace(
        workspaceId: document.id,
        title: document.title,
        now: document.createdAt,
      ).workspace;
    }
    final pages = [
      for (final page in workspace.pages)
        page.copyWith(workspaceId: document.id),
    ];
    return Workspace(
      id: document.id,
      title: document.title,
      description: workspace.description,
      workspaceType: document.isCanvas
          ? WorkspaceType.canvas
          : WorkspaceType.document,
      pages: pages,
      themeId: workspace.themeId,
      templateId: workspace.templateId,
      isFavorite: document.isFavorite,
      isArchived: workspace.isArchived,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
      deletedAt: document.deletedAt,
      version: document.version,
      metadata: workspace.metadata,
    );
  }

  Future<void> _resolveAttachmentPaths(Workspace workspace) async {
    for (final block in workspace.pages.expand((page) => page.blocks)) {
      final attachmentId = switch (block) {
        ImageBlock() => block.attachmentId,
        AttachmentBlock() => block.attachmentId,
        _ => null,
      };
      if (attachmentId == null || attachmentId.isEmpty) continue;
      final path = await _attachmentStorage.resolvePath(attachmentId);
      if (path != null) _attachmentPaths[attachmentId] = path;
    }
  }

  void _workspaceChanged(Workspace workspace) => _scheduleSave();

  void _invalidateUnmountedSelection() {
    if (_interaction.context.currentSelection case InkSelection(
      :final elementIds,
    )) {
      final layer = _session?.page.inkLayer;
      if (layer == null ||
          elementIds.any((id) => layer.elementById(id) == null)) {
        _interaction.dispatch(const ClearSelectionIntent());
      }
      return;
    }
    final selected = switch (_interaction.context.currentSelection) {
      MultiBlockSelection(:final group) => group.blockIds,
      BlockSelection(:final blockId) => [blockId],
      _ => const <String>[],
    };
    for (final id in selected) {
      if (_session?.blockById(id) == null) {
        _interaction.dispatch(RemoveBlockFromSelectionIntent(id));
      }
    }
  }

  void _recordInteractionDebug(InputDispatchResult result) {
    _interactionTimeline.add(result);
    // Only technical event metadata is logged: no document or user text.
    debugPrint(
      '[interaction:${result.correlationId}] ${result.event.type.name} '
      'target=${result.event.hitTarget?.kind.name} '
      'result=${result.resolution.kind.name}',
    );
  }

  SpatialRect? _blockTransformBounds(String blockId) {
    final entry = _geometryRegistry.geometryFor(blockId);
    return entry == null
        ? null
        : WorkspaceOverlayGeometry.transformBounds(entry);
  }

  InkBrushStyle _inkBrushFor(WorkspaceTool tool) => switch (tool) {
    WorkspaceTool.highlighter => _highlighterBrush,
    WorkspaceTool.line ||
    WorkspaceTool.arrow ||
    WorkspaceTool.rectangle ||
    WorkspaceTool.ellipse => _shapeBrush,
    _ => _penBrush,
  };

  AnnotationAnchor? _inkAnchorFor(NormalizedInputEvent event) {
    final blockId = event.targetBlockId ?? event.hitTarget?.blockId;
    final block = _session?.blockById(blockId);
    final entry = blockId == null
        ? null
        : _geometryRegistry.geometryFor(blockId);
    if (block is! ImageBlock || entry == null) return null;
    final bounds = GeometryResolver(_geometryRegistry).resolveRect(
      entry.globalBounds,
      from: GeometryCoordinateSpace.screen,
      to: GeometryCoordinateSpace.workspace,
    );
    return AnnotationAnchor(
      kind: AnnotationAnchorKind.imageRelative,
      targetId: blockId,
      referenceBounds: bounds,
    );
  }

  SpatialPoint _resolveAnchoredInkPoint(
    InkElement element,
    SpatialPoint stored,
  ) {
    final anchor = element.anchor;
    if (anchor?.targetId == null) return stored;
    final entry = _geometryRegistry.geometryFor(anchor!.targetId!);
    if (entry == null) return stored;
    final currentBounds = GeometryResolver(_geometryRegistry).resolveRect(
      entry.globalBounds,
      from: GeometryCoordinateSpace.screen,
      to: GeometryCoordinateSpace.workspace,
    );
    return anchor.resolve(stored, currentBounds);
  }

  List<String> _hitTestInk(SpatialPoint position, double radius) =>
      InkSpatialIndex(_session?.page.inkLayer.elements ?? const []).hitTest(
        position,
        tolerance: radius,
        resolvePoint: _resolveAnchoredInkPoint,
      );

  List<String> _lassoInk(List<SpatialPoint> polygon) => InkSpatialIndex(
    _session?.page.inkLayer.elements ?? const [],
  ).insideLasso(polygon, resolvePoint: _resolveAnchoredInkPoint);

  bool _isWorkspaceInputBlocked(SpatialPoint globalPosition) {
    if (!_inkToolbarVisible) return false;
    final renderObject = _inkToolbarKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final origin = renderObject.localToGlobal(Offset.zero);
    return (origin & renderObject.size).contains(
      Offset(globalPosition.x, globalPosition.y),
    );
  }

  List<String> get _selectedInkIds =>
      _interaction.context.currentSelection is InkSelection
      ? (_interaction.context.currentSelection as InkSelection).elementIds
      : const [];

  InkBrushStyle get _toolbarInkStyle {
    final primary = _interaction.context.currentSelection is InkSelection
        ? (_interaction.context.currentSelection as InkSelection)
              .primaryElementId
        : null;
    return _session?.page.inkLayer.elementById(primary ?? '')?.brush ??
        _inkBrushFor(_interaction.context.activeTool);
  }

  void _activateInkTool(WorkspaceTool tool) {
    if (!tool.startsInkSession) return;
    _interaction.activateTool(tool);
    setState(() => _inkToolbarVisible = true);
  }

  void _closeInkToolbar() {
    _interaction.dispatch(const CancelInkIntent());
    _interaction.activateTool(WorkspaceTool.selection);
    setState(() => _inkToolbarVisible = false);
  }

  void _setInkStyle(InkBrushStyle style) {
    final tool = _interaction.context.activeTool;
    setState(() {
      if (tool == WorkspaceTool.highlighter) {
        _highlighterBrush = style.copyWith(kind: InkBrushKind.highlighter);
      } else if (tool.isInkShape) {
        _shapeBrush = style.copyWith(
          kind: InkBrushKind.shape,
          pressureEnabled: false,
        );
      } else {
        _penBrush = style.copyWith(kind: InkBrushKind.pen);
      }
    });
    if (_selectedInkIds.isNotEmpty) {
      _session?.updateInkStyle(_selectedInkIds, style);
    }
  }

  void _handleInteractionCommand(
    InteractionIntent intent,
    NormalizedInputEvent event,
  ) {
    if (intent case CommitDragIntent(:final dropTarget)) {
      _session?.moveBlocksTo(
        dropTarget.sourceBlockIds.isEmpty
            ? [dropTarget.sourceBlockId]
            : dropTarget.sourceBlockIds,
        targetBlockId: dropTarget.targetBlockId,
        insertAfter: dropTarget.insertAfter,
      );
    }
    if (intent case CommitCanvasDragIntent(:final blockIds, :final delta)) {
      _session?.moveCanvasBlocks(blockIds, delta);
    }
    if (intent is DeleteSelectionIntent) {
      final inkIds = _selectedInkIds;
      if (inkIds.isNotEmpty) {
        _session?.deleteInkElements(inkIds);
        _interaction.dispatch(const ClearSelectionIntent());
        return;
      }
      final ids = switch (_interaction.context.currentSelection) {
        MultiBlockSelection(:final group) => group.blockIds,
        BlockSelection(:final blockId) => [blockId],
        _ => const <String>[],
      };
      if (ids.isNotEmpty) {
        _session?.deleteBlocks(ids);
        _interaction.dispatch(const ClearSelectionIntent());
      }
    }
    if (intent case CommitResizeIntent(:final blockId, :final bounds)) {
      _session?.resizeBlock(blockId, bounds);
    }
    if (intent case AlignSelectionIntent(:final alignment)) {
      _alignSelection(alignment);
    }
    if (intent is DistributeSelectionIntent) {
      _distributeSelection();
    }
    if (intent case CommitInkIntent(:final session)) {
      _commitInkGesture(session);
    }
  }

  void _commitInkGesture(InkSession inkSession) {
    final session = _session;
    if (session == null) return;
    if (inkSession.tool == WorkspaceTool.eraser) {
      session.deleteInkElements(inkSession.affectedElementIds);
      return;
    }
    if (inkSession.tool == WorkspaceTool.inkLasso) return;
    final processor = const InkProcessor();
    if (inkSession.tool.isInkShape) {
      final shape = processor.createShape(
        surfaceId: session.page.id,
        kind: inkSession.shapeKind ?? InkShapeKind.line,
        start: inkSession.firstPoint.workspacePosition,
        end: inkSession.currentPoint.workspacePosition,
        brush: inkSession.brush,
        anchor: inkSession.anchor,
        zOrder: session.page.inkLayer.topZOrder + 1,
      );
      if (shape != null) session.addInkElement(shape);
      return;
    }
    final stroke = processor.createStroke(
      surfaceId: session.page.id,
      points: inkSession.points,
      brush: inkSession.brush,
      anchor: inkSession.anchor,
      zOrder: session.page.inkLayer.topZOrder + 1,
      zoom: _viewportController.camera.zoom,
    );
    if (stroke != null) session.addInkElement(stroke);
  }

  List<String> get _selectedBlockIds =>
      switch (_interaction.context.currentSelection) {
        MultiBlockSelection(:final group) => group.blockIds,
        BlockSelection(:final blockId) => [blockId],
        _ => const <String>[],
      };

  Map<String, SpatialRect> _selectedWorkspaceBounds() {
    final resolver = GeometryResolver(_geometryRegistry);
    return {
      for (final id in _selectedBlockIds)
        if (_geometryRegistry.geometryFor(id) case final entry?)
          id: resolver.resolveRect(
            entry.globalBounds,
            from: GeometryCoordinateSpace.screen,
            to: GeometryCoordinateSpace.workspace,
          ),
    };
  }

  void _alignSelection(BlockAlignmentAxis alignment) {
    _session?.alignBlocks(
      _selectedBlockIds,
      _selectedWorkspaceBounds(),
      alignment,
    );
  }

  void _distributeSelection() {
    _session?.distributeBlocksVertically(
      _selectedBlockIds,
      _selectedWorkspaceBounds(),
    );
  }

  void _scheduleSave() {
    if (_loading || _document == null || _session == null) return;
    _changed = true;
    _changeRevision++;
    _saveStatus.value = EditorSaveStatus.editing;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _save);
  }

  Future<void> _save() {
    final operation = _saveQueue.then((_) => _performSave());
    _saveQueue = operation.catchError((_) {});
    return operation;
  }

  Future<void> _performSave() async {
    final document = _document;
    final session = _session;
    if (document == null || session == null || !_changed) return;
    final revision = _changeRevision;
    final title = _titleController.text;
    final workspace = session.workspace.copyWith(
      title: title,
      updatedAt: DateTime.now().toUtc(),
    );
    _saveStatus.value = EditorSaveStatus.saving;
    try {
      final saved = await UpdateDocument(widget.repository)(
        document.copyWith(
          title: title,
          content: document.content.withWorkspace(workspace),
          categoryId: _categoryId,
        ),
      );
      if (!mounted) return;
      _document = saved;
      if (_changeRevision == revision) {
        _changed = false;
        _saveStatus.value = EditorSaveStatus.saved;
      } else {
        _saveStatus.value = EditorSaveStatus.editing;
      }
    } catch (_) {
      if (mounted) _saveStatus.value = EditorSaveStatus.error;
    }
  }

  Future<void> _beforeExit() async {
    _saveTimer?.cancel();
    await _save();
    await _saveQueue;
  }

  Future<void> _exitEditor({
    InteractionCancellationReason reason =
        InteractionCancellationReason.pageChanged,
  }) async {
    if (_exiting) return;
    _exiting = true;
    _interaction.dispatch(CancelInteractionIntent(reason: reason));
    await _beforeExit();
    if (mounted) {
      final isCanvas =
          _session?.page.layoutType == WorkspaceLayoutType.canvas ||
          _document?.isCanvas == true;
      context.go(isCanvas ? '/canvas' : '/documents');
    }
  }

  void _handleSystemBack() {
    if (_inkToolbarVisible) {
      _closeInkToolbar();
      return;
    }
    if (_interaction.context.interactionMode != InteractionMode.idle) {
      _interaction.dispatch(
        const CancelInteractionIntent(
          reason: InteractionCancellationReason.systemBack,
        ),
      );
      return;
    }
    _exitEditor(reason: InteractionCancellationReason.systemBack);
  }

  @override
  Widget build(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 700;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: _session?.page.layoutType == WorkspaceLayoutType.canvas
                ? 'Volver a Canvas'
                : 'Volver a documentos',
            icon: const Icon(Icons.arrow_back),
            onPressed: _exitEditor,
          ),
          title: compactHeader
              ? null
              : ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _titleController,
                  builder: (context, value, _) => Text(
                    value.text.trim().isEmpty
                        ? (_session?.page.layoutType ==
                                  WorkspaceLayoutType.canvas
                              ? 'Canvas sin título'
                              : 'Documento sin título')
                        : value.text,
                  ),
                ),
          actions: _editorActions(compactHeader),
        ),
        body: Hero(
          tag: 'document-${widget.documentId}',
          child: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: _buildBody(context),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: _floatingEditorTools(),
      ),
    );
  }

  Widget? _floatingEditorTools() {
    final session = _session;
    if (session == null || _inkToolbarVisible) return null;
    return AnimatedBuilder(
      animation: _interaction,
      builder: (context, child) => _hasTextFormattingContext(session)
          ? const SizedBox.shrink(key: ValueKey('editor-floating-tools-hidden'))
          : child!,
      child: Column(
        key: const ValueKey('editor-floating-tools'),
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'insert-block',
            tooltip: 'Insertar bloque',
            onPressed: _showInsertSheet,
            child: const Icon(Icons.add_box_outlined),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'ink-tools',
            tooltip: 'Anotar o dibujar',
            onPressed: () => _activateInkTool(WorkspaceTool.pen),
            child: const Icon(Icons.draw_outlined),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'marquee-selection',
            tooltip: _marqueeEnabled
                ? 'Desactivar selección por área'
                : 'Activar selección por área',
            onPressed: () {
              _interaction.dispatch(
                const CancelInteractionIntent(keepBlockSelected: true),
              );
              _interaction.activateTool(WorkspaceTool.selection);
              setState(() {
                _inkToolbarVisible = false;
                _marqueeEnabled = !_marqueeEnabled;
              });
            },
            backgroundColor: _marqueeEnabled
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: Icon(
              _marqueeEnabled ? Icons.select_all : Icons.touch_app_outlined,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _editorActions(bool compact) {
    final session = _session;
    final save = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Center(child: _saveIndicator()),
    );
    if (compact) {
      return [
        if (session != null) _historyActions(session),
        if (session != null) _resetViewAction(),
        _categoryMenu(),
        save,
      ];
    }
    return [
      if (session != null)
        IconButton(
          tooltip: 'Anotar o dibujar',
          onPressed: _inkToolbarVisible
              ? _closeInkToolbar
              : () => _activateInkTool(WorkspaceTool.pen),
          icon: Icon(
            Icons.draw_outlined,
            color: _inkToolbarVisible
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      if (session?.page.layoutType == WorkspaceLayoutType.canvas)
        _canvasMenu(session!),
      if (session != null) _insertMenu(),
      if (session != null) _historyActions(session),
      _resetViewAction(showZoom: true),
      _categoryMenu(),
      save,
    ];
  }

  Widget _resetViewAction({bool showZoom = false}) => AnimatedBuilder(
    animation: _viewportController,
    builder: (context, _) => IconButton(
      tooltip:
          'Restablecer vista · ${(_viewportController.camera.zoom * 100).round()}%',
      onPressed: _viewportController.reset,
      icon: showZoom
          ? Badge(
              label: Text('${(_viewportController.camera.zoom * 100).round()}'),
              child: const Icon(Icons.center_focus_strong),
            )
          : const Icon(Icons.center_focus_strong),
    ),
  );

  // ignore: unused_element
  Widget _compactEditorMenu(WorkspaceEditorSession session) =>
      PopupMenuButton<String>(
        tooltip: 'Más opciones del editor',
        icon: const Icon(Icons.more_vert),
        onSelected: (action) {
          if (action == 'ink') {
            _inkToolbarVisible
                ? _closeInkToolbar()
                : _activateInkTool(WorkspaceTool.pen);
          } else if (action.startsWith('category:')) {
            _changeCategory(action.substring('category:'.length));
          } else if (action.startsWith('insert:')) {
            _insertBlock(
              BlockType.values.byName(action.substring('insert:'.length)),
            );
          } else if (action.startsWith('canvas:')) {
            _handleCanvasAction(session, action.substring('canvas:'.length));
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'ink',
            child: ListTile(
              leading: const Icon(Icons.draw_outlined),
              title: Text(
                _inkToolbarVisible
                    ? 'Cerrar herramientas de tinta'
                    : 'Anotar o dibujar',
              ),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(enabled: false, child: Text('Insertar bloque')),
          for (final choice in const [
            (BlockType.text, Icons.text_fields, 'Texto'),
            (BlockType.image, Icons.image_outlined, 'Imagen'),
            (BlockType.divider, Icons.horizontal_rule, 'Separador'),
            (BlockType.checklist, Icons.check_box_outlined, 'Checklist'),
            (BlockType.code, Icons.code, 'Código'),
            (BlockType.table, Icons.table_chart_outlined, 'Tabla'),
            (BlockType.attachment, Icons.attach_file, 'Archivo'),
          ])
            PopupMenuItem(
              value: 'insert:${choice.$1.name}',
              child: ListTile(leading: Icon(choice.$2), title: Text(choice.$3)),
            ),
          if (session.page.layoutType == WorkspaceLayoutType.canvas) ...[
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'canvas:select',
              child: ListTile(
                leading: Icon(Icons.ads_click_outlined),
                title: Text('Herramienta Selección'),
              ),
            ),
            const PopupMenuItem(
              value: 'canvas:hand',
              child: ListTile(
                leading: Icon(Icons.pan_tool_outlined),
                title: Text('Herramienta Mano'),
              ),
            ),
            const PopupMenuItem(
              value: 'canvas:fit-content',
              child: ListTile(
                leading: Icon(Icons.fit_screen_outlined),
                title: Text('Encajar contenido'),
              ),
            ),
            CheckedPopupMenuItem(
              value: 'canvas:grid',
              checked: session.page.canvasLayout?.showGrid ?? true,
              child: const Text('Mostrar rejilla'),
            ),
            CheckedPopupMenuItem(
              value: 'canvas:snap',
              checked: session.page.canvasLayout?.snapToGrid ?? true,
              child: const Text('Ajustar a rejilla'),
            ),
          ],
          const PopupMenuDivider(),
          for (final category in CategoryCatalog.values)
            PopupMenuItem(
              value: 'category:${category.id}',
              child: ListTile(
                leading: Icon(Icons.circle, size: 14, color: category.color),
                title: Text(category.name),
                trailing: _categoryId == category.id
                    ? const Icon(Icons.check, size: 18)
                    : null,
              ),
            ),
        ],
      );

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final session = _session!;
    final isCanvas = session.page.layoutType == WorkspaceLayoutType.canvas;
    return WorkspaceSurface(
      workspaceId: session.workspace.id,
      pageId: session.page.id,
      registry: _geometryRegistry,
      interaction: _interaction,
      scrollController: _scrollController,
      keyboardInset: MediaQuery.viewInsetsOf(context).bottom,
      inputDispatcher: _inputDispatcher,
      overlayController: _overlayController,
      viewportController: _viewportController,
      workspaceExtent: isCanvas ? const Size(4800, 3600) : null,
      inkLayer: InkCanvasLayer(
        session: session,
        interaction: _interaction,
        registry: _geometryRegistry,
      ),
      isBlockResizable: (blockId) {
        final block = session.blockById(blockId);
        return block != null &&
            !block.isLocked &&
            block.supports(BlockCapability.resizable);
      },
      lockedBlockIds: {
        for (final block in session.blocks)
          if (block.isLocked) block.id,
      },
      modalBuilder: (context, blockId) =>
          _selectedBlockActions(context, session, blockId),
      content: isCanvas
          ? CanvasBlockView(
              session: session,
              registry: _registry,
              interaction: _interaction,
              geometryRegistry: _geometryRegistry,
              onChanged: _onBlockChanged,
              resolveAttachmentPath: (id) => _attachmentPaths[id],
              onReplaceImage: _replaceImage,
              onReplaceAttachment: _replaceAttachment,
              onOpenAttachment: _openAttachment,
              viewportController: _viewportController,
              inputDispatcher: _inputDispatcher,
              header: _canvasHeader(),
              onInsertRequested: _showCanvasInsertMenu,
            )
          : BlockListView(
              session: session,
              registry: _registry,
              interaction: _interaction,
              geometryRegistry: _geometryRegistry,
              controller: _scrollController,
              onChanged: _onBlockChanged,
              resolveAttachmentPath: (id) => _attachmentPaths[id],
              onReplaceImage: _replaceImage,
              onReplaceAttachment: _replaceAttachment,
              onOpenAttachment: _openAttachment,
              inputDispatcher: _inputDispatcher,
              header: _pageHeader(isCanvas: false),
            ),
      transientOverlay: Positioned(
        left: 12,
        right: 12,
        bottom: 0,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 12),
          child: AnimatedBuilder(
            animation: _interaction,
            builder: (context, _) {
              if (_inkToolbarVisible) {
                final style = _toolbarInkStyle;
                return InkToolbar(
                  key: _inkToolbarKey,
                  activeTool: _interaction.context.activeTool,
                  style: style,
                  hasSelection: _selectedInkIds.isNotEmpty,
                  canUndo: session.canUndo,
                  canRedo: session.canRedo,
                  onTool: _activateInkTool,
                  onColor: (color) =>
                      _setInkStyle(_toolbarInkStyle.copyWith(color: color)),
                  onWidth: (width) =>
                      _setInkStyle(_toolbarInkStyle.copyWith(baseWidth: width)),
                  onOpacity: (opacity) =>
                      _setInkStyle(_toolbarInkStyle.copyWith(opacity: opacity)),
                  onUndo: session.undo,
                  onRedo: session.redo,
                  onDuplicate: () {
                    final clones = session.duplicateInkElements(
                      _selectedInkIds,
                    );
                    if (clones.isNotEmpty) {
                      _interaction.dispatch(SelectInkElementsIntent(clones));
                    }
                  },
                  onDelete: () {
                    session.deleteInkElements(_selectedInkIds);
                    _interaction.dispatch(const ClearSelectionIntent());
                  },
                  onMove: (delta) => session.translateInkElements(
                    _selectedInkIds,
                    SpatialPoint(delta.dx, delta.dy),
                  ),
                  onClose: _closeInkToolbar,
                );
              }
              final toolbar = _toolbarContext(session);
              return ToolbarOverlay(
                visible: toolbar.hasSelection,
                child: SmartFormattingToolbar(
                  key: const ValueKey('text-formatting-toolbar'),
                  contextState: toolbar,
                  onToggle: _applyTextFormat,
                  onColor: (color) => _applyTextFormat('color', color),
                  onSize: (size) => _applyTextFormat('fontSize', size),
                  onAlignment: _applyParagraphAlignment,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _canvasHeader() => _pageHeader(isCanvas: true);

  Widget _pageHeader({required bool isCanvas}) {
    final category = CategoryCatalog.resolve(_categoryId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          style: Theme.of(context).textTheme.headlineSmall,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Documento sin título',
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            ActionChip(
              avatar: Icon(category.icon, size: 16, color: category.color),
              label: Text(category.name),
              visualDensity: VisualDensity.compact,
              tooltip: 'Cambiar categoría',
              onPressed: _pickCategory,
            ),
            Chip(
              avatar: Icon(
                isCanvas
                    ? Icons.dashboard_customize_outlined
                    : Icons.article_outlined,
                size: 16,
              ),
              label: Text(isCanvas ? 'Canvas' : 'Documento'),
              visualDensity: VisualDensity.compact,
            ),
            ActionChip(
              avatar: const Icon(Icons.ios_share_outlined, size: 16),
              label: const Text('Exportar'),
              visualDensity: VisualDensity.compact,
              onPressed: _exportDocument,
            ),
          ],
        ),
        if (isCanvas) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Mantén presionado un espacio vacío para insertar contenido.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        const Divider(),
      ],
    );
  }

  Widget _selectedBlockActions(
    BuildContext context,
    WorkspaceEditorSession session,
    String blockId,
  ) {
    final block = session.blockById(blockId);
    if (block == null) return const SizedBox.shrink();
    return WorkspaceBlockActions(
      block: block,
      session: session,
      interaction: _interaction,
      onReplaceImage: _replaceImage,
      onEditImageDetails: _editImageDetails,
      onExtractImageText: _extractImageText,
      onReplaceAttachment: _replaceAttachment,
      onOpenAttachment: _openAttachment,
      onEditAttachmentDetails: _editAttachmentDetails,
      onAlignSelection: _alignSelection,
      onDistributeSelection: _distributeSelection,
    );
  }

  bool _hasTextFormattingContext(WorkspaceEditorSession session) {
    final currentSelection = _interaction.context.currentSelection;
    if (currentSelection is! TextSelectionState ||
        currentSelection.isCollapsed) {
      return false;
    }
    final block = session.blockById(currentSelection.blockId);
    return block is TextBlock &&
        (_interaction.context.editingBlock == block.id ||
            _interaction.context.selectedBlock == block.id);
  }

  ToolbarContext _toolbarContext(WorkspaceEditorSession session) {
    final currentSelection = _interaction.context.currentSelection;
    if (!_hasTextFormattingContext(session) ||
        currentSelection is! TextSelectionState) {
      return const ToolbarContext(hasSelection: false);
    }
    final block = session.blockById(currentSelection.blockId);
    if (block is! TextBlock) {
      return const ToolbarContext(hasSelection: false);
    }
    final selection = BlockTextSelection(
      baseOffset: currentSelection.baseOffset,
      extentOffset: currentSelection.extentOffset,
    );
    return ToolbarContext(
      // Every action shown here can operate on this exact non-collapsed range.
      // Keeping the range as the source of truth also survives a temporary
      // focus change while a color or size popup is open.
      hasSelection: true,
      bold: session.textFormatActive(block.id, selection, 'bold', true),
      italic: session.textFormatActive(block.id, selection, 'italic', true),
      underline: session.textFormatActive(
        block.id,
        selection,
        'underline',
        true,
      ),
      strikethrough: session.textFormatActive(
        block.id,
        selection,
        'strikethrough',
        true,
      ),
      alignment: session.currentParagraphAlignmentFor(block.id, selection),
    );
  }

  void _applyTextFormat(String attribute, Object? value) {
    final currentSelection = _interaction.context.currentSelection;
    if (currentSelection is! TextSelectionState ||
        currentSelection.isCollapsed) {
      return;
    }
    _session?.applyTextFormat(
      currentSelection.blockId,
      BlockTextSelection(
        baseOffset: currentSelection.baseOffset,
        extentOffset: currentSelection.extentOffset,
      ),
      attribute,
      value,
    );
  }

  void _applyParagraphAlignment(String alignment) {
    final currentSelection = _interaction.context.currentSelection;
    if (currentSelection is! TextSelectionState ||
        currentSelection.isCollapsed) {
      return;
    }
    _session?.applyParagraphAlignment(
      currentSelection.blockId,
      BlockTextSelection(
        baseOffset: currentSelection.baseOffset,
        extentOffset: currentSelection.extentOffset,
      ),
      alignment,
    );
  }

  BlockTextSelection? _activeBlockTextSelection() {
    final selection = _interaction.context.currentSelection;
    if (selection is! TextSelectionState) return null;
    return BlockTextSelection(
      baseOffset: selection.baseOffset,
      extentOffset: selection.extentOffset,
    );
  }

  Widget _canvasMenu(WorkspaceEditorSession session) => PopupMenuButton<String>(
    tooltip: 'Herramientas de Canvas',
    icon: const Icon(Icons.construction_outlined),
    onSelected: (action) => _handleCanvasAction(session, action),
    itemBuilder: (_) => [
      const PopupMenuItem(
        value: 'select',
        child: Text('Herramienta Selección'),
      ),
      const PopupMenuItem(value: 'hand', child: Text('Herramienta Mano')),
      const PopupMenuItem(
        value: 'text',
        child: Text('Insertar texto en el centro'),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'fit-content',
        child: Text('Encajar contenido'),
      ),
      PopupMenuItem(
        value: 'fit-selection',
        enabled: _selectedBlockIds.isNotEmpty,
        child: Text('Zoom a la selección'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'front',
        enabled: _selectedBlockIds.length == 1,
        child: const Text('Traer al frente'),
      ),
      PopupMenuItem(
        value: 'forward',
        enabled: _selectedBlockIds.length == 1,
        child: const Text('Adelantar una capa'),
      ),
      PopupMenuItem(
        value: 'backward',
        enabled: _selectedBlockIds.length == 1,
        child: const Text('Atrasar una capa'),
      ),
      PopupMenuItem(
        value: 'back',
        enabled: _selectedBlockIds.length == 1,
        child: const Text('Enviar al fondo'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'align-top',
        enabled: _selectedBlockIds.length >= 2,
        child: const Text('Alinear arriba'),
      ),
      PopupMenuItem(
        value: 'align-bottom',
        enabled: _selectedBlockIds.length >= 2,
        child: const Text('Alinear abajo'),
      ),
      PopupMenuItem(
        value: 'distribute-horizontal',
        enabled: _selectedBlockIds.length >= 3,
        child: const Text('Distribuir horizontalmente'),
      ),
      PopupMenuItem(
        value: 'connect',
        enabled: _selectedBlockIds.length == 2,
        child: const Text('Conectar dos bloques seleccionados'),
      ),
      PopupMenuItem(
        value: 'delete-connectors',
        enabled: _selectedBlockIds.isNotEmpty,
        child: const Text('Eliminar conexiones de la selección'),
      ),
      PopupMenuItem(
        value: 'frame',
        enabled: _selectedBlockIds.isNotEmpty,
        child: const Text('Crear marco para la selección'),
      ),
      const PopupMenuDivider(),
      CheckedPopupMenuItem(
        value: 'grid',
        checked: session.page.canvasLayout?.showGrid ?? true,
        child: const Text('Mostrar rejilla'),
      ),
      CheckedPopupMenuItem(
        value: 'snap',
        checked: session.page.canvasLayout?.snapToGrid ?? true,
        child: const Text('Ajustar a rejilla'),
      ),
    ],
  );

  void _handleCanvasAction(WorkspaceEditorSession session, String action) {
    if (action == 'select') {
      _interaction.activateTool(WorkspaceTool.selection);
      return;
    }
    if (action == 'hand') {
      _interaction.activateTool(WorkspaceTool.hand);
      return;
    }
    if (action == 'text') {
      _interaction.activateTool(WorkspaceTool.selection);
      _insertBlock(BlockType.text);
      return;
    }
    if (action == 'fit-content' || action == 'fit-selection') {
      _fitCanvas(selectionOnly: action == 'fit-selection');
      return;
    }
    final ids = _selectedBlockIds;
    final single = ids.length == 1 ? ids.single : null;
    if (single != null) {
      if (action == 'front') {
        session.changeCanvasZOrder(single, 1, absolute: true);
      }
      if (action == 'forward') session.changeCanvasZOrder(single, 1);
      if (action == 'backward') session.changeCanvasZOrder(single, -1);
      if (action == 'back') {
        session.changeCanvasZOrder(single, -1, absolute: true);
      }
    }
    if (action == 'align-top') _alignSelection(BlockAlignmentAxis.top);
    if (action == 'align-bottom') _alignSelection(BlockAlignmentAxis.bottom);
    if (action == 'distribute-horizontal') {
      session.distributeBlocksHorizontally(ids, _selectedWorkspaceBounds());
    }
    if (action == 'connect' && ids.length == 2) {
      session.connectCanvasBlocks(ids.first, ids.last);
    }
    if (action == 'delete-connectors') session.deleteCanvasConnectorsFor(ids);
    if (action == 'frame') {
      session.createCanvasFrame(ids, _selectedWorkspaceBounds());
    }
    final layout = session.page.canvasLayout;
    if (action == 'grid') {
      session.updateCanvasSettings(showGrid: !(layout?.showGrid ?? true));
    }
    if (action == 'snap') {
      session.updateCanvasSettings(snapToGrid: !(layout?.snapToGrid ?? true));
    }
  }

  void _fitCanvas({required bool selectionOnly}) {
    final layout = _session?.page.canvasLayout;
    if (layout == null) return;
    final selected = _selectedBlockIds.toSet();
    final placements = layout.placements
        .where((item) => !selectionOnly || selected.contains(item.blockId))
        .toList();
    if (placements.isEmpty) return;
    var bounds = placements.first.bounds();
    for (final placement in placements.skip(1)) {
      final next = placement.bounds();
      bounds = SpatialRect.fromLTRB(
        bounds.left < next.left ? bounds.left : next.left,
        bounds.top < next.top ? bounds.top : next.top,
        bounds.right > next.right ? bounds.right : next.right,
        bounds.bottom > next.bottom ? bounds.bottom : next.bottom,
      );
    }
    final size = MediaQuery.sizeOf(context);
    _viewportController.fitBounds(
      bounds,
      viewportWidth: size.width,
      viewportHeight: size.height - kToolbarHeight,
    );
  }

  Widget _insertMenu() => PopupMenuButton<BlockType>(
    tooltip: 'Insertar bloque',
    icon: const Icon(Icons.add_box_outlined),
    onSelected: _insertBlock,
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: BlockType.text,
        child: ListTile(leading: Icon(Icons.text_fields), title: Text('Texto')),
      ),
      PopupMenuItem(
        value: BlockType.image,
        child: ListTile(
          leading: Icon(Icons.image_outlined),
          title: Text('Imagen'),
        ),
      ),
      PopupMenuItem(
        value: BlockType.divider,
        child: ListTile(
          leading: Icon(Icons.horizontal_rule),
          title: Text('Separador'),
        ),
      ),
      PopupMenuItem(
        value: BlockType.checklist,
        child: ListTile(
          leading: Icon(Icons.check_box_outlined),
          title: Text('Checklist'),
        ),
      ),
      PopupMenuItem(
        value: BlockType.code,
        child: ListTile(leading: Icon(Icons.code), title: Text('Código')),
      ),
      PopupMenuItem(
        value: BlockType.table,
        child: ListTile(
          leading: Icon(Icons.table_chart_outlined),
          title: Text('Tabla'),
        ),
      ),
      PopupMenuItem(
        value: BlockType.attachment,
        child: ListTile(
          leading: Icon(Icons.attach_file),
          title: Text('Archivo'),
        ),
      ),
    ],
  );

  Widget _historyActions(WorkspaceEditorSession session) => AnimatedBuilder(
    animation: session,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Deshacer',
          onPressed: session.canUndo
              ? () {
                  _interaction.dispatch(const CancelInteractionIntent());
                  session.undo();
                  if (mounted) setState(() {});
                }
              : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: 'Rehacer',
          onPressed: session.canRedo
              ? () {
                  _interaction.dispatch(const CancelInteractionIntent());
                  session.redo();
                  if (mounted) setState(() {});
                }
              : null,
          icon: const Icon(Icons.redo),
        ),
      ],
    ),
  );

  Widget _categoryMenu() => PopupMenuButton<String>(
    tooltip: 'Categoría',
    icon: Icon(
      Icons.label_outline,
      color: CategoryCatalog.resolve(_categoryId).color,
    ),
    onSelected: _changeCategory,
    itemBuilder: (_) => [
      for (final category in CategoryCatalog.values)
        PopupMenuItem(
          value: category.id,
          child: Row(
            children: [
              CircleAvatar(radius: 7, backgroundColor: category.color),
              const SizedBox(width: 10),
              Text(category.name),
              if (_categoryId == category.id) ...[
                const Spacer(),
                const Icon(Icons.check, size: 18),
              ],
            ],
          ),
        ),
    ],
  );

  Widget _saveIndicator() => ValueListenableBuilder<EditorSaveStatus>(
    valueListenable: _saveStatus,
    builder: (context, status, _) => Tooltip(
      message: switch (status) {
        EditorSaveStatus.editing => 'Cambios pendientes',
        EditorSaveStatus.saving => 'Guardando',
        EditorSaveStatus.saved => 'Guardado',
        EditorSaveStatus.error => 'Error al guardar',
      },
      child: Semantics(
        label: switch (status) {
          EditorSaveStatus.editing => 'Cambios pendientes',
          EditorSaveStatus.saving => 'Guardando documento',
          EditorSaveStatus.saved => 'Documento guardado',
          EditorSaveStatus.error => 'Error al guardar el documento',
        },
        child: SizedBox.square(
          dimension: 36,
          child: Center(
            child: switch (status) {
              EditorSaveStatus.editing => const Icon(
                Icons.edit_outlined,
                size: 19,
              ),
              EditorSaveStatus.saving => const SizedBox.square(
                dimension: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              EditorSaveStatus.saved => Icon(
                Icons.cloud_done_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              EditorSaveStatus.error => Icon(
                Icons.cloud_off_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
            },
          ),
        ),
      ),
    ),
  );

  void _onBlockChanged(
    BaseBlock block, {
    required String kind,
    bool mergeable = false,
    bool refreshPresentation = false,
  }) {
    _session?.updateBlock(
      block,
      kind: kind,
      mergeable: mergeable,
      refreshPresentation: refreshPresentation,
    );
  }

  Future<void> _insertBlock(BlockType type) async {
    final session = _session;
    if (session == null) return;
    final activeBlockId = _interaction.context.selectedBlock;
    final activeSelection = _activeBlockTextSelection();
    if (type == BlockType.image) {
      final source = await _chooseImageSource();
      if (source == null || !mounted) return;
      if (source == ImageSource.camera) {
        final permission = await Permission.camera.request();
        if (!permission.isGranted) {
          if (permission.isPermanentlyDenied && mounted) {
            _showError(
              'Activa el permiso de cámara en ajustes para tomar fotografías.',
            );
          }
          return;
        }
      }
      final picked = await _imagePicker.pickImage(source: source);
      if (picked == null || !mounted) return;
      try {
        final stored = await _attachmentStorage.copyImage(picked);
        _attachmentPaths[stored.id] = stored.localPath;
        _commitInsertedBlock(
          session,
          ImageBlock(
            id: generateUuid(),
            orderKey: session.blocks.length.toDouble(),
            attachmentId: stored.id,
            altText: stored.originalFileName,
            metadata: {
              'mimeType': stored.mimeType,
              'sizeBytes': stored.sizeBytes,
              'originalFileName': stored.originalFileName,
            },
          ),
          activeBlockId: activeBlockId,
          textSelection: activeSelection,
        );
      } catch (error) {
        _showError('No se pudo insertar la imagen: $error');
      }
      return;
    }
    if (type == BlockType.attachment) {
      await _insertAttachment(activeBlockId, activeSelection);
      return;
    }
    _commitInsertedBlock(
      session,
      _registry.create(type, orderKey: session.blocks.length.toDouble()),
      activeBlockId: activeBlockId,
      textSelection: activeSelection,
    );
  }

  Future<ImageSource?> _chooseImageSource() =>
      showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tomar fotografía'),
                subtitle: const Text('Capturar una imagen con la cámara'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de la galería'),
                subtitle: const Text('Insertar una imagen existente'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      );

  Future<void> _showInsertSheet() async {
    final selection = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.video_file_outlined),
              title: const Text('Video'),
              subtitle: const Text('Grabar o elegir un video local'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            for (final choice in const [
              (BlockType.text, Icons.text_fields, 'Texto'),
              (BlockType.image, Icons.image_outlined, 'Imagen'),
              (BlockType.checklist, Icons.check_box_outlined, 'Checklist'),
              (BlockType.code, Icons.code, 'Código'),
              (BlockType.table, Icons.table_chart_outlined, 'Tabla'),
              (BlockType.attachment, Icons.attach_file, 'Archivo'),
              (BlockType.divider, Icons.horizontal_rule, 'Separador'),
            ])
              ListTile(
                leading: Icon(choice.$2),
                title: Text(choice.$3),
                onTap: () => Navigator.pop(context, choice.$1),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return;
    if (selection == 'video') {
      await _insertVideoAttachment();
    } else if (selection is BlockType) {
      await _insertBlock(selection);
    }
  }

  Future<void> _insertVideoAttachment() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Grabar video'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Elegir video'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (source == ImageSource.camera) {
      final camera = await Permission.camera.request();
      final microphone = await Permission.microphone.request();
      if (!camera.isGranted || !microphone.isGranted) {
        _showError('Se requieren cámara y micrófono para grabar video.');
        return;
      }
    }
    final picked = await _imagePicker.pickVideo(source: source);
    if (picked == null || !mounted) return;
    final length = await picked.length();
    final activeBlockId = _interaction.context.selectedBlock;
    final textSelection = _activeBlockTextSelection();
    try {
      final stored = await _attachmentStorage.copyFile(
        PlatformFile(name: picked.name, path: picked.path, size: length),
      );
      _attachmentPaths[stored.id] = stored.localPath;
      final session = _session;
      if (session == null) return;
      _commitInsertedBlock(
        session,
        AttachmentBlock(
          id: generateUuid(),
          orderKey: session.blocks.length.toDouble(),
          attachmentId: stored.id,
          displayName: stored.originalFileName,
          mimeType: stored.mimeType,
          extension: stored.extension,
          sizeBytes: stored.sizeBytes,
          description: 'Video local',
          metadata: {'checksum': stored.checksum, 'mediaKind': 'video'},
        ),
        activeBlockId: activeBlockId,
        textSelection: textSelection,
      );
    } catch (error) {
      _showError('No se pudo insertar el video: $error');
    }
  }

  Future<void> _showCanvasInsertMenu(Offset position) async {
    _interaction.dispatch(const CancelInteractionIntent());
    _requestedCanvasInsertPosition = SpatialPoint(position.dx, position.dy);
    final type = await showModalBottomSheet<BlockType>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Insertar en Canvas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'El bloque aparecerá donde mantuviste presionado.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.8,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                children: [
                  _canvasInsertChoice(
                    context,
                    BlockType.text,
                    Icons.text_fields,
                    'Texto',
                  ),
                  _canvasInsertChoice(
                    context,
                    BlockType.image,
                    Icons.image_outlined,
                    'Imagen',
                  ),
                  _canvasInsertChoice(
                    context,
                    BlockType.checklist,
                    Icons.check_box_outlined,
                    'Checklist',
                  ),
                  _canvasInsertChoice(
                    context,
                    BlockType.code,
                    Icons.code,
                    'Código',
                  ),
                  _canvasInsertChoice(
                    context,
                    BlockType.table,
                    Icons.table_chart_outlined,
                    'Tabla',
                  ),
                  _canvasInsertChoice(
                    context,
                    BlockType.attachment,
                    Icons.attach_file,
                    'Archivo',
                  ),
                  _canvasInsertChoice(
                    context,
                    BlockType.divider,
                    Icons.horizontal_rule,
                    'Separador',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (type != null && mounted) await _insertBlock(type);
    _requestedCanvasInsertPosition = null;
  }

  Widget _canvasInsertChoice(
    BuildContext context,
    BlockType type,
    IconData icon,
    String label,
  ) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pop(context, type),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(label)),
        ],
      ),
    ),
  );

  Future<void> _insertAttachment(
    String? activeBlockId,
    BlockTextSelection? textSelection,
  ) async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final file = result?.files.single;
    if (file == null || !mounted) return;
    try {
      final stored = await _attachmentStorage.copyFile(file);
      _attachmentPaths[stored.id] = stored.localPath;
      final session = _session;
      if (session == null) return;
      _commitInsertedBlock(
        session,
        AttachmentBlock(
          id: generateUuid(),
          orderKey: _session!.blocks.length.toDouble(),
          attachmentId: stored.id,
          displayName: stored.originalFileName,
          mimeType: stored.mimeType,
          extension: stored.extension,
          sizeBytes: stored.sizeBytes,
          metadata: {'checksum': stored.checksum},
        ),
        activeBlockId: activeBlockId,
        textSelection: textSelection,
      );
    } catch (error) {
      _showError('No se pudo adjuntar el archivo: $error');
    }
  }

  void _commitInsertedBlock(
    WorkspaceEditorSession session,
    BaseBlock block, {
    required String? activeBlockId,
    required BlockTextSelection? textSelection,
  }) {
    final canvasPosition = session.page.layoutType == WorkspaceLayoutType.canvas
        ? _requestedCanvasInsertPosition ??
              _viewportController.camera.viewportToWorkspace(
                SpatialPoint(
                  MediaQuery.sizeOf(context).width / 2,
                  MediaQuery.sizeOf(context).height / 2,
                ),
              )
        : null;
    session.insertBlock(
      block,
      activeBlockId: activeBlockId,
      textSelection: textSelection,
      canvasPosition: canvasPosition,
    );
    if (block is TextBlock) {
      _interaction.dispatch(
        StartEditingIntent(
          blockId: block.id,
          selection: TextSelectionState(
            blockId: block.id,
            baseOffset: 0,
            extentOffset: 0,
          ),
        ),
      );
    } else {
      _interaction.dispatch(SelectBlockIntent(block.id));
    }
  }

  Future<void> _replaceImage(ImageBlock block) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    try {
      final stored = await _attachmentStorage.copyImage(picked);
      _attachmentPaths[stored.id] = stored.localPath;
      _session?.updateBlock(
        block.copyWith(
          attachmentId: stored.id,
          altText: stored.originalFileName,
          metadata: {
            ...block.metadata,
            'mimeType': stored.mimeType,
            'sizeBytes': stored.sizeBytes,
            'originalFileName': stored.originalFileName,
          },
        ),
        kind: 'replaceImage',
        refreshPresentation: true,
      );
    } catch (error) {
      _showError('No se pudo reemplazar la imagen: $error');
    }
  }

  Future<void> _extractImageText(ImageBlock block) async {
    final session = _session;
    final path =
        _attachmentPaths[block.attachmentId] ??
        await _attachmentStorage.resolvePath(block.attachmentId);
    if (!mounted) return;
    if (session == null || path == null) {
      _showError('No se encontró la imagen original para ejecutar OCR.');
      return;
    }
    if (!_imageTextExtractor.isSupported) {
      _showError('El OCR local está disponible actualmente en Android y iOS.');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Extrayendo texto de la imagen…')),
    );
    try {
      final result = await _imageTextExtractor.extract(path);
      if (!mounted) return;
      if (result.isEmpty) {
        _showError('No se encontró texto legible en la imagen.');
        return;
      }
      final textBlock =
          (_registry.create(
                    BlockType.text,
                    orderKey: session.blocks.length.toDouble(),
                  )
                  as TextBlock)
              .withPlainText(result.text);
      if (session.page.layoutType == WorkspaceLayoutType.canvas) {
        final source = session.page.canvasLayout?.placementFor(block.id);
        session.insertBlock(
          textBlock,
          activeBlockId: block.id,
          canvasPosition: source == null
              ? null
              : SpatialPoint(source.x, source.y + (source.height ?? 220) + 32),
        );
      } else {
        session.insertBlock(textBlock, activeBlockId: block.id);
      }
      _interaction.dispatch(SelectBlockIntent(textBlock.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Texto extraído en ${result.blockCount} regiones y agregado como bloque editable.',
          ),
        ),
      );
    } catch (error) {
      _showError('No se pudo extraer el texto: $error');
    }
  }

  Future<void> _editImageDetails(ImageBlock block) async {
    final alt = TextEditingController(text: block.altText);
    final caption = TextEditingController(text: block.caption);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalles de imagen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: alt,
              decoration: const InputDecoration(labelText: 'Texto alternativo'),
            ),
            TextField(
              controller: caption,
              decoration: const InputDecoration(labelText: 'Caption'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      _session?.updateBlock(
        block.copyWith(
          altText: alt.text.trim(),
          caption: caption.text.trim(),
          clearAltText: alt.text.trim().isEmpty,
          clearCaption: caption.text.trim().isEmpty,
        ),
        kind: 'updateImageMetadata',
        refreshPresentation: true,
      );
    }
    alt.dispose();
    caption.dispose();
    _interaction.dispatch(
      const CancelInteractionIntent(
        reason: InteractionCancellationReason.dialogClosed,
        keepBlockSelected: true,
      ),
    );
  }

  Future<void> _replaceAttachment(AttachmentBlock block) async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final file = result?.files.single;
    if (file == null || !mounted) return;
    try {
      final stored = await _attachmentStorage.copyFile(file);
      _attachmentPaths[stored.id] = stored.localPath;
      _session?.updateBlock(
        block.copyWith(
          attachmentId: stored.id,
          displayName: stored.originalFileName,
          mimeType: stored.mimeType,
          extension: stored.extension,
          sizeBytes: stored.sizeBytes,
          metadata: {...block.metadata, 'checksum': stored.checksum},
        ),
        kind: 'replaceAttachment',
        refreshPresentation: true,
      );
    } catch (error) {
      _showError('No se pudo reemplazar el archivo: $error');
    }
  }

  Future<void> _editAttachmentDetails(AttachmentBlock block) async {
    final name = TextEditingController(text: block.displayName);
    final description = TextEditingController(text: block.description);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar archivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nombre visible'),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(
                labelText: 'Descripción opcional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (accepted == true && name.text.trim().isNotEmpty) {
      _session?.updateBlock(
        block.copyWith(
          displayName: name.text.trim(),
          description: description.text.trim(),
          clearDescription: description.text.trim().isEmpty,
        ),
        kind: 'updateAttachmentMetadata',
        refreshPresentation: true,
      );
    }
    name.dispose();
    description.dispose();
    _interaction.dispatch(
      const CancelInteractionIntent(
        reason: InteractionCancellationReason.dialogClosed,
        keepBlockSelected: true,
      ),
    );
  }

  Future<void> _openAttachment(AttachmentBlock block) async {
    final path =
        _attachmentPaths[block.attachmentId] ??
        await _attachmentStorage.resolvePath(block.attachmentId);
    if (!mounted) return;
    if (path == null) {
      _showError('El archivo ya no está disponible en este dispositivo.');
      return;
    }
    if (block.mimeType == 'application/pdf' ||
        block.extension.toLowerCase() == 'pdf') {
      await showPdfAttachmentPreview(
        context,
        path: path,
        title: block.displayName,
      );
      return;
    }
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      _showError(
        'No se encontró una aplicación compatible para abrir el archivo.',
      );
    }
  }

  Future<void> _exportDocument() async {
    await _save();
    if (!mounted) return;
    final type = await showDocumentExportSheet(context);
    if (type == null || !mounted) return;
    final document = _document;
    if (document == null) return;
    try {
      final result = await DocumentExportService().export(document, type);
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline),
          title: const Text('Exportación lista'),
          content: Text(
            [
              if (result.warning != null) result.warning!,
              'Se guardó una copia en la carpeta privada de exportaciones.',
            ].join('\n\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, 'open'),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'share'),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Compartir'),
            ),
          ],
        ),
      );
      if (action == 'open') {
        await OpenFilex.open(result.path);
      } else if (action == 'share') {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(result.path)]),
        );
      }
    } catch (error) {
      _showError('No se pudo exportar el documento: $error');
    }
  }

  void _changeCategory(String categoryId) {
    final document = _document;
    if (document == null || _categoryId == categoryId) return;
    setState(() => _categoryId = categoryId);
    _scheduleSave();
  }

  Future<void> _pickCategory() async {
    final categoryId = await showDocumentCategoryPicker(
      context,
      currentCategoryId: _categoryId,
    );
    if (categoryId != null) _changeCategory(categoryId);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _titleController
      ..removeListener(_scheduleSave)
      ..dispose();
    _session?.removeListener(_invalidateUnmountedSelection);
    _session?.dispose();
    _interaction.dispose();
    _inputDispatcher?.dispose();
    _overlayController?.dispose();
    _geometryRegistry.dispose();
    _scrollController.dispose();
    _viewportController.dispose();
    _saveStatus.dispose();
    unawaited(_imageTextExtractor.dispose());
    super.dispose();
  }
}
