import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ruler_math.dart';

/// Unit system for lengths.
enum UnitSystem { metric, imperial }

/// User settings and saved calibrations, persisted in `shared_preferences`.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs) {
    units = _prefs.getString(_kUnits) == UnitSystem.imperial.name ? UnitSystem.imperial : UnitSystem.metric;
    haptics = _prefs.getBool(_kHaptics) ?? true;
    levelOffsetX = _prefs.getDouble(_kOffsetX) ?? 0;
    levelOffsetY = _prefs.getDouble(_kOffsetY) ?? 0;
    edgeOffset = _prefs.getDouble(_kOffsetEdge) ?? 0;
    rulerCorrection = (_prefs.getDouble(_kRuler) ?? 1).clamp(minCorrection, maxCorrection).toDouble();
    soundOffset = _prefs.getDouble(_kSound) ?? 0;
  }

  static const _kUnits = 'units';
  static const _kHaptics = 'haptics';
  static const _kOffsetX = 'level_offset_x';
  static const _kOffsetY = 'level_offset_y';
  static const _kOffsetEdge = 'level_offset_edge';
  static const _kRuler = 'ruler_correction';
  static const _kSound = 'sound_offset';

  final SharedPreferences _prefs;

  static Future<SettingsStore> load() async => SettingsStore._(await SharedPreferences.getInstance());

  late UnitSystem units;
  late bool haptics;

  /// Degrees to subtract from the flat-level X / Y readings (calibration).
  late double levelOffsetX;
  late double levelOffsetY;

  /// Degrees to subtract from the edge (tube) level reading.
  late double edgeOffset;

  /// Multiplier for the ruler scale, from the bank card calibration.
  late double rulerCorrection;

  /// Decibels added to the sound meter reading.
  late double soundOffset;

  bool get isMetric => units == UnitSystem.metric;

  bool get hasCalibration =>
      levelOffsetX != 0 || levelOffsetY != 0 || edgeOffset != 0 || rulerCorrection != 1 || soundOffset != 0;

  void setUnits(UnitSystem value) {
    units = value;
    _prefs.setString(_kUnits, value.name);
    notifyListeners();
  }

  void setHaptics(bool value) {
    haptics = value;
    _prefs.setBool(_kHaptics, value);
    notifyListeners();
  }

  void setLevelOffsets({double? x, double? y}) {
    if (x != null) {
      levelOffsetX = x;
      _prefs.setDouble(_kOffsetX, x);
    }
    if (y != null) {
      levelOffsetY = y;
      _prefs.setDouble(_kOffsetY, y);
    }
    notifyListeners();
  }

  void setEdgeOffset(double value) {
    edgeOffset = value;
    _prefs.setDouble(_kOffsetEdge, value);
    notifyListeners();
  }

  void setRulerCorrection(double value) {
    rulerCorrection = value.clamp(minCorrection, maxCorrection).toDouble();
    _prefs.setDouble(_kRuler, rulerCorrection);
    notifyListeners();
  }

  void setSoundOffset(double value) {
    soundOffset = value.clamp(-40.0, 40.0).toDouble();
    _prefs.setDouble(_kSound, soundOffset);
    notifyListeners();
  }

  /// Clears the level, ruler and sound calibrations. Units and haptics stay.
  void resetCalibrations() {
    levelOffsetX = 0;
    levelOffsetY = 0;
    edgeOffset = 0;
    rulerCorrection = 1;
    soundOffset = 0;
    for (final key in [_kOffsetX, _kOffsetY, _kOffsetEdge, _kRuler, _kSound]) {
      _prefs.remove(key);
    }
    notifyListeners();
  }
}
