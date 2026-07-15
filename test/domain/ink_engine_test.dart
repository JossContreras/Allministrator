import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ink model', () {
    test('validates, derives bounds and serializes vector data only', () {
      final stroke = _stroke(
        'stroke',
        points: [
          _point(10, 20),
          _point(20, 30, pressure: .8),
          InkPoint(
            workspacePosition: const SpatialPoint(25, 35),
            timestamp: const Duration(milliseconds: 2),
            isPredicted: true,
          ),
        ],
      );
      final restored = InkLayerState.fromJson(
        InkLayerState(elements: [stroke]).toJson(),
      );

      expect(stroke.isValid, isTrue);
      expect(stroke.bounds.contains(const SpatialPoint(10, 20)), isTrue);
      expect(restored.strokes, hasLength(1));
      expect(restored.strokes.single.points, hasLength(2));
      expect(restored.strokes.single.points.last.pressure, .8);
      expect(restored.toJson()['formatVersion'], 1);
    });

    test(
      'anchor follows target resize and has a non-destructive orphan policy',
      () {
        const anchor = AnnotationAnchor(
          kind: AnnotationAnchorKind.imageRelative,
          targetId: 'image',
          referenceBounds: SpatialRect.fromLTWH(100, 100, 200, 100),
        );
        expect(
          anchor.resolve(
            const SpatialPoint(200, 150),
            const SpatialRect.fromLTWH(300, 200, 400, 200),
          ),
          const SpatialPoint(500, 300),
        );

        final layer = InkLayerState(
          elements: [_stroke('anchored', anchor: anchor)],
        ).normalizedForBlockIds(const {});
        expect(layer.elements.single.anchor, isNull);
        expect(
          layer.orphanedAnnotationPolicy,
          OrphanedAnnotationPolicy.convertToFreeCanvas,
        );
      },
    );

    test(
      'simplifies at commit while retaining endpoints and short corners',
      () {
        final points = [
          for (var index = 0; index < 30; index++)
            _point(index.toDouble(), index.isEven ? .05 : -.05),
          _point(30, 12),
          _point(42, 12),
        ];
        final simplified = const InkProcessor().simplify(
          points,
          brush: InkBrushStyle.pen(width: 3),
        );

        expect(simplified.length, lessThan(points.length));
        expect(
          simplified.first.workspacePosition,
          points.first.workspacePosition,
        );
        expect(
          simplified.last.workspacePosition,
          points.last.workspacePosition,
        );
        expect(
          simplified.any((point) => point.workspacePosition.y >= 12),
          isTrue,
        );
      },
    );

    test('spatial index supports eraser hit testing and ink lasso', () {
      final layer = InkLayerState(
        elements: [
          _stroke('inside'),
          _stroke('outside', points: [_point(200, 200), _point(240, 240)]),
        ],
      );
      final index = InkSpatialIndex(layer.elements);

      expect(
        index.hitTest(const SpatialPoint(12, 12), tolerance: 4),
        contains('inside'),
      );
      expect(
        index.insideLasso(const [
          SpatialPoint(0, 0),
          SpatialPoint(50, 0),
          SpatialPoint(50, 50),
          SpatialPoint(0, 50),
        ]),
        ['inside'],
      );
    });
  });

  test('Workspace persistence and history restore ink and z-order exactly', () {
    final session = _session();
    final stroke = _stroke('one');
    final shape = InkShape(
      id: 'shape',
      surfaceId: 'page',
      kind: InkShapeKind.rectangle,
      start: const SpatialPoint(30, 40),
      end: const SpatialPoint(90, 100),
      brush: InkBrushStyle.shape(),
      zOrder: 2,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    session.addInkElement(stroke);
    session.addInkElement(shape);
    expect(session.page.inkLayer.elements, hasLength(2));
    expect(
      Workspace.fromJson(
        session.workspace.toJson(),
      ).primaryPage.inkLayer.shapes.single.zOrder,
      2,
    );
    expect(
      DocumentContent.fromJson(
        DocumentContent.fromWorkspace(session.workspace).toJson(),
      ).schemaVersion,
      5,
    );

    session.deleteInkElements(const ['one', 'shape']);
    expect(session.page.inkLayer.elements, isEmpty);
    session.undo();
    expect(session.page.inkLayer.elements, hasLength(2));
    session.undo();
    expect(session.page.inkLayer.elements.single.id, 'one');
    session.redo();
    expect(session.page.inkLayer.shapes.single.id, 'shape');
  });

  test('ink selection move, style and duplicate are atomic and undoable', () {
    final session = _session();
    session.addInkElement(_stroke('one'));
    session.translateInkElements(const ['one'], const SpatialPoint(5, 7));
    expect(
      (session.page.inkLayer.elementById('one') as InkStroke)
          .points
          .first
          .workspacePosition,
      const SpatialPoint(15, 17),
    );
    session.undo();
    expect(
      (session.page.inkLayer.elementById('one') as InkStroke)
          .points
          .first
          .workspacePosition,
      const SpatialPoint(10, 10),
    );

    final clones = session.duplicateInkElements(const ['one']);
    expect(clones, hasLength(1));
    expect(session.page.inkLayer.elements, hasLength(2));
    session.updateInkStyle(clones, InkBrushStyle.pen(color: 0xFFDC2626));
    expect(
      session.page.inkLayer.elementById(clones.single)!.brush.color,
      0xFFDC2626,
    );
  });

  group('Ink input pipeline', () {
    test(
      'workspace coordinates remain stable through zoom, pan and scroll',
      () {
        final registry = BlockGeometryRegistry();
        addTearDown(registry.dispose);
        registry.updateViewport(
          const WorkspaceViewportGeometry(
            globalBounds: SpatialRect.fromLTWH(40, 80, 800, 600),
            scrollOffset: SpatialPoint(0, 120),
            camera: WorkspaceCamera(
              zoom: 2,
              translation: SpatialPoint(30, -20),
            ),
          ),
        );
        final geometry = GeometryResolver(registry);
        const stored = SpatialPoint(150, 260);
        final screen = geometry.resolvePoint(
          stored,
          from: GeometryCoordinateSpace.workspace,
          to: GeometryCoordinateSpace.screen,
        );
        final restored = geometry.resolvePoint(
          screen,
          from: GeometryCoordinateSpace.screen,
          to: GeometryCoordinateSpace.workspace,
        );

        expect(restored.x, closeTo(stored.x, .0001));
        expect(restored.y, closeTo(stored.y, .0001));
      },
    );

    test('pen uses one session and one commit; cancel persists nothing', () {
      final registry = BlockGeometryRegistry();
      final controller = WorkspaceInteractionController();
      final commands = <InteractionIntent>[];
      final dispatcher = InputDispatcher(
        workspaceId: 'workspace',
        pageId: 'page',
        registry: registry,
        controller: controller,
        resolver: InteractionResolver(inkBrush: (_) => InkBrushStyle.pen()),
        onCommand: (intent, _) => commands.add(intent),
      );
      addTearDown(registry.dispose);
      addTearDown(controller.dispose);
      addTearDown(dispatcher.dispose);
      controller.activateTool(WorkspaceTool.pen);

      dispatcher.dispatch(
        _event(
          'down',
          NormalizedInputEventType.pointerDown,
          position: const SpatialPoint(10, 10),
        ),
      );
      expect(controller.context.activeSession, isA<InkSession>());
      dispatcher.dispatch(
        _event(
          'move',
          NormalizedInputEventType.pointerMove,
          position: const SpatialPoint(20, 20),
          milliseconds: 5,
        ),
      );
      dispatcher.dispatch(
        _event(
          'up',
          NormalizedInputEventType.pointerUp,
          position: const SpatialPoint(30, 25),
          milliseconds: 10,
        ),
      );

      expect(commands.whereType<CommitInkIntent>(), hasLength(1));
      final committed = (commands.whereType<CommitInkIntent>().single).session;
      expect(committed.points.length, greaterThanOrEqualTo(3));
      expect(controller.context.activeSession, isNull);

      dispatcher.dispatch(
        _event(
          'down-2',
          NormalizedInputEventType.pointerDown,
          position: const SpatialPoint(40, 40),
          pointerId: 2,
        ),
      );
      dispatcher.dispatch(
        _event(
          'cancel',
          NormalizedInputEventType.pointerCancel,
          position: const SpatialPoint(41, 41),
          pointerId: 2,
        ),
      );
      expect(commands.whereType<CommitInkIntent>(), hasLength(1));
      expect(controller.context.activeSession, isNull);
    });

    test(
      'page change cancellation removes preview and keeps persisted state out',
      () {
        final controller = WorkspaceInteractionController();
        addTearDown(controller.dispose);
        controller.activateTool(WorkspaceTool.pen);
        controller.dispatch(
          BeginInkIntent(
            correlationId: 'page-change',
            pointerId: 1,
            tool: WorkspaceTool.pen,
            point: _point(1, 1),
            brush: InkBrushStyle.pen(),
          ),
        );
        expect(controller.context.activeSession, isA<InkSession>());

        controller.dispatch(
          const CancelInteractionIntent(
            reason: InteractionCancellationReason.pageChanged,
          ),
        );

        expect(controller.context.activeSession, isNull);
        expect(controller.context.activeTool, WorkspaceTool.pen);
      },
    );

    test('ink mode overrides text hit targets and lasso selects ink only', () {
      final registry = BlockGeometryRegistry();
      final controller = WorkspaceInteractionController();
      final dispatcher = InputDispatcher(
        workspaceId: 'workspace',
        pageId: 'page',
        registry: registry,
        controller: controller,
        resolver: InteractionResolver(inkBrush: (_) => InkBrushStyle.pen()),
        inkLasso: (_) => const ['stroke-a', 'shape-b'],
      );
      addTearDown(registry.dispose);
      addTearDown(controller.dispose);
      addTearDown(dispatcher.dispose);
      controller.activateTool(WorkspaceTool.inkLasso);

      final syntheticTap = const InteractionResolver().resolve(
        event: _event(
          'synthetic-tap',
          NormalizedInputEventType.tap,
          position: const SpatialPoint(0, 0),
          target: const TextRegionHitTarget('text'),
        ),
        context: controller.context,
      );
      expect(syntheticTap.kind, InteractionIntentResultKind.consumed);

      dispatcher.dispatch(
        _event(
          'lasso-down',
          NormalizedInputEventType.pointerDown,
          position: const SpatialPoint(0, 0),
          target: const TextRegionHitTarget('text'),
        ),
      );
      expect(controller.context.activeSession, isA<InkSession>());
      dispatcher.dispatch(
        _event(
          'lasso-move',
          NormalizedInputEventType.pointerMove,
          position: const SpatialPoint(50, 50),
          milliseconds: 4,
        ),
      );
      dispatcher.dispatch(
        _event(
          'lasso-up',
          NormalizedInputEventType.pointerUp,
          position: const SpatialPoint(0, 50),
          milliseconds: 8,
        ),
      );

      final selection = controller.context.currentSelection as InkSelection;
      expect(selection.elementIds, ['stroke-a', 'shape-b']);
      expect(controller.context.editingBlock, isNull);
    });

    test(
      'eraser previews affected strokes and commits one logical command',
      () {
        final registry = BlockGeometryRegistry();
        final controller = WorkspaceInteractionController();
        CommitInkIntent? command;
        final dispatcher = InputDispatcher(
          workspaceId: 'workspace',
          pageId: 'page',
          registry: registry,
          controller: controller,
          resolver: const InteractionResolver(),
          inkHitTest: (_, _) => const ['a', 'b'],
          onCommand: (intent, _) {
            if (intent is CommitInkIntent) command = intent;
          },
        );
        addTearDown(registry.dispose);
        addTearDown(controller.dispose);
        addTearDown(dispatcher.dispose);
        controller.activateTool(WorkspaceTool.eraser);

        dispatcher.dispatch(
          _event(
            'erase-down',
            NormalizedInputEventType.pointerDown,
            position: const SpatialPoint(10, 10),
          ),
        );
        dispatcher.dispatch(
          _event(
            'erase-move',
            NormalizedInputEventType.pointerMove,
            position: const SpatialPoint(12, 12),
            milliseconds: 2,
          ),
        );
        expect(
          (controller.context.activeSession as InkSession).affectedElementIds,
          containsAll(['a', 'b']),
        );
        dispatcher.dispatch(
          _event(
            'erase-up',
            NormalizedInputEventType.pointerUp,
            position: const SpatialPoint(14, 14),
            milliseconds: 4,
          ),
        );
        expect(command!.session.affectedElementIds, containsAll(['a', 'b']));
      },
    );

    test('overlay controls capture pointer down without creating ink', () {
      final registry = BlockGeometryRegistry();
      final controller = WorkspaceInteractionController();
      final dispatcher = InputDispatcher(
        workspaceId: 'workspace',
        pageId: 'page',
        registry: registry,
        controller: controller,
        resolver: const InteractionResolver(),
        inputBlocker: (_) => true,
      );
      addTearDown(registry.dispose);
      addTearDown(controller.dispose);
      addTearDown(dispatcher.dispose);
      controller.activateTool(WorkspaceTool.pen);

      final result = dispatcher.dispatch(
        _event(
          'toolbar-down',
          NormalizedInputEventType.pointerDown,
          position: const SpatialPoint(10, 10),
        ),
      );

      expect(result.resolution.reason, 'overlay-control-captured-input');
      expect(controller.context.activeSession, isNull);
    });
  });
}

InkPoint _point(double x, double y, {double? pressure}) => InkPoint(
  workspacePosition: SpatialPoint(x, y),
  timestamp: Duration(milliseconds: x.round()),
  pressure: pressure,
);

InkStroke _stroke(
  String id, {
  List<InkPoint>? points,
  AnnotationAnchor? anchor,
}) => InkStroke(
  id: id,
  surfaceId: 'page',
  brush: InkBrushStyle.pen(),
  points: points ?? [_point(10, 10), _point(30, 30)],
  anchor: anchor,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

NormalizedInputEvent _event(
  String id,
  NormalizedInputEventType type, {
  required SpatialPoint position,
  WorkspaceHitTarget? target,
  int pointerId = 1,
  int milliseconds = 0,
}) => NormalizedInputEvent(
  eventId: id,
  workspaceId: 'workspace',
  pageId: 'page',
  type: type,
  deviceType: InputDeviceType.stylus,
  timestamp: DateTime.utc(2026).add(Duration(milliseconds: milliseconds)),
  pointerId: pointerId,
  globalPosition: position,
  workspacePosition: position,
  pressure: .6,
  hitTarget: target ?? const EmptyAreaHitTarget(),
  targetBlockId: target?.blockId,
);

WorkspaceEditorSession _session() =>
    WorkspaceEditorSession(workspace: _workspace(), onChanged: (_) {});

Workspace _workspace() {
  final now = DateTime.utc(2026);
  return Workspace(
    id: 'workspace',
    title: 'Ink',
    description: null,
    workspaceType: WorkspaceType.document,
    pages: [
      WorkspacePage(
        id: 'page',
        workspaceId: 'workspace',
        title: null,
        layoutType: WorkspaceLayoutType.canvas,
        blocks: [
          TextBlock(
            id: 'text',
            orderKey: 0,
            paragraphs: [BlockParagraph(id: 'paragraph', text: 'Texto')],
          ),
        ],
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        version: 1,
        metadata: const {},
      ),
    ],
    themeId: null,
    templateId: null,
    isFavorite: false,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    version: 1,
    metadata: const {},
  );
}
