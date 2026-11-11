import 'package:flutter_test/flutter_test.dart';
import 'package:levelr/core/ruler_math.dart';

void main() {
  group('logicalPxPerMm', () {
    test('converts DPI to logical pixels per millimetre', () {
      // 254 dpi = 10 physical px per mm; at a pixel ratio of 2 that is 5 logical px.
      expect(logicalPxPerMm(dpi: 254, devicePixelRatio: 2), closeTo(5, 1e-9));
    });

    test('one inch is dpi / ratio logical pixels', () {
      const dpi = 420.0;
      const dpr = 2.625;
      final px = mmToPx(mmPerInch, logicalPxPerMm(dpi: dpi, devicePixelRatio: dpr));
      expect(px, closeTo(dpi / dpr, 1e-9));
    });

    test('applies the correction factor', () {
      final base = logicalPxPerMm(dpi: 400, devicePixelRatio: 2.5);
      expect(logicalPxPerMm(dpi: 400, devicePixelRatio: 2.5, correction: 1.1), closeTo(base * 1.1, 1e-9));
    });

    test('falls back to 160 dpi for an implausible value', () {
      final expected = logicalPxPerMm(dpi: fallbackDpi, devicePixelRatio: 1);
      expect(logicalPxPerMm(dpi: 0, devicePixelRatio: 1), expected);
      expect(logicalPxPerMm(dpi: double.nan, devicePixelRatio: 1), expected);
      expect(logicalPxPerMm(dpi: 99999, devicePixelRatio: 1), expected);
    });
  });

  test('isPlausibleDpi', () {
    expect(isPlausibleDpi(null), isFalse);
    expect(isPlausibleDpi(160), isTrue);
    expect(isPlausibleDpi(440), isTrue);
    expect(isPlausibleDpi(20), isFalse);
  });

  test('pixel and millimetre conversions are inverse', () {
    const scale = 6.3;
    expect(pxToMm(mmToPx(42.5, scale), scale), closeTo(42.5, 1e-9));
  });

  test('inch and millimetre conversions', () {
    expect(mmToInches(25.4), 1);
    expect(inchesToMm(2), closeTo(50.8, 1e-9));
    expect(mmToInches(bankCardWidthMm), closeTo(3.37, 0.005));
  });

  group('calibratedCorrection', () {
    test('no change when the ruler already reads the card correctly', () {
      expect(calibratedCorrection(currentCorrection: 1, measuredMm: bankCardWidthMm), closeTo(1, 1e-12));
    });

    test('a ruler that reads too long gets a bigger scale', () {
      // Reads 90 mm for an 85.6 mm card: pixels per mm were too small.
      final c = calibratedCorrection(currentCorrection: 1, measuredMm: 90);
      expect(c, closeTo(90 / bankCardWidthMm, 1e-12));
      expect(c, greaterThan(1));
    });

    test('a ruler that reads too short gets a smaller scale', () {
      expect(calibratedCorrection(currentCorrection: 1, measuredMm: 80), lessThan(1));
    });

    test('the corrected ruler then reads the card exactly', () {
      const dpi = 410.0;
      const dpr = 2.75;
      // Pretend the real screen is 3% denser than reported.
      final truePxPerMm = logicalPxPerMm(dpi: dpi * 1.03, devicePixelRatio: dpr);
      final reportedPxPerMm = logicalPxPerMm(dpi: dpi, devicePixelRatio: dpr);
      final cardPx = mmToPx(bankCardWidthMm, truePxPerMm);
      final measured = pxToMm(cardPx, reportedPxPerMm);

      final correction = calibratedCorrection(currentCorrection: 1, measuredMm: measured);
      final fixed = logicalPxPerMm(dpi: dpi, devicePixelRatio: dpr, correction: correction);
      expect(pxToMm(cardPx, fixed), closeTo(bankCardWidthMm, 1e-9));
    });

    test('calibrating again builds on the current factor', () {
      final first = calibratedCorrection(currentCorrection: 1, measuredMm: 90);
      final second = calibratedCorrection(currentCorrection: first, measuredMm: 86.6);
      expect(second, closeTo(first * 86.6 / bankCardWidthMm, 1e-12));
    });

    test('rejects absurd results and bad input', () {
      expect(calibratedCorrection(currentCorrection: 1, measuredMm: 1000), maxCorrection);
      expect(calibratedCorrection(currentCorrection: 1, measuredMm: 1), minCorrection);
      expect(calibratedCorrection(currentCorrection: 1.2, measuredMm: 0), 1.2);
    });
  });

  test('formatting', () {
    expect(formatCentimetres(85.6), '8.56 cm');
    expect(formatInches(25.4), '1.00 in');
  });
}
