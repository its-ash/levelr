import 'dart:math' as math;

/// Pure math for the sound meter.
///
/// A phone microphone is not a measurement microphone, so the result is an
/// approximation of dB SPL. Full scale (0 dBFS) is assumed to be
/// [referenceSpl] dB SPL; users can correct the rest with an offset.

/// Assumed dB SPL at digital full scale for a typical phone microphone.
const double referenceSpl = 90;

/// Quietest level reported, in dBFS, so silence does not become -infinity.
const double floorDbfs = -120;

/// Highest SPL reported.
const double maxSpl = 130;

/// Converts an RMS amplitude (0..1, full scale = 1) to dBFS.
double rmsToDbfs(double rms) {
  if (rms <= 0) return floorDbfs;
  return math.max(floorDbfs, 20 * math.log(rms) / math.ln10);
}

/// Converts dBFS to an approximate dB SPL, applying a user [offset] in dB.
/// The result is kept between 0 and [maxSpl].
double dbfsToSpl(double dbfs, {double offset = 0}) =>
    (dbfs + referenceSpl + offset).clamp(0.0, maxSpl).toDouble();

/// RMS amplitude straight to approximate dB SPL.
double rmsToSpl(double rms, {double offset = 0}) => dbfsToSpl(rmsToDbfs(rms), offset: offset);

/// Root mean square of 16-bit PCM style samples scaled to -1..1.
double rmsOf(List<double> samples) {
  if (samples.isEmpty) return 0;
  var sum = 0.0;
  for (final s in samples) {
    sum += s * s;
  }
  return math.sqrt(sum / samples.length);
}

/// Everyday loudness bands.
enum LoudnessBand {
  quiet('Quiet room', 0, 40),
  conversation('Conversation', 40, 65),
  traffic('Busy traffic', 65, 85),
  loud('Loud', 85, 100),
  harmful('Hearing risk', 100, maxSpl + 1);

  const LoudnessBand(this.label, this.fromDb, this.toDb);

  final String label;

  /// Inclusive lower bound, exclusive upper bound, in dB.
  final double fromDb;
  final double toDb;

  static LoudnessBand of(double db) {
    for (final band in values) {
      if (db < band.toDb) return band;
    }
    return harmful;
  }
}

/// Running statistics for one measuring session.
class SoundStats {
  double? current;
  double? min;
  double? max;
  double _sum = 0;
  int _count = 0;

  int get count => _count;

  double? get average => _count == 0 ? null : _sum / _count;

  void add(double db) {
    current = db;
    min = min == null ? db : math.min(min!, db);
    max = max == null ? db : math.max(max!, db);
    _sum += db;
    _count++;
  }

  void reset() {
    current = null;
    min = null;
    max = null;
    _sum = 0;
    _count = 0;
  }
}

/// Fixed-size history of the most recent values, for the live chart.
class RollingWindow {
  RollingWindow(this.capacity) : assert(capacity > 1);

  final int capacity;
  final List<double> _values = [];

  List<double> get values => List.unmodifiable(_values);

  void add(double v) {
    _values.add(v);
    if (_values.length > capacity) _values.removeAt(0);
  }

  void clear() => _values.clear();
}
