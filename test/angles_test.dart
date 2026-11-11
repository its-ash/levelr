import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:levelr/core/angles.dart';

const g = 9.81;

/// Gravity for a phone whose screen is tilted [deg] about an axis.
Vec3 tiltedX(double deg) => Vec3(g * math.sin(deg * math.pi / 180), 0, g * math.cos(deg * math.pi / 180));
Vec3 tiltedY(double deg) => Vec3(0, g * math.sin(deg * math.pi / 180), g * math.cos(deg * math.pi / 180));

void main() {
  group('flatTilt', () {
    test('is zero when flat', () {
      final t = flatTilt(const Vec3(0, 0, g));
      expect(t.x, closeTo(0, 1e-9));
      expect(t.y, closeTo(0, 1e-9));
      expect(t.total, closeTo(0, 1e-6));
    });

    test('right edge up is positive x', () {
      expect(flatTilt(tiltedX(3)).x, closeTo(3, 1e-9));
      expect(flatTilt(tiltedX(-3)).x, closeTo(-3, 1e-9));
    });

    test('top edge up is positive y', () {
      expect(flatTilt(tiltedY(2.5)).y, closeTo(2.5, 1e-9));
    });

    test('total combines both axes', () {
      // 45 degrees on one axis is 45 degrees in total.
      expect(flatTilt(tiltedX(45)).total, closeTo(45, 1e-6));
    });

    test('a zero vector does not divide by zero', () {
      final t = flatTilt(Vec3.zero);
      expect(t.x, 0);
      expect(t.y, 0);
    });

    test('noise above 1g stays finite', () {
      expect(flatTilt(const Vec3(10, 0, 0)).x.isFinite, isTrue);
    });
  });

  group('classifyMode', () {
    test('flat when lying down', () {
      expect(classifyMode(const Vec3(0, 0, g), previous: LevelMode.edge), LevelMode.flat);
    });

    test('edge when upright', () {
      expect(classifyMode(const Vec3(0, g, 0)), LevelMode.edge);
      expect(classifyMode(const Vec3(g, 0, 0)), LevelMode.edge);
    });

    test('keeps the previous mode inside the dead band', () {
      // About 50 degrees from flat: |z|/g is about 0.64.
      final v = tiltedY(50);
      expect(classifyMode(v, previous: LevelMode.flat), LevelMode.flat);
      expect(classifyMode(v, previous: LevelMode.edge), LevelMode.edge);
    });

    test('face down counts as flat', () {
      expect(classifyMode(const Vec3(0, 0, -g)), LevelMode.flat);
    });
  });

  group('edgeTilt', () {
    test('is zero when exactly upright or on its side', () {
      expect(edgeTilt(const Vec3(0, g, 0)), closeTo(0, 1e-9));
      expect(edgeTilt(const Vec3(g, 0, 0)), closeTo(0, 1e-9));
      expect(edgeTilt(const Vec3(-g, 0, 0)), closeTo(0, 1e-9));
    });

    test('portrait: right edge higher is positive', () {
      final a = 2 * math.pi / 180;
      expect(edgeTilt(Vec3(g * math.sin(a), g * math.cos(a), 0)), closeTo(2, 1e-9));
    });

    test('portrait upside down keeps the user-relative sign', () {
      final a = 2 * math.pi / 180;
      // Device x negative = the user's right is higher when upside down.
      expect(edgeTilt(Vec3(-g * math.sin(a), -g * math.cos(a), 0)), closeTo(2, 1e-9));
    });

    test('landscape signs agree for both rotations', () {
      final a = 4 * math.pi / 180;
      // Top to the left (x > 0): the user's right is the device -y end.
      expect(edgeTilt(Vec3(g * math.cos(a), -g * math.sin(a), 0)), closeTo(4, 1e-9));
      // Top to the right (x < 0): the user's right is the device +y end.
      expect(edgeTilt(Vec3(-g * math.cos(a), g * math.sin(a), 0)), closeTo(4, 1e-9));
    });
  });

  group('inclineAngle', () {
    test('0 upright, 90 top to the right, 180 upside down, 270 top to the left', () {
      expect(inclineAngle(const Vec3(0, g, 0)), closeTo(0, 1e-9));
      expect(inclineAngle(const Vec3(-g, 0, 0)), closeTo(90, 1e-9));
      expect(inclineAngle(const Vec3(0, -g, 0)), closeTo(180, 1e-9));
      expect(inclineAngle(const Vec3(g, 0, 0)), closeTo(270, 1e-9));
    });

    test('is always inside 0..360', () {
      for (var d = -720; d <= 720; d += 7) {
        final r = d * math.pi / 180;
        final a = inclineAngle(Vec3(g * math.sin(r), g * math.cos(r), 0))!;
        expect(a, inInclusiveRange(0, 360));
        expect(a, lessThan(360));
      }
    });

    test('is undefined when the phone lies flat', () {
      expect(inclineAngle(const Vec3(0.1, 0.1, g)), isNull);
    });
  });

  group('angle normalisation', () {
    test('normalize360', () {
      expect(normalize360(-10), 350);
      expect(normalize360(370), 10);
      expect(normalize360(360), 0);
      expect(normalize360(0), 0);
    });

    test('normalize180', () {
      expect(normalize180(190), -170);
      expect(normalize180(-190), 170);
      expect(normalize180(180), 180);
      expect(normalize180(-180), 180);
      expect(normalize180(45), 45);
    });

    test('relative difference wraps across zero', () {
      // From a zero of 350 to 10 degrees is +20, not -340.
      expect(normalize180(10 - 350), 20);
    });
  });

  group('smoothAngle', () {
    test('starts at the first value', () {
      expect(smoothAngle(null, 123), 123);
    });

    test('takes the short way across north', () {
      final next = smoothAngle(350, 10, alpha: 0.5);
      expect(next, closeTo(0, 1e-9));
    });

    test('converges', () {
      double? h;
      for (var i = 0; i < 60; i++) {
        h = smoothAngle(h ?? 0, 90, alpha: 0.2);
      }
      expect(h, closeTo(90, 0.1));
    });
  });

  group('LowPassFilter', () {
    test('first sample passes through', () {
      final f = LowPassFilter();
      expect(f.filter(const Vec3(1, 2, 3)), const Vec3(1, 2, 3));
    });

    test('moves a fraction towards each new sample', () {
      final f = LowPassFilter(alpha: 0.5)..filter(const Vec3(0, 0, 0));
      expect(f.filter(const Vec3(10, 0, 0)).x, closeTo(5, 1e-9));
      expect(f.filter(const Vec3(10, 0, 0)).x, closeTo(7.5, 1e-9));
    });

    test('reset forgets the state', () {
      final f = LowPassFilter()..filter(const Vec3(5, 5, 5));
      f.reset();
      expect(f.filter(const Vec3(1, 1, 1)), const Vec3(1, 1, 1));
    });

    test('smooths noise around the true value', () {
      final f = LowPassFilter(alpha: 0.1);
      var out = Vec3.zero;
      for (var i = 0; i < 200; i++) {
        out = f.filter(Vec3(i.isEven ? 1.0 : -1.0, 0, g));
      }
      expect(out.x.abs(), lessThan(0.15));
      expect(out.z, closeTo(g, 0.01));
    });
  });

  group('isLevel', () {
    test('uses a 0.1 degree default tolerance', () {
      expect(isLevel(0.1), isTrue);
      expect(isLevel(-0.1), isTrue);
      expect(isLevel(0.11), isFalse);
    });
  });

  test('compassPoint', () {
    expect(compassPoint(0), 'N');
    expect(compassPoint(359), 'N');
    expect(compassPoint(90), 'E');
    expect(compassPoint(200), 'SSW');
    expect(compassPoint(315), 'NW');
  });
}
