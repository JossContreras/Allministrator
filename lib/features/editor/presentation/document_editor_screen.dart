import 'dart:async';

import 'package:allministrator/features/documents/domain/entities/document.dart';
import 'package:allministrator/features/documents/domain/repositories/document_repository.dart';
import 'package:allministrator/features/documents/domain/use_cases/document_use_cases.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:allministrator/features/documents/presentation/category_catalog.dart';
import 'package:allministrator/domain/editing/editor_history.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'rich_text_editing_controller.dart';
import 'smart_formatting_toolbar.dart';
import 'package:allministrator/domain/editing/selection_controller.dart';
import 'package:allministrator/domain/editing/formatting_controller.dart';
import 'package:allministrator/features/editor/data/local_attachment_storage.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:image_picker/image_picker.dart';

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
  final _titleController = TextEditingController();
  final _contentController = RichTextEditingController();
  Timer? _saveTimer;
  Future<void> _saveQueue = Future<void>.value();
  Document? _document;
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;
  bool _exiting = false;
  int _changeRevision = 0;
  String? _error;
  final _softBreakOffsets = <int>{};
  bool _capturedSoftBreak = false;
  final _contentFocusNode = FocusNode();
  String _lastVisibleText = '';
  EditorHistoryController? _history;
  bool _applyingHistory = false;
  final _selectionController = SelectionController();
  late final ToolbarController _toolbarController = ToolbarController();
  FormattingController? _formattingController;
  final _attachmentStorage = LocalAttachmentStorage();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _contentFocusNode.onKeyEvent = (_, event) {
      final modifier =
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (event is KeyDownEvent &&
          modifier &&
          event.logicalKey == LogicalKeyboardKey.keyZ) {
        if (HardwareKeyboard.instance.isShiftPressed) {
          _applyHistoryAction(redo: true);
        } else {
          _applyHistoryAction(redo: false);
        }
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          modifier &&
          event.logicalKey == LogicalKeyboardKey.keyY) {
        _applyHistoryAction(redo: true);
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          HardwareKeyboard.instance.isShiftPressed) {
        final offset = _contentController.selection.baseOffset;
        if (offset >= 0) {
          _softBreakOffsets.add(offset);
          _capturedSoftBreak = true;
        }
      }
      return KeyEventResult.ignored;
    };
    _contentFocusNode.addListener(() {
      _toolbarController.setEditorFocus(_contentFocusNode.hasFocus);
      if (mounted) setState(() {});
    });
    _load();
    _titleController.addListener(_scheduleSave);
    _contentController.addListener(_scheduleSave);
    _contentController.addListener(_recordContentEdit);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _history?.dispose();
    super.dispose();
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
      _document = document;
      _titleController.text = document.title;
      _contentController.text = document.content.text;
      _contentController.setDocument(document.content.structured);
      for (final image
          in document.content.structured.nodes.whereType<ImageNode>()) {
        final path = await _attachmentStorage.resolvePath(image.attachmentId);
        if (path != null) {
          _contentController.attachmentPaths[image.attachmentId] = path;
        }
      }
      _lastVisibleText = _contentController.text;
      final structured = document.content.structured;
      _history = EditorHistoryController(
        initialState: EditorState(
          document: structured,
          selection: DocumentSelection.collapsed(
            DocumentPosition(nodeId: structured.nodes.first.id, offset: 0),
          ),
        ),
      );
      _selectionController.setSelection(
        _history!.current.selection,
        structured,
      );
      _formattingController = FormattingController(
        _history!,
        _selectionController,
      );
      setState(() => _loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo cargar el documento.';
        });
      }
    }
  }

  void _scheduleSave() {
    if (_loading || _document == null) return;
    if (!_capturedSoftBreak) {
      _adjustSoftBreakOffsets(_lastVisibleText, _contentController.text);
    }
    _lastVisibleText = _contentController.text;
    _capturedSoftBreak = false;
    _changed = true;
    _changeRevision++;
    setState(() => _saving = true);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  void _adjustSoftBreakOffsets(String previous, String current) {
    var prefix = 0;
    while (prefix < previous.length &&
        prefix < current.length &&
        previous[prefix] == current[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < previous.length - prefix &&
        suffix < current.length - prefix &&
        previous[previous.length - 1 - suffix] ==
            current[current.length - 1 - suffix]) {
      suffix++;
    }
    final oldEnd = previous.length - suffix;
    final delta = current.length - previous.length;
    final adjusted = <int>{};
    for (final offset in _softBreakOffsets) {
      if (offset < prefix) {
        adjusted.add(offset);
      } else if (offset >= oldEnd) {
        adjusted.add(offset + delta);
      }
    }
    _softBreakOffsets
      ..clear()
      ..addAll(adjusted);
  }

  void _recordContentEdit() {
    final history = _history;
    if (_loading || _applyingHistory || history == null) return;
    final before = history.current;
    final afterDocument = before.document.reconcileText(
      _contentController.text,
      _softBreakOffsets,
    );
    final currentSelection = _selectionFromController(afterDocument);
    _selectionController.setSelection(currentSelection, afterDocument);
    if (afterDocument.plainText == before.document.plainText &&
        afterDocument.toJson().toString() ==
            before.document.toJson().toString()) {
      if (currentSelection.anchor.nodeId != before.selection.anchor.nodeId ||
          currentSelection.anchor.offset != before.selection.anchor.offset ||
          currentSelection.focus.nodeId != before.selection.focus.nodeId ||
          currentSelection.focus.offset != before.selection.focus.offset) {
        history.updateSelection(currentSelection);
        _toolbarController.updateContext(
          history.current,
          _selectionController.context,
        );
        if (mounted) setState(() {});
      }
      return;
    }
    final after = EditorState(
      document: afterDocument,
      selection: currentSelection,
    );
    _contentController.setDocument(afterDocument);
    final delta =
        _contentController.text.length - before.document.plainText.length;
    final command = delta > 0
        ? InsertTextCommand(
            before: before,
            after: after,
            selectionBefore: before.selection,
            selectionAfter: after.selection,
          )
        : delta < 0
        ? DeleteTextCommand(
            before: before,
            after: after,
            selectionBefore: before.selection,
            selectionAfter: after.selection,
          )
        : ReplaceSelectionCommand(
            before: before,
            after: after,
            selectionBefore: before.selection,
            selectionAfter: after.selection,
          );
    history.executeCommand(command);
    _toolbarController.updateContext(
      history.current,
      _selectionController.context,
    );
    if (mounted) setState(() {});
  }

  DocumentSelection _selectionFromController(StructuredDocument document) {
    DocumentPosition positionAt(int offset) {
      var cursor = 0;
      for (final node in document.nodes.whereType<ParagraphNode>()) {
        final end = cursor + node.text.length;
        if (offset <= end) {
          return DocumentPosition(
            nodeId: node.id,
            offset: (offset - cursor).clamp(0, node.text.length),
          );
        }
        cursor = end + 1;
      }
      final last = document.nodes.last as ParagraphNode;
      return DocumentPosition(nodeId: last.id, offset: last.text.length);
    }

    final value = _contentController.selection;
    return DocumentSelection(
      anchor: positionAt(
        value.baseOffset.clamp(0, _contentController.text.length),
      ),
      focus: positionAt(
        value.extentOffset.clamp(0, _contentController.text.length),
      ),
    );
  }

  TextSelection _controllerSelection(EditorState state) {
    int offsetOf(DocumentPosition position) {
      var offset = 0;
      for (final node in state.document.nodes.whereType<ParagraphNode>()) {
        if (node.id == position.nodeId) return offset + position.offset;
        offset += node.text.length + 1;
      }
      return offset;
    }

    return TextSelection(
      baseOffset: offsetOf(state.selection.anchor),
      extentOffset: offsetOf(state.selection.focus),
    );
  }

  void _applyHistoryAction({required bool redo}) {
    final history = _history;
    if (history == null || (redo ? !history.canRedo : !history.canUndo)) return;
    _applyingHistory = true;
    if (redo) {
      history.redo();
    } else {
      history.undo();
    }
    final state = history.current;
    _selectionController.setSelection(state.selection, state.document);
    _toolbarController.updateContext(state, _selectionController.context);
    _contentController.value = TextEditingValue(
      text: state.document.plainText,
      selection: _controllerSelection(state),
    );
    _contentController.setDocument(state.document);
    _lastVisibleText = _contentController.text;
    _softBreakOffsets.clear();
    _applyingHistory = false;
    _scheduleSave();
  }

  Future<void> _save() {
    final operation = _saveQueue.then((_) => _performSave());
    _saveQueue = operation.catchError((_) {});
    return operation;
  }

  Future<void> _performSave() async {
    final document = _document;
    if (document == null || !_changed) return;
    final revision = _changeRevision;
    try {
      final saved = await UpdateDocument(widget.repository)(
        document.copyWith(
          title: _titleController.text,
          content: document.content.withStructured(
            _history?.current.document ?? document.content.structured,
          ),
        ),
      );
      if (mounted) {
        setState(() {
          _document = saved;
          _saving = false;
          if (_changeRevision == revision) _changed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _beforeExit() async {
    _saveTimer?.cancel();
    await _save();
  }

  Future<void> _exitEditor() async {
    if (_exiting) return;
    _exiting = true;
    await _beforeExit();
    if (!mounted) return;
    context.go('/documents');
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
        title: Text(
          _document?.title.trim().isNotEmpty == true
              ? _document!.title
              : 'Documento sin título',
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Insertar objeto',
            icon: const Icon(Icons.add_box_outlined),
            onSelected: (value) {
              if (value == 'image') _insertImage();
              if (value == 'divider') _insertDivider();
              if (value == 'checklist') _insertChecklist();
              if (value == 'quote') _insertQuote();
              if (value == 'callout') _insertCallout();
              if (value == 'code') _insertCode();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'image',
                child: ListTile(
                  leading: Icon(Icons.image_outlined),
                  title: Text('Imagen'),
                ),
              ),
              PopupMenuItem(
                value: 'divider',
                child: ListTile(
                  leading: Icon(Icons.horizontal_rule),
                  title: Text('Separador'),
                ),
              ),
              PopupMenuItem(
                value: 'checklist',
                child: ListTile(
                  leading: Icon(Icons.check_box_outlined),
                  title: Text('Checklist'),
                ),
              ),
              PopupMenuItem(
                value: 'quote',
                child: ListTile(
                  leading: Icon(Icons.format_quote),
                  title: Text('Cita'),
                ),
              ),
              PopupMenuItem(
                value: 'callout',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Callout'),
                ),
              ),
              PopupMenuItem(
                value: 'code',
                child: ListTile(
                  leading: Icon(Icons.code),
                  title: Text('Código'),
                ),
              ),
            ],
          ),
          if (_history != null)
            AnimatedBuilder(
              animation: _history!,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Deshacer',
                    onPressed: _history!.canUndo
                        ? () => _applyHistoryAction(redo: false)
                        : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: 'Rehacer',
                    onPressed: _history!.canRedo
                        ? () => _applyHistoryAction(redo: true)
                        : null,
                    icon: const Icon(Icons.redo),
                  ),
                ],
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'Categoría',
            icon: Icon(
              Icons.label_outline,
              color: CategoryCatalog.resolve(_document?.categoryId).color,
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
                      if (_document?.categoryId == category.id) ...[
                        const Spacer(),
                        const Icon(Icons.check, size: 18),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                _saving ? 'Guardando…' : 'Guardado',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
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
    final editor = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        TextField(
          controller: _contentController,
          focusNode: _contentFocusNode,
          textAlign: _currentTextAlign(),
          minLines: 18,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Empieza a escribir…',
            border: InputBorder.none,
          ),
        ),
      ],
    );
    final toolbarContext = _toolbarContext();
    return Stack(
      children: [
        editor,
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: ToolbarOverlay(
            visible:
                _toolbarController.state.isVisible &&
                _contentFocusNode.hasFocus,
            child: SmartFormattingToolbar(
              contextState: toolbarContext,
              onToggle: _applyFormat,
              onColor: (color) => _applyFormat('color', color),
              onSize: (size) => _applyFormat('fontSize', size),
              onAlignment: _applyAlignment,
            ),
          ),
        ),
      ],
    );
  }

  ToolbarContext _toolbarContext() {
    final history = _history;
    if (history == null || history.current.selection.isCollapsed) {
      return const ToolbarContext(hasSelection: false);
    }
    final document = history.current.document;
    final selection = history.current.selection;
    final paragraphIndex = document.nodes.indexWhere(
      (node) => node.id == selection.anchor.nodeId,
    );
    final alignment = paragraphIndex >= 0
        ? (document.nodes[paragraphIndex] as ParagraphNode).attributes.alignment
        : 'left';
    return ToolbarContext(
      hasSelection: true,
      bold: document.formatActive(selection, 'bold', true),
      italic: document.formatActive(selection, 'italic', true),
      underline: document.formatActive(selection, 'underline', true),
      strikethrough: document.formatActive(selection, 'strikethrough', true),
      alignment: alignment,
    );
  }

  void _applyFormat(String attribute, Object? value) {
    final history = _history;
    if (history == null || history.current.selection.isCollapsed) return;
    final formatting = _formattingController;
    if (formatting != null) {
      final before = history.current;
      switch (attribute) {
        case 'bold':
          formatting.toggleBold(before);
        case 'italic':
          formatting.toggleItalic(before);
        case 'underline':
          formatting.toggleUnderline(before);
        case 'strikethrough':
          formatting.toggleStrikethrough(before);
        case 'color':
          formatting.setTextColor(before, value as int?);
        case 'highlight':
          formatting.setHighlightColor(before, value as int?);
        case 'fontSize':
          formatting.setFontSize(before, value as double?);
        default:
          return;
      }
      final after = history.current;
      _contentController.setDocument(after.document);
      setState(() {});
      _scheduleSave();
      return;
    }
    final before = history.current;
    final after = EditorState(
      document: before.document.applyFormat(before.selection, attribute, value),
      selection: before.selection,
    );
    history.executeCommand(
      FormatTextCommand(
        before: before,
        after: after,
        selectionBefore: before.selection,
        selectionAfter: before.selection,
      ),
    );
    _contentController.setDocument(after.document);
    setState(() {});
    _scheduleSave();
  }

  void _applyAlignment(String alignment) {
    final history = _history;
    if (history == null || history.current.selection.isCollapsed) return;
    final formatting = _formattingController;
    if (formatting != null) {
      formatting.setParagraphAlignment(
        history.current,
        ParagraphAlignment.values.firstWhere((item) => item.name == alignment),
      );
      final after = history.current;
      _contentController.setDocument(after.document);
      setState(() {});
      _scheduleSave();
      return;
    }
    final before = history.current;
    final after = EditorState(
      document: before.document.setParagraphAttribute(
        before.selection,
        'alignment',
        alignment,
      ),
      selection: before.selection,
    );
    history.executeCommand(
      FormatTextCommand(
        before: before,
        after: after,
        selectionBefore: before.selection,
        selectionAfter: before.selection,
      ),
    );
    _contentController.setDocument(after.document);
    setState(() {});
    _scheduleSave();
  }

  TextAlign _currentTextAlign() {
    final history = _history;
    if (history == null) return TextAlign.left;
    final index = history.current.document.nodes.indexWhere(
      (node) => node.id == history.current.selection.anchor.nodeId,
    );
    if (index < 0) return TextAlign.left;
    final selected = history.current.document.nodes[index];
    if (selected is! ParagraphNode) return TextAlign.left;
    return switch (selected.attributes.alignment) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'justify' => TextAlign.justify,
      _ => TextAlign.left,
    };
  }

  Future<void> _insertImage() async {
    if (_history == null || _history!.current.selection.isCollapsed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coloca el cursor donde quieras insertar la imagen.'),
          ),
        );
      }
      return;
    }
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final stored = await _attachmentStorage.copyImage(picked);
      final before = _history!.current;
      final engine = DocumentEditingEngine(
        before.document,
        selection: before.selection,
      );
      final result = engine.insertImage(
        ImageNode(
          id: generateUuid(),
          attachmentId: stored.id,
          altText: stored.originalFileName,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      final after = EditorState(
        document: result.document,
        selection: result.selection,
      );
      _history!.executeCommand(
        InsertNodeCommand(
          before: before,
          after: after,
          selectionBefore: before.selection,
          selectionAfter: after.selection,
        ),
      );
      _contentController.attachmentPaths[stored.id] = stored.localPath;
      _applyingHistory = true;
      _contentController.value = TextEditingValue(
        text: after.document.plainText,
        selection: _controllerSelection(after),
      );
      _contentController.setDocument(after.document);
      _applyingHistory = false;
      setState(() {});
      _scheduleSave();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo insertar la imagen: $error')),
        );
      }
    }
  }

  void _insertDivider() {
    final history = _history;
    if (history == null) return;
    final before = history.current;
    final engine = DocumentEditingEngine(
      before.document,
      selection: before.selection,
    );
    final result = engine.insertDivider(DividerNode(id: generateUuid()));
    final after = EditorState(
      document: result.document,
      selection: result.selection,
    );
    history.executeCommand(
      InsertNodeCommand(
        before: before,
        after: after,
        selectionBefore: before.selection,
        selectionAfter: after.selection,
      ),
    );
    _applyingHistory = true;
    _contentController.value = TextEditingValue(
      text: after.document.plainText,
      selection: _controllerSelection(after),
    );
    _contentController.setDocument(after.document);
    _applyingHistory = false;
    setState(() {});
    _scheduleSave();
  }

  void _insertChecklist() =>
      _insertStructuredNode(ChecklistNode(id: generateUuid()));
  void _insertQuote() => _insertStructuredNode(QuoteNode(id: generateUuid()));
  void _insertCallout() =>
      _insertStructuredNode(CalloutNode(id: generateUuid(), title: 'Idea'));
  void _insertCode() =>
      _insertStructuredNode(CodeBlockNode(id: generateUuid()));

  void _insertStructuredNode(DocumentNode node) {
    final history = _history;
    if (history == null) return;
    final before = history.current;
    final result = DocumentEditingEngine(
      before.document,
      selection: before.selection,
    ).insertNode(node);
    final after = EditorState(
      document: result.document,
      selection: result.selection,
    );
    history.executeCommand(
      InsertNodeCommand(
        before: before,
        after: after,
        selectionBefore: before.selection,
        selectionAfter: after.selection,
      ),
    );
    _applyingHistory = true;
    _contentController.value = TextEditingValue(
      text: after.document.plainText,
      selection: _controllerSelection(after),
    );
    _contentController.setDocument(after.document);
    _applyingHistory = false;
    setState(() {});
    _scheduleSave();
  }

  Future<void> _changeCategory(String categoryId) async {
    final document = _document;
    if (document == null || document.categoryId == categoryId) return;
    try {
      final updated = await widget.repository.updateDocument(
        document.copyWith(categoryId: categoryId),
      );
      if (mounted) setState(() => _document = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la categoría')),
        );
      }
    }
  }
}
