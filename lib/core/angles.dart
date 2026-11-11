import 'dart:math' as math;

/// Pure math for the level, inclinometer and compass tools.
///
/// Android's gravity sensor reports the vector pointing up, in the phone's own
/// frame: x to the right of the screen, y to the top, z out of the screen.
/// Lying flat on a table, face up, it reads (0, 0, 9.81). Raising the right
/// edge makes x positive, raising the top edge makes y positive.

/// A 3-axis sensor sample.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  static const zero = Vec3(0, 0, 0);

  final double x;
  final double y;
  final double z;

  double get magnitude => math.sqrt(x * x + y * y + z * z);

  @override
  bool operator ==(Object other) => other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

/// Exponential low-pass filter for [Vec3] samples.
///
/// [alpha] is the weight of each new sample: 1 passes the signal through, a
/// small value smooths strongly but reacts slowly.
class LowPassFilter {
  LowPassFilter({this.alpha = 0.15}) : assert(alpha > 0 && alpha <= 1);

  final double alpha;
  Vec3? _state;

  Vec3 filter(Vec3 sample) {
    final s = _state;
    if (s == null) return _state = sample;
    return _state = Vec3(
      s.x + alpha * (sample.x - s.x),
      s.y + alpha * (sample.y - s.y),
      s.z + alpha * (sample.z - s.z),
    );
  }

  void reset() => _state = null;
}

/// How the phone is held while levelling.
enum LevelMode {
  /// Lying flat: two axes, shown as a bullseye bubble.
  flat,

  /// Standing on an edge: one axis, shown as a tube level.
  edge,
}

double toDegrees(double radians) => radians * 180 / math.pi;

/// `asin` in degrees for a ratio that may be slightly outside -1..1 from noise.
double asinDegrees(double ratio) => toDegrees(math.asin(ratio.clamp(-1.0, 1.0)));

/// Chooses [LevelMode.flat] or [LevelMode.edge] from gravity.
///
/// There is a dead band between the two so the mode does not flicker near 45
/// degrees: inside it the [previous] mode is kept.
LevelMode classifyMode(Vec3 g, {LevelMode previous = LevelMode.flat}) {
  final m = g.magnitude;
  if (m < 1e-6) return previous;
  final faceOn = g.z.abs() / m;
  if (faceOn > 0.75) return LevelMode.flat;
  if (faceOn < 0.6) return LevelMode.edge;
  return previous;
}

/// Tilt of a flat phone, in degrees, about each axis. Positive [x] means the
/// right edge is higher, positive [y] means the top edge is higher.
class FlatTilt {
  const FlatTilt(this.x, this.y);

  final double x;
  final double y;

  /// Angle between the screen and the horizontal. With sx = sin(x) and
  /// sy = sin(y) being the gravity components, sin(total) = hypot(sx, sy).
  double get total {
    final sx = math.sin(x * math.pi / 180);
    final sy = math.sin(y * math.pi / 180);
    return asinDegrees(math.sqrt(sx * sx + sy * sy));
  }
}

FlatTilt flatTilt(Vec3 g) {
  final m = g.magnitude;
  if (m < 1e-6) return const FlatTilt(0, 0);
  return FlatTilt(asinDegrees(g.x / m), asinDegrees(g.y / m));
}

/// Tilt, in degrees, of whichever screen axis is closest to horizontal when
/// the phone stands on an edge. Positive means the user's right-hand end is
/// higher, whether the phone is held in portrait or landscape.
double edgeTilt(Vec3 g) {
  final m = g.magnitude;
  if (m < 1e-6) return 0;
  if (g.x.abs() >= g.y.abs()) {
    // Landscape: the long axis (y) is the near-horizontal one.
    return -g.x.sign * asinDegrees(g.y / m);
  }
  // Portrait: the short axis (x) is the near-horizontal one.
  return g.y.sign * asinDegrees(g.x / m);
}

/// Angle of the phone's edge in the screen plane, 0..360 degrees.
///
/// 0 when the phone stands upright (top edge up), increasing as it turns
/// clockwise as seen by the user (top edge to the right): 90 in landscape with
/// the top to the right, 180 upside down. Returns null when the phone lies
/// nearly flat, where the in-plane direction of gravity is not defined.
double? inclineAngle(Vec3 g, {double minInPlane = 0.25}) {
  final m = g.magnitude;
  if (m < 1e-6) return null;
  if (math.sqrt(g.x * g.x + g.y * g.y) / m < minInPlane) return null;
  return normalize360(toDegrees(math.atan2(-g.x, g.y)));
}

/// Moves a heading towards [target] along the shortest way round the circle.
/// [alpha] is the weight of the target, as in [LowPassFilter].
double smoothAngle(double? previous, double target, {double alpha = 0.2}) {
  if (previous == null) return normalize360(target);
  return normalize360(previous + alpha * normalize180(target - previous));
}

/// Maps any angle into 0 (inclusive) to 360 (exclusive).
double normalize360(double degrees) {
  final r = degrees % 360;
  final wrapped = r < 0 ? r + 360 : r;
  // A tiny negative remainder rounds up to exactly 360.
  return wrapped >= 360 ? 0 : wrapped;
}

/// Maps any angle into -180 (exclusive) to 180 (inclusive).
double normalize180(double degrees) {
  final r = normalize360(degrees);
  return r > 180 ? r - 360 : r;
}

/// Whether [degrees] is within [tolerance] of zero.
bool isLevel(double degrees, {double tolerance = 0.1}) => degrees.abs() <= tolerance;

/// Cardinal name for a heading, e.g. 92 -> "E", 200 -> "SSW".
String compassPoint(double heading) {
  const names = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
  final i = (normalize360(heading) / 22.5).round() % 16;
  return names[i];
}
