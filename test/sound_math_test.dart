import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:levelr/core/sound_math.dart';

void main() {
  group('rmsToDbfs', () {
    test('full scale is 0 dBFS', () {
      expect(rmsToDbfs(1), closeTo(0, 1e-9));
    });

    test('half amplitude is about -6 dBFS', () {
      expect(rmsToDbfs(0.5), closeTo(-6.0206, 1e-3));
    });

    test('each factor of ten is 20 dB', () {
      expect(rmsToDbfs(0.1), closeTo(-20, 1e-9));
      expect(rmsToDbfs(0.01), closeTo(-40, 1e-9));
    });

    test('silence is floored instead of -infinity', () {
      expect(rmsToDbfs(0), floorDbfs);
      expect(rmsToDbfs(-1), floorDbfs);
      expect(rmsToDbfs(1e-12), floorDbfs);
    });
  });

  group('dbfsToSpl', () {
    test('adds the reference level', () {
      expect(dbfsToSpl(-30), closeTo(referenceSpl - 30, 1e-9));
    });

    test('applies the user offset', () {
      expect(dbfsToSpl(-30, offset: 5), closeTo(referenceSpl - 25, 1e-9));
      expect(dbfsToSpl(-30, offset: -5), closeTo(referenceSpl - 35, 1e-9));
    });

    test('clamps to the displayable range', () {
      expect(dbfsToSpl(-120), 0);
      expect(dbfsToSpl(0, offset: 100), maxSpl);
    });
  });

  test('rmsToSpl chains both steps', () {
    expect(rmsToSpl(0.1, offset: 2), closeTo(referenceSpl - 20 + 2, 1e-9));
  });

  group('rmsOf', () {
    test('of a constant is its magnitude', () {
      expect(rmsOf([0.5, 0.5, -0.5, -0.5]), closeTo(0.5, 1e-12));
    });

    test('of a full-scale sine is 1/sqrt(2)', () {
      final samples = [for (var i = 0; i < 1000; i++) math.sin(2 * math.pi * i / 100)];
      expect(rmsOf(samples), closeTo(1 / math.sqrt2, 1e-3));
    });

    test('of nothing is zero', () {
      expect(rmsOf(const []), 0);
    });
  });

  group('LoudnessBand', () {
    test('maps levels to labels', () {
      expect(LoudnessBand.of(20), LoudnessBand.quiet);
      expect(LoudnessBand.of(39.9), LoudnessBand.quiet);
      expect(LoudnessBand.of(40), LoudnessBand.conversation);
      expect(LoudnessBand.of(70), LoudnessBand.traffic);
      expect(LoudnessBand.of(90), LoudnessBand.loud);
      expect(LoudnessBand.of(110), LoudnessBand.harmful);
      expect(LoudnessBand.of(maxSpl), LoudnessBand.harmful);
    });

    test('bands cover 0 to max without gaps', () {
      for (var i = 1; i < LoudnessBand.values.length; i++) {
        expect(LoudnessBand.values[i].fromDb, LoudnessBand.values[i - 1].toDb);
      }
      expect(LoudnessBand.values.first.fromDb, 0);
    });
  });

  group('SoundStats', () {
    test('tracks current, min, max and average', () {
      final s = SoundStats();
      expect(s.average, isNull);
      for (final v in [40.0, 60.0, 50.0]) {
        s.add(v);
      }
      expect(s.current, 50);
      expect(s.min, 40);
      expect(s.max, 60);
      expect(s.average, 50);
      expect(s.count, 3);
    });

    test('reset clears everything', () {
      final s = SoundStats()..add(70);
      s.reset();
      expect(s.current, isNull);
      expect(s.min, isNull);
      expect(s.max, isNull);
      expect(s.average, isNull);
    });
  });

  test('RollingWindow keeps only the newest values', () {
    final w = RollingWindow(3);
    for (var i = 1; i <= 5; i++) {
      w.add(i.toDouble());
    }
    expect(w.values, [3, 4, 5]);
    w.clear();
    expect(w.values, isEmpty);
  });
}
