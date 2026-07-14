class SpatialPoint {
  const SpatialPoint(this.x, this.y);

  final double x;
  final double y;

  SpatialPoint operator +(SpatialPoint other) =>
      SpatialPoint(x + other.x, y + other.y);

  SpatialPoint operator -(SpatialPoint other) =>
      SpatialPoint(x - other.x, y - other.y);

  @override
  bool operator ==(Object other) =>
      other is SpatialPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

class SpatialRect {
  const SpatialRect.fromLTRB(this.left, this.top, this.right, this.bottom);

  const SpatialRect.fromLTWH(
    double left,
    double top,
    double width,
    double height,
  ) : this.fromLTRB(left, top, left + width, top + height);

  static const zero = SpatialRect.fromLTRB(0, 0, 0, 0);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  SpatialPoint get topLeft => SpatialPoint(left, top);
  SpatialPoint get center => SpatialPoint(left + width / 2, top + height / 2);
  bool get isEmpty => width <= 0 || height <= 0;

  bool contains(SpatialPoint point) =>
      point.x >= left &&
      point.x <= right &&
      point.y >= top &&
      point.y <= bottom;

  bool overlaps(SpatialRect other) =>
      left < other.right &&
      right > other.left &&
      top < other.bottom &&
      bottom > other.top;

  SpatialRect intersect(SpatialRect other) {
    final nextLeft = left > other.left ? left : other.left;
    final nextTop = top > other.top ? top : other.top;
    final nextRight = right < other.right ? right : other.right;
    final nextBottom = bottom < other.bottom ? bottom : other.bottom;
    if (nextRight <= nextLeft || nextBottom <= nextTop) return zero;
    return SpatialRect.fromLTRB(nextLeft, nextTop, nextRight, nextBottom);
  }

  SpatialRect translate(double dx, double dy) =>
      SpatialRect.fromLTRB(left + dx, top + dy, right + dx, bottom + dy);

  @override
  bool operator ==(Object other) =>
      other is SpatialRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}
