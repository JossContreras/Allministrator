import 'dart:math' as math;

import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/interaction/spatial_geometry.dart';
import 'package:allministrator/domain/interaction/transformation_engine.dart';
import 'package:allministrator/domain/value_objects/structured_document.dart';
import 'package:flutter/foundation.dart';

typedef WorkspaceChanged = void Function(Workspace workspace);

class WorkspaceEditorSession extends ChangeNotifier {
  WorkspaceEditorSession({
    required Workspace workspace,
    required this.onChanged,
    this.maxOperations = 200,
  }) : _workspace = workspace;

  Workspace _workspace;
  final WorkspaceChanged onChanged;
  final int maxOperations;
  final ValueNotifier<int> presentationRevision = ValueNotifier(0);
  final List<_WorkspaceEdit> _undoStack = [];
  final List<_WorkspaceEdit> _redoStack = [];

  Workspace get workspace => _workspace;
  WorkspacePage get page => _workspace.primaryPage;
  List<BaseBlock> get blocks => page.orderedBlocks;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  BaseBlock? blockById(Uuid? id) {
    if (id == null) return null;
    for (final block in blocks) {
      if (block.id == id) return block;
    }
    return null;
  }

  void updateBlock(
    BaseBlock updated, {
    required String kind,
    bool mergeable = false,
    bool refreshPresentation = false,
  }) {
    final ordered = blocks;
    final index = ordered.indexWhere((block) => block.id == updated.id);
    if (index < 0) return;
    final previous = ordered[index];
    if (mapEquals(previous.toJson(), updated.toJson())) return;
    final now = DateTime.now().toUtc();
    final nextBlock = updated.copyWithCommon(
      updatedAt: now,
      version: previous.version + 1,
    );
    final nextBlocks = [...ordered]..[index] = nextBlock;
    _commit(
      _replaceBlocks(nextBlocks, now: now),
      kind: kind,
      blockId: updated.id,
      mergeable: mergeable,
      refreshPresentation: refreshPresentation,
    );
  }

  void insertBlock(
    BaseBlock block, {
    Uuid? activeBlockId,
    BlockTextSelection? textSelection,
  }) {
    final ordered = blocks;
    final selectedIndex = ordered.indexWhere(
      (candidate) => candidate.id == activeBlockId,
    );
    final selected = selectedIndex < 0 ? null : ordered[selectedIndex];
    final now = DateTime.now().toUtc();
    late List<BaseBlock> next;

    if (selected is TextBlock) {
      final fallback =
          selected.selection ??
          BlockTextSelection(
            baseOffset: selected.plainText.length,
            extentOffset: selected.plainText.length,
          );
      final selection = textSelection ?? fallback;
      final start = math.min(selection.baseOffset, selection.extentOffset);
      final end = math.max(selection.baseOffset, selection.extentOffset);
      var source = selected;
      if (start != end) {
        final text = source.plainText;
        source = source.withPlainText(
          text.replaceRange(
            start.clamp(0, text.length),
            end.clamp(0, text.length),
            '',
          ),
        );
      }
      final split = _splitTextBlock(source, start);
      next = [...ordered]
        ..replaceRange(selectedIndex, selectedIndex + 1, [
          split.left,
          block,
          split.right,
        ]);
    } else {
      final insertionIndex = selectedIndex < 0
          ? ordered.length
          : selectedIndex + 1;
      next = [...ordered]..insert(insertionIndex, block);
    }

    next = _normalizeOrder(next, now);
    _commit(
      _replaceBlocks(next, now: now),
      kind: 'insertBlock',
      blockId: block.id,
      refreshPresentation: true,
    );
  }

  void deleteBlock(String blockId) {
    final ordered = blocks;
    final index = ordered.indexWhere((block) => block.id == blockId);
    if (index < 0 || !ordered[index].supports(BlockCapability.deletable)) {
      return;
    }
    final now = DateTime.now().toUtc();
    final next = [...ordered]..removeAt(index);
    if (index > 0 &&
        index < next.length &&
        next[index - 1] is TextBlock &&
        next[index] is TextBlock) {
      final first = next[index - 1] as TextBlock;
      final second = next[index] as TextBlock;
      next.replaceRange(index - 1, index + 1, [
        first.copyWith(paragraphs: [...first.paragraphs, ...second.paragraphs]),
      ]);
    }
    if (next.isEmpty) {
      next.add(_emptyTextBlock(orderKey: 0, now: now));
    }
    final normalized = _normalizeOrder(next, now);
    _commit(
      _replaceBlocks(normalized, now: now),
      kind: 'deleteBlock',
      blockId: blockId,
      refreshPresentation: true,
    );
  }

  Uuid? duplicateBlock(String blockId) {
    final ordered = blocks;
    final index = ordered.indexWhere((block) => block.id == blockId);
    if (index < 0 || !ordered[index].supports(BlockCapability.duplicable)) {
      return null;
    }
    final json = _replaceIds(ordered[index].toJson()) as JsonMap;
    final clone = BlockCodec.fromJson(json);
    final now = DateTime.now().toUtc();
    final next = [...ordered]..insert(index + 1, clone);
    final normalized = _normalizeOrder(next, now);
    _commit(
      _replaceBlocks(normalized, now: now),
      kind: 'duplicateBlock',
      blockId: clone.id,
      refreshPresentation: true,
    );
    return clone.id;
  }

  void moveBlock(String blockId, int delta) {
    if (delta == 0) return;
    final ordered = blocks;
    final index = ordered.indexWhere((block) => block.id == blockId);
    if (index < 0 || !ordered[index].supports(BlockCapability.movable)) return;
    final target = (index + delta).clamp(0, ordered.length - 1);
    if (target == index) return;
    final next = [...ordered];
    final block = next.removeAt(index);
    next.insert(target, block);
    final now = DateTime.now().toUtc();
    _commit(
      _replaceBlocks(_normalizeOrder(next, now), now: now),
      kind: 'moveBlock',
      blockId: blockId,
      refreshPresentation: true,
    );
  }

  /// Commits a drag drop as one reversible editor command.
  void moveBlockTo(
    String blockId, {
    String? targetBlockId,
    required bool insertAfter,
  }) {
    final ordered = blocks;
    final sourceIndex = ordered.indexWhere((block) => block.id == blockId);
    if (sourceIndex < 0 ||
        !ordered[sourceIndex].supports(BlockCapability.movable)) {
      return;
    }
    final next = [...ordered];
    final source = next.removeAt(sourceIndex);
    var insertionIndex = targetBlockId == null
        ? next.length
        : next.indexWhere((block) => block.id == targetBlockId);
    if (insertionIndex < 0) insertionIndex = next.length;
    if (insertAfter && insertionIndex < next.length) insertionIndex++;
    insertionIndex = insertionIndex.clamp(0, next.length);
    next.insert(insertionIndex, source);
    if (listEquals(
      ordered.map((block) => block.id).toList(),
      next.map((block) => block.id).toList(),
    )) {
      return;
    }
    final now = DateTime.now().toUtc();
    _commit(
      _replaceBlocks(_normalizeOrder(next, now), now: now),
      kind: 'dragBlock',
      blockId: blockId,
      refreshPresentation: true,
    );
  }

  /// One history entry for a multi-block drag while preserving visual order.
  void moveBlocksTo(
    Iterable<String> blockIds, {
    String? targetBlockId,
    required bool insertAfter,
  }) {
    final selectedIds = blockIds.toSet();
    if (selectedIds.isEmpty) return;
    final ordered = blocks;
    final moving = ordered
        .where((block) => selectedIds.contains(block.id))
        .toList();
    if (moving.length != selectedIds.length ||
        moving.any((block) => !block.supports(BlockCapability.movable))) {
      return;
    }
    final next = ordered
        .where((block) => !selectedIds.contains(block.id))
        .toList();
    var insertionIndex = targetBlockId == null
        ? next.length
        : next.indexWhere((block) => block.id == targetBlockId);
    if (insertionIndex < 0) insertionIndex = next.length;
    if (insertAfter && insertionIndex < next.length) insertionIndex++;
    insertionIndex = insertionIndex.clamp(0, next.length);
    next.insertAll(insertionIndex, moving);
    if (listEquals(
      ordered.map((block) => block.id).toList(),
      next.map((block) => block.id).toList(),
    )) {
      return;
    }
    final now = DateTime.now().toUtc();
    _commit(
      _replaceBlocks(_normalizeOrder(next, now), now: now),
      kind: 'moveMultipleBlocks',
      blockId: moving.first.id,
      refreshPresentation: true,
    );
  }

  void deleteBlocks(Iterable<String> blockIds) {
    final ids = blockIds.toSet();
    if (ids.isEmpty) return;
    final selected = blocks.where((block) => ids.contains(block.id)).toList();
    if (selected.length != ids.length ||
        selected.any((block) => !block.supports(BlockCapability.deletable))) {
      return;
    }
    final now = DateTime.now().toUtc();
    final next = blocks.where((block) => !ids.contains(block.id)).toList();
    if (next.isEmpty) next.add(_emptyTextBlock(orderKey: 0, now: now));
    _commit(
      _replaceBlocks(_normalizeOrder(next, now), now: now),
      kind: 'deleteMultipleBlocks',
      blockId: selected.first.id,
      refreshPresentation: true,
    );
  }

  void resizeBlock(String blockId, SpatialRect workspaceBounds) {
    final block = blockById(blockId);
    if (block == null ||
        block.isLocked ||
        !block.supports(BlockCapability.resizable)) {
      return;
    }
    final nextGeometry = block.geometry.copyWith(
      width: workspaceBounds.width,
      height: workspaceBounds.height,
    );
    updateBlock(
      block.copyWithCommon(geometry: nextGeometry),
      kind: 'resizeBlock',
      refreshPresentation: true,
    );
  }

  void alignBlocks(
    Iterable<String> blockIds,
    Map<String, SpatialRect> workspaceBounds,
    BlockAlignmentAxis alignment,
  ) {
    final ids = blockIds.toSet();
    final selected = blocks.where((block) => ids.contains(block.id)).toList();
    if (selected.length < 2 ||
        selected.any((block) => !workspaceBounds.containsKey(block.id)) ||
        selected.any(
          (block) => block.isLocked || !block.supports(BlockCapability.movable),
        )) {
      return;
    }
    final deltas = const TransformationEngine().align({
      for (final block in selected) block.id: workspaceBounds[block.id]!,
    }, alignment);
    _transformBlocks(
      selected,
      deltas,
      kind: 'alignBlocks',
      alignment: alignment,
    );
  }

  void distributeBlocksVertically(
    Iterable<String> blockIds,
    Map<String, SpatialRect> workspaceBounds,
  ) {
    final ids = blockIds.toSet();
    final selected = blocks.where((block) => ids.contains(block.id)).toList();
    if (selected.length < 3 ||
        selected.any((block) => !workspaceBounds.containsKey(block.id)) ||
        selected.any(
          (block) => block.isLocked || !block.supports(BlockCapability.movable),
        )) {
      return;
    }
    final deltas = const TransformationEngine().distributeVertically(
      blocks.map((block) => block.id).toList(),
      {for (final block in selected) block.id: workspaceBounds[block.id]!},
    );
    _transformBlocks(selected, deltas, kind: 'distributeBlocks');
  }

  void _transformBlocks(
    List<BaseBlock> selected,
    Map<String, SpatialPoint> deltas, {
    required String kind,
    BlockAlignmentAxis? alignment,
  }) {
    if (deltas.isEmpty) return;
    final selectedIds = selected.map((block) => block.id).toSet();
    final now = DateTime.now().toUtc();
    var changed = false;
    final next = <BaseBlock>[];
    for (final block in blocks) {
      final delta = deltas[block.id];
      if (!selectedIds.contains(block.id) || delta == null) {
        next.add(block);
        continue;
      }
      var transformed = block.copyWithCommon(
        geometry: block.geometry.copyWith(
          x: block.geometry.x + delta.x,
          y: block.geometry.y + delta.y,
        ),
        updatedAt: now,
        version: block.version + 1,
      );
      if (transformed is ImageBlock && alignment != null) {
        final imageAlignment = switch (alignment) {
          BlockAlignmentAxis.left => BlockAlignment.left,
          BlockAlignmentAxis.horizontalCenter => BlockAlignment.center,
          BlockAlignmentAxis.right => BlockAlignment.right,
          _ => transformed.alignment,
        };
        transformed = transformed.copyWith(alignment: imageAlignment);
      }
      changed = changed || !mapEquals(block.toJson(), transformed.toJson());
      next.add(transformed);
    }
    if (!changed) return;
    _commit(
      _replaceBlocks(next, now: now),
      kind: kind,
      blockId: selected.first.id,
      refreshPresentation: true,
    );
  }

  bool canMergeTextWithNext(String blockId) {
    final ordered = blocks;
    final index = ordered.indexWhere((block) => block.id == blockId);
    return index >= 0 &&
        index < ordered.length - 1 &&
        ordered[index] is TextBlock &&
        ordered[index + 1] is TextBlock;
  }

  void mergeTextWithNext(String blockId) {
    if (!canMergeTextWithNext(blockId)) return;
    final ordered = blocks;
    final index = ordered.indexWhere((block) => block.id == blockId);
    final first = ordered[index] as TextBlock;
    final second = ordered[index + 1] as TextBlock;
    final merged = first.copyWith(
      paragraphs: [...first.paragraphs, ...second.paragraphs],
    );
    final now = DateTime.now().toUtc();
    final next = [...ordered]..replaceRange(index, index + 2, [merged]);
    _commit(
      _replaceBlocks(_normalizeOrder(next, now), now: now),
      kind: 'mergeTextBlock',
      blockId: merged.id,
      refreshPresentation: true,
    );
  }

  void applyTextFormat(
    Uuid blockId,
    BlockTextSelection selection,
    String attribute,
    Object? value,
  ) {
    final selected = blockById(blockId);
    if (selected is! TextBlock || selected.isLocked) return;
    if (selection.baseOffset == selection.extentOffset) {
      return;
    }
    final document = StructuredDocument(
      nodes: selected.paragraphs
          .map((paragraph) => paragraph.toLegacy())
          .toList(),
    );
    final anchor = _documentPosition(document, selection.baseOffset);
    final focus = _documentPosition(document, selection.extentOffset);
    final formatted = document.applyFormat(
      DocumentSelection(anchor: anchor, focus: focus),
      attribute,
      value,
    );
    updateBlock(
      selected.copyWith(
        paragraphs: formatted.nodes
            .whereType<ParagraphNode>()
            .map(BlockParagraph.fromLegacy)
            .toList(),
        selection: selection,
      ),
      kind: 'formatText',
      refreshPresentation: true,
    );
  }

  bool textFormatActive(
    Uuid blockId,
    BlockTextSelection selection,
    String attribute,
    Object? value,
  ) {
    final selected = blockById(blockId);
    if (selected is! TextBlock) return false;
    if (selection.baseOffset == selection.extentOffset) {
      return false;
    }
    final document = StructuredDocument(
      nodes: selected.paragraphs
          .map((paragraph) => paragraph.toLegacy())
          .toList(),
    );
    return document.formatActive(
      DocumentSelection(
        anchor: _documentPosition(document, selection.baseOffset),
        focus: _documentPosition(document, selection.extentOffset),
      ),
      attribute,
      value,
    );
  }

  String currentParagraphAlignmentFor(
    Uuid blockId,
    BlockTextSelection selection,
  ) {
    final selected = blockById(blockId);
    if (selected is! TextBlock || selected.paragraphs.isEmpty) return 'left';
    var consumed = 0;
    for (final paragraph in selected.paragraphs) {
      if (selection.baseOffset <= consumed + paragraph.text.length) {
        return paragraph.attributes.alignment;
      }
      consumed += paragraph.text.length + 1;
    }
    return selected.paragraphs.last.attributes.alignment;
  }

  void applyParagraphAlignment(
    Uuid blockId,
    BlockTextSelection selection,
    String alignment,
  ) {
    final selected = blockById(blockId);
    if (selected is! TextBlock || selected.isLocked) return;
    final document = StructuredDocument(
      nodes: selected.paragraphs
          .map((paragraph) => paragraph.toLegacy())
          .toList(),
    );
    final updated = document.setParagraphAttribute(
      DocumentSelection(
        anchor: _documentPosition(document, selection.baseOffset),
        focus: _documentPosition(document, selection.extentOffset),
      ),
      'alignment',
      alignment,
    );
    updateBlock(
      selected.copyWith(
        paragraphs: updated.nodes
            .whereType<ParagraphNode>()
            .map(BlockParagraph.fromLegacy)
            .toList(),
        selection: selection,
      ),
      kind: 'alignText',
      refreshPresentation: true,
    );
  }

  void undo() {
    if (!canUndo) return;
    final edit = _undoStack.removeLast();
    _workspace = edit.before;
    _redoStack.add(edit);
    onChanged(_workspace);
    notifyListeners();
    _refreshPresentation();
  }

  void redo() {
    if (!canRedo) return;
    final edit = _redoStack.removeLast();
    _workspace = edit.after;
    _undoStack.add(edit);
    onChanged(_workspace);
    notifyListeners();
    _refreshPresentation();
  }

  void _commit(
    Workspace next, {
    required String kind,
    required String blockId,
    bool mergeable = false,
    bool refreshPresentation = false,
  }) {
    final now = DateTime.now();
    final edit = _WorkspaceEdit(
      before: _workspace,
      after: next,
      kind: kind,
      blockId: blockId,
      timestamp: now,
      mergeable: mergeable,
    );
    if (_undoStack.isNotEmpty && _undoStack.last.canMerge(edit)) {
      _undoStack[_undoStack.length - 1] = _undoStack.last.merge(edit);
    } else {
      _undoStack.add(edit);
      while (_undoStack.length > maxOperations) {
        _undoStack.removeAt(0);
      }
    }
    _workspace = next;
    _redoStack.clear();
    onChanged(_workspace);
    notifyListeners();
    if (refreshPresentation) _refreshPresentation();
  }

  Workspace _replaceBlocks(List<BaseBlock> blocks, {required DateTime now}) {
    final currentPage = page;
    final nextPage = currentPage.copyWith(
      blocks: blocks,
      updatedAt: now,
      version: currentPage.version + 1,
    );
    final pages = [..._workspace.pages];
    final index = pages.indexWhere((page) => page.id == currentPage.id);
    if (index < 0) {
      pages.add(nextPage);
    } else {
      pages[index] = nextPage;
    }
    return _workspace.copyWith(
      pages: pages,
      updatedAt: now,
      version: _workspace.version + 1,
    );
  }

  List<BaseBlock> _normalizeOrder(List<BaseBlock> input, DateTime now) => [
    for (var index = 0; index < input.length; index++)
      input[index].copyWithCommon(
        orderKey: index.toDouble(),
        updatedAt: input[index].orderKey == index.toDouble()
            ? input[index].updatedAt
            : now,
      ),
  ];

  ({TextBlock left, TextBlock right}) _splitTextBlock(
    TextBlock block,
    int globalOffset,
  ) {
    final safe = globalOffset.clamp(0, block.plainText.length);
    var consumed = 0;
    var paragraphIndex = block.paragraphs.length - 1;
    var localOffset = block.paragraphs.last.text.length;
    for (var index = 0; index < block.paragraphs.length; index++) {
      final paragraph = block.paragraphs[index];
      final end = consumed + paragraph.text.length;
      if (safe <= end) {
        paragraphIndex = index;
        localOffset = safe - consumed;
        break;
      }
      consumed = end + 1;
    }
    final paragraph = block.paragraphs[paragraphIndex];
    final leftParagraph = BlockParagraph(
      id: paragraph.id,
      text: paragraph.text.substring(0, localOffset),
      attributes: paragraph.attributes,
      spans: _leftSpans(paragraph.spans, localOffset),
      metadata: paragraph.metadata,
    );
    final rightParagraph = BlockParagraph(
      id: generateUuid(),
      text: paragraph.text.substring(localOffset),
      attributes: paragraph.attributes,
      spans: _rightSpans(paragraph.spans, localOffset),
      metadata: paragraph.metadata,
    );
    final left = block.copyWith(
      paragraphs: [...block.paragraphs.take(paragraphIndex), leftParagraph],
      selection: BlockTextSelection(baseOffset: safe, extentOffset: safe),
    );
    final right = TextBlock(
      id: generateUuid(),
      orderKey: block.orderKey + 1,
      paragraphs: [
        rightParagraph,
        ...block.paragraphs.skip(paragraphIndex + 1),
      ],
      selection: const BlockTextSelection(baseOffset: 0, extentOffset: 0),
      geometry: block.geometry,
      capabilities: block.capabilities,
      isVisible: block.isVisible,
      isLocked: block.isLocked,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      metadata: block.metadata,
    );
    return (left: left, right: right);
  }

  List<TextSpanMark> _leftSpans(List<TextSpanMark> spans, int offset) => spans
      .where((span) => span.start < offset)
      .map((span) => span.copyWith(end: math.min(span.end, offset)))
      .where((span) => span.start < span.end)
      .toList();

  List<TextSpanMark> _rightSpans(List<TextSpanMark> spans, int offset) => spans
      .where((span) => span.end > offset)
      .map(
        (span) => span.copyWith(
          start: math.max(span.start, offset) - offset,
          end: span.end - offset,
        ),
      )
      .where((span) => span.start < span.end)
      .toList();

  DocumentPosition _documentPosition(
    StructuredDocument document,
    int globalOffset,
  ) {
    var consumed = 0;
    final paragraphs = document.nodes.whereType<ParagraphNode>().toList();
    for (final paragraph in paragraphs) {
      final end = consumed + paragraph.text.length;
      if (globalOffset <= end) {
        return DocumentPosition(
          nodeId: paragraph.id,
          offset: (globalOffset - consumed).clamp(0, paragraph.text.length),
        );
      }
      consumed = end + 1;
    }
    final last = paragraphs.last;
    return DocumentPosition(nodeId: last.id, offset: last.text.length);
  }

  TextBlock _emptyTextBlock({
    required double orderKey,
    required DateTime now,
  }) => TextBlock(
    id: generateUuid(),
    orderKey: orderKey,
    paragraphs: [BlockParagraph(id: generateUuid(), text: '')],
    createdAt: now,
    updatedAt: now,
  );

  Object? _replaceIds(Object? value) {
    if (value is List) return value.map(_replaceIds).toList();
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): entry.key == 'id'
              ? generateUuid()
              : _replaceIds(entry.value),
      };
    }
    return value;
  }

  void _refreshPresentation() {
    presentationRevision.value++;
  }

  @override
  void dispose() {
    presentationRevision.dispose();
    super.dispose();
  }
}

class _WorkspaceEdit {
  const _WorkspaceEdit({
    required this.before,
    required this.after,
    required this.kind,
    required this.blockId,
    required this.timestamp,
    required this.mergeable,
  });

  final Workspace before;
  final Workspace after;
  final String kind;
  final String blockId;
  final DateTime timestamp;
  final bool mergeable;

  bool canMerge(_WorkspaceEdit other) =>
      mergeable &&
      other.mergeable &&
      kind == other.kind &&
      blockId == other.blockId &&
      other.timestamp.difference(timestamp).inMilliseconds <= 900;

  _WorkspaceEdit merge(_WorkspaceEdit other) => _WorkspaceEdit(
    before: before,
    after: other.after,
    kind: kind,
    blockId: blockId,
    timestamp: other.timestamp,
    mergeable: true,
  );
}
