import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
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
      _focusNodes.putIfAbsent(
        id,
        () => FocusNode(debugLabel: 'table-cell-$id'),
      );
    }
    for (final id
        in _focusNodes.keys.where((id) => !ids.contains(id)).toList()) {
      _focusNodes.remove(id)?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => BlockFrame(
    block: _current,
    session: widget.renderContext.session,
    readOnly: widget.renderContext.readOnly,
    onTap: () => widget.renderContext.session.selectBlock(_current.id),
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
        if (widget.renderContext.isSelected && !widget.renderContext.readOnly)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: _current.rows.length >= 8 ? null : _addRow,
                icon: const Icon(Icons.table_rows_outlined),
                label: const Text('Fila'),
              ),
              TextButton.icon(
                onPressed: _current.rows.length <= 1 ? null : _removeRow,
                icon: const Icon(Icons.remove),
                label: const Text('Quitar fila'),
              ),
              TextButton.icon(
                onPressed: _current.columnCount >= 8 ? null : _addColumn,
                icon: const Icon(Icons.view_column_outlined),
                label: const Text('Columna'),
              ),
              TextButton.icon(
                onPressed: _current.columnCount <= 1 ? null : _removeColumn,
                icon: const Icon(Icons.remove),
                label: const Text('Quitar columna'),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _cell(BuildContext context, int rowIndex, int columnIndex) {
    final cell = _current.rows[rowIndex].cells[columnIndex];
    final selected = _selectedCellId == cell.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
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
          widget.renderContext.session.beginEditing(_current.id);
          setState(() => _selectedCellId = cell.id);
        },
        onChanged: (text) => _updateCell(rowIndex, columnIndex, text),
        onFieldSubmitted: (_) => _focusNext(rowIndex, columnIndex),
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

  void _addRow() {
    final row = BlockTableRow(
      id: generateUuid(),
      cells: List.generate(
        _current.columnCount,
        (_) => BlockTableCell(id: generateUuid()),
      ),
    );
    _emit(
      _current.copyWith(rows: [..._current.rows, row]),
      kind: 'addTableRow',
      refresh: true,
    );
  }

  void _removeRow() {
    if (_current.rows.length <= 1) return;
    var index = _selectedRowIndex();
    if (index < 0) index = _current.rows.length - 1;
    final rows = [..._current.rows]..removeAt(index);
    _selectedCellId = null;
    _emit(_current.copyWith(rows: rows), kind: 'removeTableRow', refresh: true);
  }

  void _addColumn() {
    final rows = [
      for (final row in _current.rows)
        row.copyWith(
          cells: [
            ...row.cells,
            BlockTableCell(id: generateUuid()),
          ],
        ),
    ];
    _emit(
      _current.copyWith(
        rows: rows,
        columnIds: [..._current.columnIds, generateUuid()],
      ),
      kind: 'addTableColumn',
      refresh: true,
    );
  }

  void _removeColumn() {
    if (_current.columnCount <= 1) return;
    var index = _selectedColumnIndex();
    if (index < 0) index = _current.columnCount - 1;
    final rows = [
      for (final row in _current.rows)
        row.copyWith(cells: [...row.cells]..removeAt(index)),
    ];
    final columns = [..._current.columnIds]..removeAt(index);
    _selectedCellId = null;
    _emit(
      _current.copyWith(rows: rows, columnIds: columns),
      kind: 'removeTableColumn',
      refresh: true,
    );
  }

  int _selectedRowIndex() => _current.rows.indexWhere(
    (row) => row.cells.any((cell) => cell.id == _selectedCellId),
  );

  int _selectedColumnIndex() {
    for (final row in _current.rows) {
      final index = row.cells.indexWhere((cell) => cell.id == _selectedCellId);
      if (index >= 0) return index;
    }
    return -1;
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
    _focusNodes[cell.id]?.requestFocus();
    setState(() => _selectedCellId = cell.id);
  }

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
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }
}
