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
    session: renderContext.session,
    readOnly: renderContext.readOnly,
    onTap: () => renderContext.session.selectBlock(block.id),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          block.style == DividerStyle.solid
              ? Divider(thickness: block.thickness)
              : _DashedDivider(thickness: block.thickness),
          if (renderContext.isSelected && !renderContext.readOnly)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                DropdownButton<DividerStyle>(
                  value: block.style,
                  items: const [
                    DropdownMenuItem(
                      value: DividerStyle.solid,
                      child: Text('Sólido'),
                    ),
                    DropdownMenuItem(
                      value: DividerStyle.dashed,
                      child: Text('Discontinuo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      renderContext.onChanged(
                        block.copyWith(style: value),
                        kind: 'updateDivider',
                        refreshPresentation: true,
                      );
                    }
                  },
                ),
                DropdownButton<double>(
                  value: block.thickness.clamp(1, 3),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 px')),
                    DropdownMenuItem(value: 2, child: Text('2 px')),
                    DropdownMenuItem(value: 3, child: Text('3 px')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      renderContext.onChanged(
                        block.copyWith(thickness: value),
                        kind: 'updateDivider',
                        refreshPresentation: true,
                      );
                    }
                  },
                ),
              ],
            ),
        ],
      ),
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
