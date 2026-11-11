import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/angles.dart';
import '../platform/device_channel.dart';
import '../widgets/dial_painters.dart';
import '../widgets/live_stream.dart';

/// Inclinometer: the angle of the phone's edge, 0 to 360 degrees, with an
/// optional relative mode that measures from a zero you set.
class AngleScreen extends StatefulWidget {
  const AngleScreen({super.key, required this.device});

  final DeviceChannel device;

  @override
  State<AngleScreen> createState() => _AngleScreenState();
}

enum _AngleMode { absolute, relative }

class _AngleScreenState extends State<AngleScreen> {
  final _filter = LowPassFilter(alpha: 0.2);
  _AngleMode _mode = _AngleMode.absolute;

  /// Latest valid absolute angle, or null while the phone lies flat.
  double? _angle;
  double? _lastValid;
  double _zero = 0;
  bool _held = false;

  void _onGravity(Vec3 raw) {
    if (_held) return;
    final a = inclineAngle(_filter.filter(raw));
    _angle = a;
    if (a != null) _lastValid = a;
  }

  /// The value shown: 0..360 absolute, or -180..180 from the zero.
  double get _shown {
    final a = _lastValid ?? 0;
    return _mode == _AngleMode.absolute ? a : normalize180(a - _zero);
  }

  void _setZero() {
    final a = _lastValid;
    if (a == null) return;
    setState(() {
      _zero = a;
      _mode = _AngleMode.relative;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    return LiveStream<Vec3>(
      open: widget.device.gravity,
      onData: _onGravity,
      builder: (context, latest) {
        if (latest == null) return const Center(child: UiSpinner());
        final relative = _mode == _AngleMode.relative;
        final valid = _angle != null || _held;
        final shown = _shown;
        final needle = relative ? normalize360(shown) : shown;
        return OrientationBuilder(
          builder: (context, orientation) {
            final dial = GestureDetector(
              onTap: _setZero,
              child: Semantics(
                label: 'Angle dial. Tap to set zero.',
                child: CustomPaint(
                  painter: ProtractorPainter(
                    colors: colors,
                    labelStyle: text.labelSmall!.copyWith(color: colors.textMuted),
                    angle: needle,
                    active: valid,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            );
            final panel = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    '${(shown.abs() < 0.05 ? 0.0 : shown).toStringAsFixed(1)}°',
                    style: text.displayLarge?.copyWith(color: valid ? colors.text : colors.textDisabled),
                  ),
                ),
                Center(
                  child: Text(
                    valid
                        ? (relative ? 'From your zero (${_zero.toStringAsFixed(1)}° absolute)' : 'Angle of the phone edge')
                        : 'Stand the phone on its edge or hold it upright',
                    style: text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const UiGap(UiSpace.lg),
                UiSegmentedControl<_AngleMode>(
                  [
                    const UiSegment(_AngleMode.absolute, label: 'Absolute'),
                    const UiSegment(_AngleMode.relative, label: 'Relative'),
                  ],
                  value: _mode,
                  expand: true,
                  onChanged: (m) => setState(() => _mode = m),
                ),
                const UiGap(UiSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: UiButton(
                        relative ? 'Set zero here' : 'Measure from here',
                        icon: Icons.flag_rounded,
                        onPressed: _lastValid == null ? null : _setZero,
                      ),
                    ),
                    const UiGap(UiSpace.sm),
                    UiToggleButton.icon(
                      _held ? Icons.lock_rounded : Icons.lock_open_rounded,
                      tooltip: _held ? 'Release hold' : 'Hold value',
                      selected: _held,
                      onChanged: (v) => setState(() => _held = v),
                    ),
                  ],
                ),
              ],
            );
            const padding = EdgeInsets.fromLTRB(UiSpace.page, UiSpace.md, UiSpace.page, UiSpace.lg);
            if (orientation == Orientation.landscape) {
              return Padding(
                padding: padding,
                child: Row(
                  children: [
                    Expanded(child: dial),
                    const UiGap(UiSpace.xl),
                    SizedBox(width: 300, child: Center(child: SingleChildScrollView(child: panel))),
                  ],
                ),
              );
            }
            return Padding(
              padding: padding,
              child: Column(children: [panel, const UiGap(UiSpace.lg), Expanded(child: dial)]),
            );
          },
        );
      },
    );
  }
}
