import 'package:flutter_test/flutter_test.dart';
import 'package:levelr/core/ruler_math.dart';
import 'package:levelr/settings/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults', () async {
    final s = await SettingsStore.load();
    expect(s.units, UnitSystem.metric);
    expect(s.haptics, isTrue);
    expect(s.rulerCorrection, 1);
    expect(s.soundOffset, 0);
    expect(s.hasCalibration, isFalse);
  });

  test('values persist across loads', () async {
    final s = await SettingsStore.load();
    s.setUnits(UnitSystem.imperial);
    s.setHaptics(false);
    s.setLevelOffsets(x: 0.4, y: -0.2);
    s.setEdgeOffset(0.3);
    s.setRulerCorrection(1.04);
    s.setSoundOffset(-3.5);

    final again = await SettingsStore.load();
    expect(again.units, UnitSystem.imperial);
    expect(again.haptics, isFalse);
    expect(again.levelOffsetX, 0.4);
    expect(again.levelOffsetY, -0.2);
    expect(again.edgeOffset, 0.3);
    expect(again.rulerCorrection, 1.04);
    expect(again.soundOffset, -3.5);
    expect(again.hasCalibration, isTrue);
  });

  test('setting one level axis keeps the other', () async {
    final s = await SettingsStore.load();
    s.setLevelOffsets(x: 1, y: 2);
    s.setLevelOffsets(x: 3);
    expect(s.levelOffsetX, 3);
    expect(s.levelOffsetY, 2);
  });

  test('ruler correction and sound offset are clamped', () async {
    final s = await SettingsStore.load();
    s.setRulerCorrection(50);
    expect(s.rulerCorrection, maxCorrection);
    s.setSoundOffset(-500);
    expect(s.soundOffset, -40);
  });

  test('resetCalibrations clears calibrations but keeps preferences', () async {
    final s = await SettingsStore.load();
    s.setUnits(UnitSystem.imperial);
    s.setHaptics(false);
    s.setLevelOffsets(x: 1, y: 1);
    s.setEdgeOffset(1);
    s.setRulerCorrection(1.2);
    s.setSoundOffset(4);

    var notified = 0;
    s.addListener(() => notified++);
    s.resetCalibrations();

    expect(notified, 1);
    expect(s.hasCalibration, isFalse);
    expect(s.units, UnitSystem.imperial);
    expect(s.haptics, isFalse);

    final again = await SettingsStore.load();
    expect(again.hasCalibration, isFalse);
    expect(again.units, UnitSystem.imperial);
  });
}
