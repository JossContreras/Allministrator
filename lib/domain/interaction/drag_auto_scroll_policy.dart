import 'package:allministrator/domain/interaction/spatial_geometry.dart';

/// Deterministic edge policy; acceleration belongs to a later sprint.
class DragAutoScrollPolicy {
  const DragAutoScrollPolicy({this.edgeExtent = 48, this.step = 12});

  final double edgeExtent;
  final double step;

  double deltaFor(double pointerY, SpatialRect visibleBounds) {
    if (pointerY < visibleBounds.top + edgeExtent) return -step;
    if (pointerY > visibleBounds.bottom - edgeExtent) return step;
    return 0;
  }
}
