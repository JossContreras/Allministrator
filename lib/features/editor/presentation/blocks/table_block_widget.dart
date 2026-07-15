import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/app/theme/app_motion.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_frame.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:flutter/material.dart';

class TableBlockWidget extends StatefulWidget {
  const TableBlockWidget({required this.renderContext, super.key});

  final BlockRenderContext renderContext;

  @override
  State<TableBlockWidget> createState() => _TableBlockWidgetState();
}

class _TableBlockWidgetState extends State<TableBlockWidget> {
  final Map<String, FocusNode> _focusNodes = {};
  String? _selectedCellId;
  late TableBlock _current;

  @override
  void initState() {
    super.initState();
    _current = widget.renderContext.block as TableBlock;
    _syncFocusNodes();
  }

  @override
  void didUpdateWidget(covariant TableBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.renderContext.block as TableBlock;
    if (incoming.version != _current.version ||
        incoming.rows.length != _current.rows.length ||
        incoming.columnCount != _current.columnCount) {
      _current = incoming;
    }
    _syncFocusNodes();
  }

  void _syncFocusNodes() {
    final ids = _current.rows
        .expand((row) => row.cells)
        .map((cell) => cell.id)
        .toSet();
    for (final id in ids) {
      _focusNodes.putIfAbsent(id, () {
        final targetId = _focusTargetId(id);
        final node = FocusNode(debugLabel: targetId);
        node.addListener(() {
          widget.renderContext.interaction.focusCoordinator.reportFocusChange(
            targetId,
            hasFocus: node.hasFocus,
          );
        });
        widget.renderContext.interaction.focusCoordinator.registerTarget(
          targetId: targetId,
          blockId: _current.id,
          requestFocus: node.requestFocus,
          releaseFocus: node.unfocus,
        );
        return node;
      });
    }
    for (final id
        in _focusNodes.keys.where((id) => !ids.contains(id)).toList()) {
      widget.renderContext.interaction.focusCoordinator.unregisterTarget(
        _focusTargetId(id),
      );
      _focusNodes.remove(id)?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => BlockFrame(
    block: _current,
    geometryRegistry: widget.renderContext.geometryRegistry,
    workspaceId: widget.renderContext.session.workspace.id,
    pageId: widget.renderContext.session.page.id,
    visualLayer: widget.renderContext.visualLayer,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.sizeOf(context).width - 76,
            ),
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(flex: 1),
              border: TableBorder.all(color: Theme.of(context).dividerColor),
              children: [
                for (
                  var rowIndex = 0;
                  rowIndex < _current.rows.length;
                  rowIndex++
                )
                  TableRow(
                    decoration: _current.hasHeaderRow && rowIndex == 0
                        ? BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          )
                        : null,
                    children: [
                      for (
                        var columnIndex = 0;
                        columnIndex < _current.rows[rowIndex].cells.length;
                        columnIndex++
                      )
                        _cell(context, rowIndex, columnIndex),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _cell(BuildContext context, int rowIndex, int columnIndex) {
    final cell = _current.rows[rowIndex].cells[columnIndex];
    final selected = _selectedCellId == cell.id;
    return widget.renderContext.region(
      id: 'cell-${cell.id}',
      target: TableCellHitTarget(
        _current.id,
        cellId: cell.id,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
      ),
      priority: 25,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        color: selected
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: TextFormField(
          key: ValueKey(cell.id),
          initialValue: cell.text,
          focusNode: _focusNodes[cell.id],
          readOnly: widget.renderContext.readOnly || _current.isLocked,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          onTap: () {
            widget.renderContext.interaction.dispatch(
              StartEditingIntent(
                blockId: _current.id,
                focusTargetId: _focusTargetId(cell.id),
                selectBlock: false,
              ),
            );
            setState(() => _selectedCellId = cell.id);
          },
          onChanged: (text) => _updateCell(rowIndex, columnIndex, text),
          onFieldSubmitted: (_) => _focusNext(rowIndex, columnIndex),
        ),
      ),
    );
  }

  void _updateCell(int rowIndex, int columnIndex, String text) {
    final rows = [..._current.rows];
    final row = rows[rowIndex];
    final cells = [...row.cells];
    cells[columnIndex] = cells[columnIndex].copyWith(text: text);
    rows[rowIndex] = row.copyWith(cells: cells);
    _emit(
      _current.copyWith(rows: rows),
      kind: 'editTableCell',
      mergeable: true,
    );
  }

  void _focusNext(int rowIndex, int columnIndex) {
    var nextRow = rowIndex;
    var nextColumn = columnIndex + 1;
    if (nextColumn >= _current.columnCount) {
      nextColumn = 0;
      nextRow++;
    }
    if (nextRow >= _current.rows.length) return;
    final cell = _current.rows[nextRow].cells[nextColumn];
    widget.renderContext.interaction.dispatch(
      StartEditingIntent(
        blockId: _current.id,
        focusTargetId: _focusTargetId(cell.id),
        selectBlock: false,
      ),
    );
    setState(() => _selectedCellId = cell.id);
  }

  String _focusTargetId(String cellId) => 'table-${_current.id}-$cellId';

  void _emit(
    TableBlock next, {
    required String kind,
    bool mergeable = false,
    bool refresh = false,
  }) {
    _current = next;
    _syncFocusNodes();
    widget.renderContext.onChanged(
      next,
      kind: kind,
      mergeable: mergeable,
      refreshPresentation: refresh,
    );
    if (mounted && refresh) setState(() {});
  }

  @override
  void dispose() {
    for (final id in _focusNodes.keys) {
      widget.renderContext.interaction.focusCoordinator.unregisterTarget(
        _focusTargetId(id),
      );
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }
}
