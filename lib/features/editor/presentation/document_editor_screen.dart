import 'dart:async';

import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/domain/use_cases/document_use_cases.dart';
import 'package:allministrator/features/documents/presentation/category_catalog.dart';
import 'package:allministrator/features/editor/data/local_attachment_storage.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_list_view.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_registry.dart';
import 'package:allministrator/features/editor/presentation/smart_formatting_toolbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

  Future<void> _exitEditor() async {
    if (_exiting) return;
    _exiting = true;
    await _beforeExit();
    if (mounted) context.go('/documents');
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _exitEditor();
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
    return Stack(
      children: [
        BlockListView(
          session: session,
          registry: _registry,
          onChanged: _onBlockChanged,
          resolveAttachmentPath: (id) => _attachmentPaths[id],
          onReplaceImage: _replaceImage,
          onReplaceAttachment: _replaceAttachment,
          onOpenAttachment: _openAttachment,
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
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: ValueListenableBuilder<int>(
            valueListenable: session.selectionRevision,
            builder: (context, _, _) {
              final toolbar = _toolbarContext(session);
              return ToolbarOverlay(
                visible: toolbar.hasSelection,
                child: SmartFormattingToolbar(
                  contextState: toolbar,
                  onToggle: session.applyTextFormat,
                  onColor: (color) => session.applyTextFormat('color', color),
                  onSize: (size) => session.applyTextFormat('fontSize', size),
                  onAlignment: session.applyParagraphAlignment,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  ToolbarContext _toolbarContext(WorkspaceEditorSession session) {
    final block = session.selectedBlock;
    if (block is! TextBlock) {
      return const ToolbarContext(hasSelection: false);
    }
    final selection = session.selectionFor(block.id) ?? block.selection;
    final hasSelection =
        selection != null && selection.baseOffset != selection.extentOffset;
    if (!hasSelection) return const ToolbarContext(hasSelection: false);
    return ToolbarContext(
      hasSelection: true,
      bold: session.textFormatActive('bold', true),
      italic: session.textFormatActive('italic', true),
      underline: session.textFormatActive('underline', true),
      strikethrough: session.textFormatActive('strikethrough', true),
      alignment: session.currentParagraphAlignment,
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
          onPressed: session.canUndo ? session.undo : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: 'Rehacer',
          onPressed: session.canRedo ? session.redo : null,
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
    if (type == BlockType.image) {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      try {
        final stored = await _attachmentStorage.copyImage(picked);
        _attachmentPaths[stored.id] = stored.localPath;
        session.insertBlock(
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
        );
      } catch (error) {
        _showError('No se pudo insertar la imagen: $error');
      }
      return;
    }
    if (type == BlockType.attachment) {
      await _insertAttachment();
      return;
    }
    session.insertBlock(
      _registry.create(type, orderKey: session.blocks.length.toDouble()),
    );
  }

  Future<void> _insertAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final file = result?.files.single;
    if (file == null || !mounted) return;
    try {
      final stored = await _attachmentStorage.copyFile(file);
      _attachmentPaths[stored.id] = stored.localPath;
      _session?.insertBlock(
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
      );
    } catch (error) {
      _showError('No se pudo adjuntar el archivo: $error');
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
    _session?.dispose();
    _saveStatus.dispose();
    super.dispose();
  }
}
