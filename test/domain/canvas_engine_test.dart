import 'package:allministrator/domain/blocks/blocks.dart';
import 'package:allministrator/domain/editing/workspace_editor_session.dart';
import 'package:allministrator/domain/entities/canvas_layout.dart';
import 'package:allministrator/domain/entities/workspace.dart';
import 'package:allministrator/domain/entities/workspace_page.dart';
import 'package:allministrator/domain/interaction/interaction.dart';
import 'package:allministrator/domain/value_objects/document_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy pages default to structured document layout', () {
    final page = WorkspacePage.fromJson({
      'id': 'page',
      'workspaceId': 'workspace',
      'blocks': [
        TextBlock(
          id: 'text',
          orderKey: 0,
          paragraphs: const [BlockParagraph(id: 'paragraph', text: 'Hola')],
        ).toJson(),
      ],
    });

    expect(page.layoutType, WorkspaceLayoutType.document);
    expect(page.canvasLayout, isNull);
  });

  test('schema 3 workspaces upgrade idempotently without losing blocks', () {
    final workspace = _workspace();
    final first = DocumentContent.fromJson({
      'schemaVersion': 3,
      'workspace': workspace.toJson(),
    });
    final second = DocumentContent.fromJson(first.toJson());

    expect(first.schemaVersion, DocumentContent.currentSchemaVersion);
    expect(first.wasMigrated, isTrue);
    expect(
      first.workspace.primaryPage.layoutType,
      WorkspaceLayoutType.document,
    );
    expect(first.workspace.primaryPage.blocks.single.id, 'a');
    expect(second.wasMigrated, isFalse);
    expect(second.workspace.toJson(), first.workspace.toJson());
  });

  test(
    'document to canvas conversion is persistent, deterministic and undoable',
    () {
      final session = _session(
        blocks: [
          _text('a', 0),
          DividerBlock(id: 'b', orderKey: 1),
          _text('c', 2),
        ],
      );

      session.convertLayout(WorkspaceLayoutType.canvas);
      expect(session.page.layoutType, WorkspaceLayoutType.canvas);
      expect(
        session.page.canvasLayout!.placements.map((item) => item.blockId),
        ['a', 'b', 'c'],
      );
      final restored = Workspace.fromJson(session.workspace.toJson());
      expect(restored.primaryPage.canvasLayout!.placements, hasLength(3));

      session.undo();
      expect(session.page.layoutType, WorkspaceLayoutType.document);
      session.redo();
      expect(session.page.layoutType, WorkspaceLayoutType.canvas);
    },
  );

  test('canvas converts to document by rows and then left-to-right', () {
    final blocks = <BaseBlock>[_text('a', 0), _text('b', 1), _text('c', 2)];
    final base = _workspace(blocks: blocks);
    final canvasPage = base.primaryPage.copyWith(
      layoutType: WorkspaceLayoutType.canvas,
      canvasLayout: const CanvasLayoutState(
        placements: [
          CanvasPlacement(blockId: 'a', x: 500, y: 100, zIndex: 0),
          CanvasPlacement(blockId: 'b', x: 100, y: 110, zIndex: 1),
          CanvasPlacement(blockId: 'c', x: 0, y: 220, zIndex: 2),
        ],
      ),
    );
    final session = WorkspaceEditorSession(
      workspace: base.copyWith(pages: [canvasPage]),
      onChanged: (_) {},
    );

    session.convertLayout(WorkspaceLayoutType.document);

    expect(session.blocks.map((block) => block.id), ['b', 'a', 'c']);
  });

  test(
    'free multi-drag snaps in workspace coordinates as one undo command',
    () {
      final session = _canvasSession();
      final beforeA = session.page.canvasLayout!.placementFor('a')!;
      final beforeB = session.page.canvasLayout!.placementFor('b')!;

      session.moveCanvasBlocks(const ['a', 'b'], const SpatialPoint(25, 50));
      final moved = session.page.canvasLayout!;
      expect(moved.placementFor('a')!.x, 192);
      expect(moved.placementFor('a')!.y, 168);
      expect(moved.placementFor('b')!.x, 600);
      expect(moved.placementFor('b')!.y, 168);

      session.undo();
      expect(session.page.canvasLayout!.placementFor('a')!.x, beforeA.x);
      expect(session.page.canvasLayout!.placementFor('b')!.y, beforeB.y);
      session.redo();
      expect(session.page.canvasLayout!.placementFor('a')!.x, 192);
    },
  );

  test('canvas resize updates placement and survives undo and persistence', () {
    final session = _canvasSession();
    session.resizeBlock('a', const SpatialRect.fromLTWH(210, 260, 480, 180));

    final placement = session.page.canvasLayout!.placementFor('a')!;
    expect(placement.x, 210);
    expect(placement.width, 480);
    expect(placement.height, 180);
    expect(
      Workspace.fromJson(
        session.workspace.toJson(),
      ).primaryPage.canvasLayout!.placementFor('a')!.height,
      180,
    );
    session.undo();
    expect(session.page.canvasLayout!.placementFor('a')!.width, 360);
  });

  test(
    'alignment and horizontal distribution each create one history entry',
    () {
      final session = _canvasSession(threeBlocks: true);
      const bounds = {
        'a': SpatialRect.fromLTWH(160, 120, 100, 50),
        'b': SpatialRect.fromLTWH(580, 240, 100, 50),
        'c': SpatialRect.fromLTWH(1120, 420, 100, 50),
      };

      session.alignBlocks(
        const ['a', 'b', 'c'],
        bounds,
        BlockAlignmentAxis.top,
      );
      expect(session.page.canvasLayout!.placementFor('b')!.y, 0);
      session.undo();
      expect(session.page.canvasLayout!.placementFor('b')!.y, 120);

      session.distributeBlocksHorizontally(const ['a', 'b', 'c'], bounds);
      final distributedX = session.page.canvasLayout!.placementFor('b')!.x;
      expect(distributedX, 640);
      session.undo();
      expect(session.page.canvasLayout!.placementFor('b')!.x, 580);
    },
  );

  test('z-order controls spatial hit testing and is undoable', () {
    final session = _canvasSession();
    session.moveCanvasBlocks(const ['b'], const SpatialPoint(-408, 0));
    var layout = session.page.canvasLayout!;
    var hit = CanvasSpatialIndex(
      layout.placements,
    ).hitTest(const SpatialPoint(180, 140));
    expect(hit!.blockId, 'b');

    session.changeCanvasZOrder('a', 1, absolute: true);
    layout = session.page.canvasLayout!;
    hit = CanvasSpatialIndex(
      layout.placements,
    ).hitTest(const SpatialPoint(180, 140));
    expect(hit!.blockId, 'a');
    session.undo();
    expect(
      CanvasSpatialIndex(
        session.page.canvasLayout!.placements,
      ).hitTest(const SpatialPoint(180, 140))!.blockId,
      'b',
    );
  });

  test('connectors and flat frame membership persist and follow movement', () {
    final session = _canvasSession();
    final connectorId = session.connectCanvasBlocks('a', 'b');
    expect(connectorId, isNotNull);
    session.createCanvasFrame(
      const ['a', 'b'],
      const {
        'a': SpatialRect.fromLTWH(160, 120, 360, 96),
        'b': SpatialRect.fromLTWH(568, 120, 360, 96),
      },
    );
    final frame = session.page.canvasLayout!.frames.single;
    expect(session.page.canvasLayout!.placementFor('a')!.containerId, frame.id);

    session.moveCanvasBlocks(const ['a'], const SpatialPoint(24, 0));
    final restored = Workspace.fromJson(session.workspace.toJson());
    final layout = restored.primaryPage.canvasLayout!;
    expect(layout.connectors.single.id, connectorId);
    expect(layout.connectors.single.sourceBlockId, 'a');
    expect(layout.placementFor('a')!.x, 192);
    expect(layout.frames.single.id, frame.id);
  });

  test('camera can fit content and center a selected region', () {
    final controller = WorkspaceViewportController(minZoom: .25, maxZoom: 4);
    addTearDown(controller.dispose);

    controller.fitBounds(
      const SpatialRect.fromLTWH(100, 200, 800, 400),
      viewportWidth: 1000,
      viewportHeight: 600,
      padding: 50,
    );
    expect(controller.camera.zoom, 1.125);
    expect(
      controller.camera.workspaceToViewport(const SpatialPoint(500, 400)),
      const SpatialPoint(500, 300),
    );
    controller.centerOn(
      const SpatialRect.fromLTWH(900, 700, 100, 100),
      viewportWidth: 1000,
      viewportHeight: 600,
    );
    expect(
      controller.camera.workspaceToViewport(const SpatialPoint(950, 750)),
      const SpatialPoint(500, 300),
    );
  });

  test('canvas dispatcher commits zoom-correct multi-block drag delta', () {
    final registry = BlockGeometryRegistry();
    final controller = WorkspaceInteractionController();
    final commands = <InteractionIntent>[];
    addTearDown(registry.dispose);
    addTearDown(controller.dispose);
    registry.updateViewport(
      const WorkspaceViewportGeometry(
        globalBounds: SpatialRect.fromLTWH(0, 0, 800, 600),
        camera: WorkspaceCamera(zoom: 2),
      ),
    );
    final dispatcher = InputDispatcher(
      workspaceId: 'workspace',
      pageId: 'page',
      registry: registry,
      controller: controller,
      resolver: InteractionResolver(
        blockInfo: (_) => const BlockInteractionInfo(
          capabilities: {BlockCapability.selectable, BlockCapability.movable},
        ),
      ),
      isCanvasMode: () => true,
      camera: () => const WorkspaceCamera(zoom: 2),
      onCommand: (intent, _) => commands.add(intent),
    );
    addTearDown(dispatcher.dispose);

    dispatcher.dispatch(
      _pointer(
        'down',
        NormalizedInputEventType.pointerDown,
        20,
        20,
        target: const BlockHandleHitTarget('a'),
      ),
    );
    dispatcher.dispatch(
      _pointer(
        'drag-start',
        NormalizedInputEventType.longPressStart,
        20,
        20,
        target: const BlockHandleHitTarget('a'),
      ),
    );
    dispatcher.dispatch(
      _pointer('move', NormalizedInputEventType.pointerMove, 100, 60),
    );
    dispatcher.dispatch(
      _pointer('up', NormalizedInputEventType.pointerUp, 100, 60),
    );

    final command = commands.single as CommitCanvasDragIntent;
    expect(command.blockIds, ['a']);
    expect(command.delta, const SpatialPoint(40, 20));
    expect(controller.context.activeSession, isNull);
  });
}

NormalizedInputEvent _pointer(
  String id,
  NormalizedInputEventType type,
  double x,
  double y, {
  WorkspaceHitTarget? target,
}) => NormalizedInputEvent(
  eventId: id,
  workspaceId: 'workspace',
  pageId: 'page',
  type: type,
  deviceType: InputDeviceType.mouse,
  timestamp: DateTime.utc(2026),
  pointerId: 1,
  globalPosition: SpatialPoint(x, y),
  hitTarget: target,
  targetBlockId: target?.blockId,
);

TextBlock _text(String id, double order) => TextBlock(
  id: id,
  orderKey: order,
  paragraphs: [BlockParagraph(id: 'p-$id', text: id.toUpperCase())],
);

Workspace _workspace({List<BaseBlock>? blocks}) {
  final now = DateTime.utc(2026);
  return Workspace(
    id: 'workspace',
    title: 'Workspace',
    description: null,
    workspaceType: WorkspaceType.document,
    pages: [
      WorkspacePage(
        id: 'page',
        workspaceId: 'workspace',
        title: null,
        layoutType: WorkspaceLayoutType.document,
        blocks: blocks ?? [_text('a', 0)],
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

WorkspaceEditorSession _session({required List<BaseBlock> blocks}) =>
    WorkspaceEditorSession(
      workspace: _workspace(blocks: blocks),
      onChanged: (_) {},
    );

WorkspaceEditorSession _canvasSession({bool threeBlocks = false}) {
  final session = _session(
    blocks: [
      ImageBlock(id: 'a', orderKey: 0, attachmentId: 'a'),
      ImageBlock(id: 'b', orderKey: 1, attachmentId: 'b'),
      if (threeBlocks) ImageBlock(id: 'c', orderKey: 2, attachmentId: 'c'),
    ],
  );
  session.convertLayout(WorkspaceLayoutType.canvas);
  return session;
}
