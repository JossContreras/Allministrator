import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/interaction/geometry_reporting.dart';
import 'package:flutter/material.dart';

class BlockFrame extends StatelessWidget {
  const BlockFrame({
    required this.block,
    required this.geometryRegistry,
    required this.workspaceId,
    required this.pageId,
    required this.visualLayer,
    required this.child,
    this.compact = false,
    super.key,
  });

  final BaseBlock block;
  final BlockGeometryRegistry geometryRegistry;
  final String workspaceId;
  final String pageId;
  final int visualLayer;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Bloque ${_label(block.type)}',
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 5),
      child: BlockGeometryReporter(
        registry: geometryRegistry,
        blockId: block.id,
        workspaceId: workspaceId,
        pageId: pageId,
        layer: visualLayer,
        child: InteractionRegionReporter(
          registry: geometryRegistry,
          blockId: block.id,
          regionId: 'block-background',
          target: BlockBackgroundHitTarget(block.id),
          child: InteractionRegionReporter(
            registry: geometryRegistry,
            blockId: block.id,
            regionId: 'block-content',
            target: BlockContentHitTarget(block.id),
            priority: 10,
            child: child,
          ),
        ),
      ),
    ),
  );

  String _label(BlockType type) => switch (type) {
    BlockType.text => 'Texto',
    BlockType.image => 'Imagen',
    BlockType.divider => 'Separador',
    BlockType.checklist => 'Checklist',
    BlockType.code => 'Código',
    BlockType.table => 'Tabla',
    BlockType.attachment => 'Archivo',
    BlockType.quote => 'Cita',
    BlockType.callout => 'Callout',
    BlockType.unknown => 'No compatible',
  };
}
