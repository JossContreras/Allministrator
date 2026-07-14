import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_frame.dart';
import 'package:allministrator/features/editor/presentation/blocks/block_render_context.dart';
import 'package:flutter/material.dart';

class DividerBlockWidget extends StatelessWidget {
  const DividerBlockWidget({required this.renderContext, super.key});

  final BlockRenderContext renderContext;

  DividerBlock get block => renderContext.block as DividerBlock;

  @override
  Widget build(BuildContext context) => BlockFrame(
    block: block,
    geometryRegistry: renderContext.geometryRegistry,
    workspaceId: renderContext.session.workspace.id,
    pageId: renderContext.session.page.id,
    visualLayer: renderContext.visualLayer,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: block.style == DividerStyle.solid
          ? Divider(thickness: block.thickness)
          : _DashedDivider(thickness: block.thickness),
    ),
  );
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.thickness});

  final double thickness;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const dash = 8.0;
      const gap = 6.0;
      final count = (constraints.maxWidth / (dash + gap)).floor().clamp(1, 200);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var index = 0; index < count; index++)
            SizedBox(
              width: dash,
              height: thickness,
              child: ColoredBox(color: Theme.of(context).dividerColor),
            ),
        ],
      );
    },
  );
}
