import 'package:allministrator/domain/interaction/spatial_geometry.dart';
import 'package:flutter/foundation.dart';

class WorkspaceCamera {
  const WorkspaceCamera({
    this.zoom = 1,
    this.translation = const SpatialPoint(0, 0),
  });

  final double zoom;
  final SpatialPoint translation;

  SpatialPoint workspaceToViewport(SpatialPoint point) => SpatialPoint(
    point.x * zoom + translation.x,
    point.y * zoom + translation.y,
  );

  SpatialPoint viewportToWorkspace(SpatialPoint point) => SpatialPoint(
    (point.x - translation.x) / zoom,
    (point.y - translation.y) / zoom,
  );

  SpatialRect workspaceToViewportRect(SpatialRect rect) {
    final origin = workspaceToViewport(rect.topLeft);
    return SpatialRect.fromLTWH(
      origin.x,
      origin.y,
      rect.width * zoom,
      rect.height * zoom,
    );
  }

  SpatialRect viewportToWorkspaceRect(SpatialRect rect) {
    final origin = viewportToWorkspace(rect.topLeft);
    return SpatialRect.fromLTWH(
      origin.x,
      origin.y,
      rect.width / zoom,
      rect.height / zoom,
    );
  }

  WorkspaceCamera copyWith({double? zoom, SpatialPoint? translation}) =>
      WorkspaceCamera(
        zoom: zoom ?? this.zoom,
        translation: translation ?? this.translation,
      );

  @override
  bool operator ==(Object other) =>
      other is WorkspaceCamera &&
      other.zoom == zoom &&
      other.translation == translation;

  @override
  int get hashCode => Object.hash(zoom, translation);
}

class WorkspaceViewportState {
  const WorkspaceViewportState({
    this.workspaceId,
    this.pageId,
    this.camera = const WorkspaceCamera(),
    this.minZoom = .5,
    this.maxZoom = 3,
  });

  final String? workspaceId;
  final String? pageId;
  final WorkspaceCamera camera;
  final double minZoom;
  final double maxZoom;

  WorkspaceViewportState copyWith({
    String? workspaceId,
    String? pageId,
    WorkspaceCamera? camera,
    double? minZoom,
    double? maxZoom,
  }) => WorkspaceViewportState(
    workspaceId: workspaceId ?? this.workspaceId,
    pageId: pageId ?? this.pageId,
    camera: camera ?? this.camera,
    minZoom: minZoom ?? this.minZoom,
    maxZoom: maxZoom ?? this.maxZoom,
  );
}

class WorkspaceViewportController extends ChangeNotifier {
  WorkspaceViewportController({
    String? workspaceId,
    String? pageId,
    double minZoom = .5,
    double maxZoom = 3,
  }) : assert(minZoom > 0 && maxZoom >= minZoom),
       _state = WorkspaceViewportState(
         workspaceId: workspaceId,
         pageId: pageId,
         minZoom: minZoom,
         maxZoom: maxZoom,
       );

  WorkspaceViewportState _state;
  bool _gestureActive = false;
  DateTime? _suppressTapUntil;

  WorkspaceViewportState get state => _state;
  WorkspaceCamera get camera => _state.camera;
  bool get isGestureActive =>
      _gestureActive || (_suppressTapUntil?.isAfter(DateTime.now()) ?? false);

  void beginGesture() => _gestureActive = true;

  void endGesture() {
    _gestureActive = false;
    _suppressTapUntil = DateTime.now().add(const Duration(milliseconds: 120));
  }

  void attach({required String workspaceId, required String pageId}) {
    if (_state.workspaceId == workspaceId && _state.pageId == pageId) return;
    _state = _state.copyWith(workspaceId: workspaceId, pageId: pageId);
    notifyListeners();
  }

  void panBy(SpatialPoint delta) {
    if (delta == const SpatialPoint(0, 0)) return;
    _setCamera(camera.copyWith(translation: camera.translation + delta));
  }

  void zoomBy(double factor, {required SpatialPoint focalPoint}) {
    if (!factor.isFinite || factor <= 0) return;
    setZoom(camera.zoom * factor, focalPoint: focalPoint);
  }

  void setZoom(double zoom, {required SpatialPoint focalPoint}) {
    final nextZoom = zoom.clamp(_state.minZoom, _state.maxZoom).toDouble();
    if ((nextZoom - camera.zoom).abs() < .0001) return;
    final workspaceFocal = camera.viewportToWorkspace(focalPoint);
    final translation = SpatialPoint(
      focalPoint.x - workspaceFocal.x * nextZoom,
      focalPoint.y - workspaceFocal.y * nextZoom,
    );
    _setCamera(WorkspaceCamera(zoom: nextZoom, translation: translation));
  }

  void reset() => _setCamera(const WorkspaceCamera());

  void _setCamera(WorkspaceCamera next) {
    if (next == camera) return;
    _state = _state.copyWith(camera: next);
    notifyListeners();
  }
}
