import 'dart:async';

import 'package:flutter/services.dart';

import '../core/angles.dart';
import '../core/ruler_math.dart';

const _base = 'com.itsash.levelr';

/// A sensor or the microphone cannot be used on this device.
class SensorUnavailable implements Exception {
  const SensorUnavailable(this.message, {this.permissionDenied = false});

  final String message;

  /// True when the cause is a missing microphone permission.
  final bool permissionDenied;

  @override
  String toString() => message;
}

/// Physical display size info, from Android's `DisplayMetrics`.
class DeviceMetrics {
  const DeviceMetrics({required this.xdpi, required this.ydpi});

  /// Used when the native side cannot answer.
  static const fallback = DeviceMetrics(xdpi: fallbackDpi, ydpi: fallbackDpi);

  final double xdpi;
  final double ydpi;

  bool get isReliable => isPlausibleDpi(xdpi) && isPlausibleDpi(ydpi);
}

/// One compass reading.
class Heading {
  const Heading(this.degrees, this.accuracy);

  /// Degrees clockwise from magnetic north, 0..360.
  final double degrees;

  /// Android sensor accuracy: 0 unreliable, 1 low, 2 medium, 3 high.
  final int accuracy;

  bool get needsCalibration => accuracy < 2;
}

/// Access to the native sensors, the microphone and display info.
///
/// Every stream starts its native sensor when listened to and releases it
/// when cancelled.
class DeviceChannel {
  const DeviceChannel();

  static const _device = MethodChannel('$_base/device');
  static const _gravity = EventChannel('$_base/gravity');
  static const _heading = EventChannel('$_base/heading');
  static const _mic = EventChannel('$_base/mic');

  /// Gravity in the phone's frame, m/s2.
  Stream<Vec3> gravity() => _gravity.receiveBroadcastStream().map((e) {
        final v = (e as List).cast<num>();
        return Vec3(v[0].toDouble(), v[1].toDouble(), v[2].toDouble());
      }).transform(_mapErrors('This phone has no accelerometer.'));

  /// Compass heading from the rotation vector sensor.
  Stream<Heading> heading() => _heading.receiveBroadcastStream().map((e) {
        final v = (e as List).cast<num>();
        return Heading(v[0].toDouble(), v[1].toInt());
      }).transform(_mapErrors('This phone has no compass sensor.'));

  /// RMS level (0..1) of each ~125 ms microphone window. Needs the
  /// microphone permission to be granted first.
  Stream<double> micRms() => _mic
      .receiveBroadcastStream()
      .map((e) => (e as num).toDouble())
      .transform(_mapErrors('The microphone is not available.'));

  Future<DeviceMetrics> displayMetrics() async {
    try {
      final m = await _device.invokeMapMethod<String, double>('displayMetrics');
      if (m == null) return DeviceMetrics.fallback;
      return DeviceMetrics(xdpi: m['xdpi'] ?? fallbackDpi, ydpi: m['ydpi'] ?? fallbackDpi);
    } on PlatformException {
      return DeviceMetrics.fallback;
    } on MissingPluginException {
      return DeviceMetrics.fallback;
    }
  }

  /// Keeps the screen on while Levelr is open.
  Future<void> keepScreenOn(bool on) async {
    try {
      await _device.invokeMethod<void>('keepScreenOn', on);
    } on PlatformException {
      // Best effort: the screen may simply turn off.
    } on MissingPluginException {
      // No native side (tests).
    }
  }

  StreamTransformer<T, T> _mapErrors<T>(String unavailable) => StreamTransformer.fromHandlers(
        handleData: (data, sink) => sink.add(data),
        handleError: (error, stack, sink) {
          if (error is PlatformException) {
            final denied = error.code == 'no_permission';
            sink.addError(SensorUnavailable(denied ? 'Microphone permission is needed.' : unavailable, permissionDenied: denied), stack);
          } else if (error is MissingPluginException) {
            sink.addError(SensorUnavailable(unavailable), stack);
          } else {
            sink.addError(error, stack);
          }
        },
      );
}
