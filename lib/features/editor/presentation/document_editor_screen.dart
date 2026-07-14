import 'dart:async';

import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/domain/use_cases/document_use_cases.dart';
import 'package:allministrator/features/documents/presentation/category_catalog.dart';
import 'package:allministrator/features/editor/data/local_attachment_storage.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_list_view.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_registry.dart';
import 'package:allministrator/features/editor/presentation/smart_formatting_toolbar.dart';
import 'package:allministrator/features/editor/presentation/interaction/workspace_surface.dart';
import 'package:allministrator/features/editor/presentation/interaction/workspace_block_actions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

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

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final LocalAttachmentStorage _attachmentStorage = LocalAttachmentStorage();
  final ImagePicker _imagePicker = ImagePicker();
  final BlockRegistry _registry = BlockRegistry.standard();
  final WorkspaceInteractionController _interaction =
      WorkspaceInteractionController();
  final BlockGeometryRegistry _geometryRegistry = BlockGeometryRegistry();
  final ScrollController _scrollController = ScrollController();
  InputDispatcher? _inputDispatcher;
  InteractionOverlayController? _overlayController;
  final InteractionDebugTimeline _interactionTimeline =
      InteractionDebugTimeline(limit: 100);
  final ValueNotifier<EditorSaveStatus> _saveStatus = ValueNotifier(
    EditorSaveStatus.saved,
  );
  final Map<String, String> _attachmentPaths = {};

  Timer? _saveTimer;
  Future<void> _saveQueue = Future<void>.value();
  Document? _document;
  String? _categoryId;
  WorkspaceEditorSession? _session;
  bool _loading = true;
  bool _changed = false;
  bool _exiting = false;
  int _changeRevision = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_scheduleSave);
    _load();
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
          visualOrder: () => _session?.blocks.map((block) => block.id).toList() ?? const [],
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
      workspaceType: WorkspaceType.document,
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
    if (intent is DeleteSelectionIntent) {
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
    if (mounted) context.go('/documents');
  }

  void _handleSystemBack() {
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
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _handleSystemBack();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a documentos',
          icon: const Icon(Icons.arrow_back),
          onPressed: _exitEditor,
        ),
        title: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _titleController,
          builder: (context, value, _) => Text(
            value.text.trim().isEmpty ? 'Documento sin título' : value.text,
          ),
        ),
        actions: [
          if (_session != null) _insertMenu(),
          if (_session != null) _historyActions(_session!),
          _categoryMenu(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: _saveIndicator()),
          ),
        ],
      ),
      body: Hero(
        tag: 'document-${widget.documentId}',
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: _buildBody(context),
        ),
      ),
    ),
  );

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final session = _session!;
    return WorkspaceSurface(
      workspaceId: session.workspace.id,
      pageId: session.page.id,
      registry: _geometryRegistry,
      interaction: _interaction,
      scrollController: _scrollController,
      keyboardInset: MediaQuery.viewInsetsOf(context).bottom,
      inputDispatcher: _inputDispatcher,
      overlayController: _overlayController,
      lockedBlockIds: {
        for (final block in session.blocks)
          if (block.isLocked) block.id,
      },
      modalBuilder: (context, blockId) =>
          _selectedBlockActions(context, session, blockId),
      content: BlockListView(
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
        header: Column(
          children: [
            TextField(
              controller: _titleController,
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: const InputDecoration(
                hintText: 'Título',
                border: InputBorder.none,
              ),
            ),
            const Divider(),
          ],
        ),
      ),
      transientOverlay: Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: AnimatedBuilder(
          animation: _interaction,
          builder: (context, _) {
            final toolbar = _toolbarContext(session);
            return ToolbarOverlay(
              visible: toolbar.hasSelection,
              child: SmartFormattingToolbar(
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
      onReplaceAttachment: _replaceAttachment,
      onOpenAttachment: _openAttachment,
      onEditAttachmentDetails: _editAttachmentDetails,
    );
  }

  ToolbarContext _toolbarContext(WorkspaceEditorSession session) {
    final currentSelection = _interaction.context.currentSelection;
    final block = session.blockById(_interaction.context.selectedBlock);
    if (block is! TextBlock || _interaction.context.editingBlock != block.id) {
      return const ToolbarContext(hasSelection: false);
    }
    if (currentSelection is! TextSelectionState ||
        currentSelection.blockId != block.id) {
      return const ToolbarContext(hasSelection: false);
    }
    final selection = BlockTextSelection(
      baseOffset: currentSelection.baseOffset,
      extentOffset: currentSelection.extentOffset,
    );
    final hasSelection = selection.baseOffset != selection.extentOffset;
    if (!hasSelection) return const ToolbarContext(hasSelection: false);
    return ToolbarContext(
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
    final selection = _activeBlockTextSelection();
    final blockId =
        _interaction.context.editingBlock ?? _interaction.context.selectedBlock;
    if (selection == null || blockId == null) return;
    _session?.applyTextFormat(blockId, selection, attribute, value);
  }

  void _applyParagraphAlignment(String alignment) {
    final selection = _activeBlockTextSelection();
    final blockId =
        _interaction.context.editingBlock ?? _interaction.context.selectedBlock;
    if (selection == null || blockId == null) return;
    _session?.applyParagraphAlignment(blockId, selection, alignment);
  }

  BlockTextSelection? _activeBlockTextSelection() {
    final selection = _interaction.context.currentSelection;
    if (selection is! TextSelectionState) return null;
    return BlockTextSelection(
      baseOffset: selection.baseOffset,
      extentOffset: selection.extentOffset,
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
    builder: (context, status, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == EditorSaveStatus.saving)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (status == EditorSaveStatus.error)
          Icon(
            Icons.error_outline,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
        const SizedBox(width: 4),
        Text(switch (status) {
          EditorSaveStatus.editing => 'Editando',
          EditorSaveStatus.saving => 'Guardando',
          EditorSaveStatus.saved => 'Guardado',
          EditorSaveStatus.error => 'Error',
        }, style: Theme.of(context).textTheme.bodySmall),
      ],
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
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
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
    session.insertBlock(
      block,
      activeBlockId: activeBlockId,
      textSelection: textSelection,
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
    if (path == null) {
      _showError('El archivo ya no está disponible en este dispositivo.');
      return;
    }
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      _showError(
        'No se encontró una aplicación compatible para abrir el archivo.',
      );
    }
  }

  void _changeCategory(String categoryId) {
    final document = _document;
    if (document == null || _categoryId == categoryId) return;
    setState(() => _categoryId = categoryId);
    _scheduleSave();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
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
    _saveStatus.dispose();
    super.dispose();
  }
}
