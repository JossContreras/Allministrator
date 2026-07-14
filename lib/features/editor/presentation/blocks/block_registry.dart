import 'package:allministrator/core/shared/identifiers.dart';
import 'package:allministrator/core/utils/uuid_generator.dart';
import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/blocks/attachment_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:allministrator/features/editor/presentation/blocks/checklist_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/code_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/divider_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/image_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/quote_callout_block_widgets.dart';
import 'package:allministrator/features/editor/presentation/blocks/table_block_widget.dart';
import 'package:allministrator/features/editor/presentation/blocks/text_block_widget.dart';
import 'package:flutter/widgets.dart';

class BlockDefinition {
  const BlockDefinition({
    required this.type,
    required this.serializer,
    required this.deserializer,
    required this.editableRenderer,
    required this.readOnlyRenderer,
    required this.toolbarProvider,
    required this.commandHandler,
    required this.selectionHandler,
    required this.validationHandler,
    required this.insertionFactory,
  });

  final BlockType type;
  final JsonMap Function(BaseBlock block) serializer;
  final BaseBlock Function(JsonMap json) deserializer;
  final EditableBlockRenderer editableRenderer;
  final ReadOnlyBlockRenderer readOnlyRenderer;
  final BlockToolbarProvider toolbarProvider;
  final BlockCommandHandler commandHandler;
  final BlockSelectionHandler selectionHandler;
  final BlockValidationHandler validationHandler;
  final BlockInsertionFactory insertionFactory;
}

class BlockRegistry {
  BlockRegistry(Iterable<BlockDefinition> definitions)
    : _definitions = {
        for (final definition in definitions) definition.type: definition,
      };

  final Map<BlockType, BlockDefinition> _definitions;

  factory BlockRegistry.standard() => BlockRegistry([
    _definition(
      BlockType.text,
      (context) => TextBlockWidget(renderContext: context),
      (orderKey) => TextBlock(
        id: generateUuid(),
        orderKey: orderKey,
        paragraphs: [BlockParagraph(id: generateUuid(), text: '')],
      ),
    ),
    _definition(
      BlockType.image,
      (context) => ImageBlockWidget(renderContext: context),
      (orderKey) =>
          ImageBlock(id: generateUuid(), orderKey: orderKey, attachmentId: ''),
    ),
    _definition(
      BlockType.divider,
      (context) => DividerBlockWidget(renderContext: context),
      (orderKey) => DividerBlock(id: generateUuid(), orderKey: orderKey),
    ),
    _definition(
      BlockType.checklist,
      (context) => ChecklistBlockWidget(renderContext: context),
      (orderKey) => ChecklistBlock(
        id: generateUuid(),
        orderKey: orderKey,
        items: [BlockChecklistItem(id: generateUuid(), text: '')],
      ),
    ),
    _definition(
      BlockType.code,
      (context) => CodeBlockWidget(renderContext: context),
      (orderKey) => CodeBlock(id: generateUuid(), orderKey: orderKey),
    ),
    _definition(
      BlockType.table,
      (context) => TableBlockWidget(renderContext: context),
      _tableFactory,
    ),
    _definition(
      BlockType.attachment,
      (context) => AttachmentBlockWidget(renderContext: context),
      (orderKey) => AttachmentBlock(
        id: generateUuid(),
        orderKey: orderKey,
        attachmentId: '',
        displayName: 'Archivo adjunto',
      ),
    ),
    _definition(
      BlockType.quote,
      (context) => QuoteBlockWidget(renderContext: context),
      (orderKey) => QuoteBlock(id: generateUuid(), orderKey: orderKey),
    ),
    _definition(
      BlockType.callout,
      (context) => CalloutBlockWidget(renderContext: context),
      (orderKey) => CalloutBlock(id: generateUuid(), orderKey: orderKey),
    ),
    _definition(
      BlockType.unknown,
      (context) => UnknownBlockWidget(renderContext: context),
      (orderKey) => UnknownBlock(
        id: generateUuid(),
        orderKey: orderKey,
        originalType: 'unknown',
        raw: const {},
      ),
    ),
  ]);

  void register(BlockDefinition definition) {
    _definitions[definition.type] = definition;
    BlockCodec.register(definition.type.name, definition.deserializer);
  }

  BlockDefinition definitionFor(BlockType type) =>
      _definitions[type] ?? _definitions[BlockType.unknown]!;

  Widget renderEditable(BlockRenderContext context) {
    final definition = definitionFor(context.block.type);
    return definition.editableRenderer(context);
  }

  Widget renderReadOnly(BlockRenderContext context) {
    final definition = definitionFor(context.block.type);
    return definition.readOnlyRenderer(context.copyWith(readOnly: true));
  }

  BaseBlock create(BlockType type, {double orderKey = 0}) =>
      definitionFor(type).insertionFactory(orderKey);

  String? validate(BaseBlock block) =>
      definitionFor(block.type).validationHandler(block);
}

BlockDefinition _definition(
  BlockType type,
  EditableBlockRenderer renderer,
  BlockInsertionFactory factory,
) => BlockDefinition(
  type: type,
  serializer: BlockCodec.toJson,
  deserializer: BlockCodec.fromJson,
  editableRenderer: renderer,
  readOnlyRenderer: renderer,
  toolbarProvider: (block) => block.capabilities.toList(growable: false),
  commandHandler: _handleCommand,
  selectionHandler: (context) =>
      context.interaction.dispatch(SelectBlockIntent(context.block.id)),
  validationHandler: (block) {
    if (block.id.trim().isEmpty) {
      return 'El bloque no tiene UUID.';
    }
    if (block.type != type) {
      return 'El tipo registrado no coincide con el bloque.';
    }
    return null;
  },
  insertionFactory: factory,
);

void _handleCommand(BlockRenderContext context, String command) {
  final block = context.block;
  if (command == 'moveUp' && block.supports(BlockCapability.movable)) {
    context.session.moveBlock(block.id, -1);
  } else if (command == 'moveDown' && block.supports(BlockCapability.movable)) {
    context.session.moveBlock(block.id, 1);
  } else if (command == 'duplicate' &&
      block.supports(BlockCapability.duplicable)) {
    context.session.duplicateBlock(block.id);
  } else if (command == 'delete' && block.supports(BlockCapability.deletable)) {
    context.interaction.dispatch(
      const CancelInteractionIntent(
        reason: InteractionCancellationReason.blockDeleted,
      ),
    );
    context.session.deleteBlock(block.id);
  } else if (command == 'select' &&
      block.supports(BlockCapability.selectable)) {
    context.interaction.dispatch(SelectBlockIntent(block.id));
  }
}

TableBlock _tableFactory(double orderKey) {
  final columns = List<Uuid>.generate(2, (_) => generateUuid());
  return TableBlock(
    id: generateUuid(),
    orderKey: orderKey,
    columnIds: columns,
    rows: List.generate(
      2,
      (_) => BlockTableRow(
        id: generateUuid(),
        cells: List.generate(
          columns.length,
          (_) => BlockTableCell(id: generateUuid()),
        ),
      ),
    ),
  );
}
