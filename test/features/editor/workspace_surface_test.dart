import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/features/editor/presentation/interaction/geometry_reporting.dart';
import 'package:allministrator/features/editor/presentation/interaction/workspace_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('surface scales geometry and exposes reusable resize handles', (
    tester,
  ) async {
    final registry = BlockGeometryRegistry();
    final interaction = WorkspaceInteractionController()
      ..dispatch(const SelectBlockIntent('block'));
    final scrollController = ScrollController();
    final viewportController = WorkspaceViewportController();
    addTearDown(registry.dispose);
    addTearDown(interaction.dispose);
    addTearDown(scrollController.dispose);
    addTearDown(viewportController.dispose);

    await tester.pumpWidget(
      _surface(
        registry: registry,
        interaction: interaction,
        scrollController: scrollController,
        viewportController: viewportController,
        resizable: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    final height = registry.geometryFor('block')!.globalBounds.height;
    final viewportDimension = scrollController.position.viewportDimension;
    expect(find.byKey(const ValueKey('resize-block-east')), findsOneWidget);
    expect(find.byKey(const ValueKey('resize-block-south')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('resize-block-southEast')),
      findsOneWidget,
    );

    viewportController.setZoom(1.5, focalPoint: const SpatialPoint(0, 0));
    await tester.pump();
    await tester.pump();
    expect(
      registry.geometryFor('block')!.globalBounds.height,
      closeTo(height * 1.5, .1),
    );
    expect(
      scrollController.position.viewportDimension,
      closeTo(viewportDimension / 1.5, .1),
    );
  });

  testWidgets('surface registers layout and aligns selection handle overlay', (
    tester,
  ) async {
    final registry = BlockGeometryRegistry();
    final interaction = WorkspaceInteractionController();
    final scrollController = ScrollController();
    addTearDown(registry.dispose);
    addTearDown(interaction.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      _surface(
        registry: registry,
        interaction: interaction,
        scrollController: scrollController,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final entry = registry.geometryFor('block');
    expect(entry, isNotNull);
    expect(entry!.globalBounds.width, greaterThan(100));
    expect(entry.visibleBounds.isEmpty, isFalse);
    expect(entry.regions['text']?.target, isA<TextRegionHitTarget>());
    expect(find.byType(ContentLayer), findsOneWidget);
    expect(find.byType(DecorationLayer), findsOneWidget);
    expect(find.byType(InteractionLayer), findsOneWidget);
    expect(find.byType(OverlayLayer), findsOneWidget);
    expect(find.byType(ModalLayer), findsOneWidget);

    final handle = find.byKey(const ValueKey('block-handle-block'));
    expect(handle, findsOneWidget);
    final handleRect = tester.getRect(handle);
    final expected = WorkspaceOverlayGeometry.handleBounds(entry);
    expect(handleRect.left, closeTo(expected.left, 0.01));
    expect(handleRect.top, closeTo(expected.top, 0.01));

    await tester.tap(handle);
    await tester.pump();
    expect(interaction.context.selectedBlock, 'block');
    expect(interaction.context.interactionMode, InteractionMode.blockSelected);
    final hit = registry.hitTest(
      SpatialPoint(handleRect.center.dx, handleRect.center.dy),
    );
    expect(hit.target, isA<BlockHandleHitTarget>());
  });

  testWidgets('surface updates geometry on scroll, keyboard and rotation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final registry = BlockGeometryRegistry();
    final interaction = WorkspaceInteractionController();
    final scrollController = ScrollController();
    addTearDown(registry.dispose);
    addTearDown(interaction.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      _surface(
        registry: registry,
        interaction: interaction,
        scrollController: scrollController,
        topSpacer: 500,
        keyboardInset: 120,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    final before = registry.geometryFor('block')!.globalBounds.top;
    expect(registry.viewport!.keyboardInset, 120);

    scrollController.jumpTo(300);
    await tester.pump();
    await tester.pump();
    final afterScroll = registry.geometryFor('block')!.globalBounds.top;
    expect(afterScroll, lessThan(before));
    expect(registry.viewport!.scrollOffset.y, 300);

    tester.view.physicalSize = const Size(700, 500);
    await tester.pumpWidget(
      _surface(
        registry: registry,
        interaction: interaction,
        scrollController: scrollController,
        topSpacer: 500,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(registry.viewport!.globalBounds.width, 700);
  });

  testWidgets('surface releases geometry when a block disappears', (
    tester,
  ) async {
    final registry = BlockGeometryRegistry();
    final interaction = WorkspaceInteractionController();
    final scrollController = ScrollController();
    final visible = ValueNotifier(true);
    addTearDown(registry.dispose);
    addTearDown(interaction.dispose);
    addTearDown(scrollController.dispose);
    addTearDown(visible.dispose);

    await tester.pumpWidget(
      _surface(
        registry: registry,
        interaction: interaction,
        scrollController: scrollController,
        visible: visible,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(registry.geometryFor('block'), isNotNull);

    visible.value = false;
    await tester.pump();
    await tester.pump();
    expect(registry.geometryFor('block'), isNull);

    visible.value = true;
    await tester.pump();
    await tester.pump();
    expect(registry.geometryFor('block'), isNotNull);
  });

  testWidgets('toolbar anchor follows scroll and respects visible viewport', (
    tester,
  ) async {
    final registry = BlockGeometryRegistry();
    final interaction = WorkspaceInteractionController()
      ..dispatch(const SelectBlockIntent('block'));
    final scrollController = ScrollController();
    addTearDown(registry.dispose);
    addTearDown(interaction.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      _surface(
        registry: registry,
        interaction: interaction,
        scrollController: scrollController,
        topSpacer: 420,
        keyboardInset: 140,
        showModal: true,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(interaction.context.selectedBlock, 'block');
    expect(registry.viewport, isNotNull);
    expect(registry.geometryFor('block'), isNotNull);
    expect(registry.geometryFor('block')!.isVisible, isTrue);
    final before = tester.getRect(find.byKey(const ValueKey('modal-actions')));

    scrollController.jumpTo(260);
    await tester.pump();
    await tester.pumpAndSettle();
    final after = tester.getRect(find.byKey(const ValueKey('modal-actions')));
    final entry = registry.geometryFor('block')!;

    expect(after.top, isNot(before.top));
    expect(entry.toolbarAnchor.y, entry.globalBounds.top);
    expect(
      after.bottom,
      lessThanOrEqualTo(registry.viewport!.visibleBounds.bottom + 0.01),
    );
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('selection overlay supports ${brightness.name} theme', (
      tester,
    ) async {
      final registry = BlockGeometryRegistry();
      final interaction = WorkspaceInteractionController()
        ..dispatch(const SelectBlockIntent('block'));
      final scrollController = ScrollController();
      addTearDown(registry.dispose);
      addTearDown(interaction.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        _surface(
          registry: registry,
          interaction: interaction,
          scrollController: scrollController,
          brightness: brightness,
          debugGeometry: true,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _surface({
  required BlockGeometryRegistry registry,
  required WorkspaceInteractionController interaction,
  required ScrollController scrollController,
  double topSpacer = 40,
  double keyboardInset = 0,
  Brightness brightness = Brightness.light,
  bool debugGeometry = false,
  bool showModal = false,
  ValueNotifier<bool>? visible,
  WorkspaceViewportController? viewportController,
  bool resizable = false,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(500, 700),
      viewInsets: EdgeInsets.only(bottom: keyboardInset),
    ),
    child: Scaffold(
      body: WorkspaceSurface(
        workspaceId: 'workspace',
        pageId: 'page',
        registry: registry,
        interaction: interaction,
        scrollController: scrollController,
        debugGeometry: debugGeometry,
        keyboardInset: keyboardInset,
        viewportController: viewportController,
        isBlockResizable: resizable ? (_) => true : null,
        modalBuilder: showModal
            ? (_, _) => const SizedBox(
                key: ValueKey('modal-actions'),
                width: 120,
                height: 48,
              )
            : null,
        content: ListView(
          controller: scrollController,
          padding: const EdgeInsets.only(left: 60, right: 20),
          children: [
            SizedBox(height: topSpacer),
            if (visible == null)
              _reportedBlock(registry)
            else
              ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (context, isVisible, _) => isVisible
                    ? _reportedBlock(registry)
                    : const SizedBox.shrink(),
              ),
            const SizedBox(height: 800),
          ],
        ),
      ),
    ),
  ),
);

Widget _reportedBlock(BlockGeometryRegistry registry) => BlockGeometryReporter(
  registry: registry,
  blockId: 'block',
  workspaceId: 'workspace',
  pageId: 'page',
  layer: 0,
  child: InteractionRegionReporter(
    registry: registry,
    blockId: 'block',
    regionId: 'text',
    target: const TextRegionHitTarget('block'),
    priority: 20,
    child: const SizedBox(height: 100, child: Text('Block')),
  ),
);
