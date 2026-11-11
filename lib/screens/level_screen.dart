import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:theme/theme.dart';

import '../core/angles.dart';
import '../platform/device_channel.dart';
import '../settings/settings_store.dart';
import '../widgets/level_painters.dart';
import '../widgets/live_stream.dart';

/// Bubble level: a two-axis bullseye when flat, a one-axis tube on an edge.
class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key, required this.device, required this.settings});

  final DeviceChannel device;
  final SettingsStore settings;

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  static const _tolerance = 0.1;
  static const _rearmAt = 0.3;

  final _filter = LowPassFilter();
  LevelMode _mode = LevelMode.flat;
  Vec3 _gravity = const Vec3(0, 0, 9.81);

  // Displayed (calibrated) values.
  double _x = 0;
  double _y = 0;
  double _edge = 0;

  bool _held = false;
  bool _tickArmed = true;

  SettingsStore get _settings => widget.settings;

  void _onGravity(Vec3 raw) {
    if (_held) return;
    _gravity = _filter.filter(raw);
    _mode = classifyMode(_gravity, previous: _mode);
    final tilt = flatTilt(_gravity);
    _x = tilt.x - _settings.levelOffsetX;
    _y = tilt.y - _settings.levelOffsetY;
    _edge = edgeTilt(_gravity) - _settings.edgeOffset;
    _updateHaptics();
  }

  bool get _isLevel => _mode == LevelMode.flat ? isLevel(_x, tolerance: _tolerance) && isLevel(_y, tolerance: _tolerance) : isLevel(_edge, tolerance: _tolerance);

  void _updateHaptics() {
    if (_isLevel) {
      if (_tickArmed && _settings.haptics) HapticFeedback.mediumImpact();
      _tickArmed = false;
    } else {
      final worst = _mode == LevelMode.flat ? (_x.abs() > _y.abs() ? _x.abs() : _y.abs()) : _edge.abs();
      if (worst > _rearmAt) _tickArmed = true;
    }
  }

  void _calibrate({bool x = false, bool y = false, bool edge = false}) {
    final tilt = flatTilt(_gravity);
    if (x || y) _settings.setLevelOffsets(x: x ? tilt.x : null, y: y ? tilt.y : null);
    if (edge) _settings.setEdgeOffset(edgeTilt(_gravity));
    setState(() {
      _x = tilt.x - _settings.levelOffsetX;
      _y = tilt.y - _settings.levelOffsetY;
      _edge = edgeTilt(_gravity) - _settings.edgeOffset;
    });
    context.showToast('Calibrated to this surface');
  }

  @override
  Widget build(BuildContext context) {
    return LiveStream<Vec3>(
      open: widget.device.gravity,
      onData: _onGravity,
      builder: (context, latest) {
        if (latest == null) return const Center(child: UiSpinner());
        return OrientationBuilder(
          builder: (context, orientation) {
            final vial = _vial(context);
            final panel = _panel(context);
            final padding = EdgeInsets.fromLTRB(UiSpace.page, UiSpace.md, UiSpace.page, UiSpace.lg);
            if (orientation == Orientation.landscape) {
              return Padding(
                padding: padding,
                child: Row(
                  children: [
                    Expanded(child: vial),
                    const UiGap(UiSpace.xl),
                    SizedBox(width: 280, child: Center(child: SingleChildScrollView(child: panel))),
                  ],
                ),
              );
            }
            return Padding(
              padding: padding,
              child: Column(children: [Expanded(child: vial), const UiGap(UiSpace.lg), panel]),
            );
          },
        );
      },
    );
  }

  Widget _vial(BuildContext context) {
    final colors = context.colors;
    final flat = _mode == LevelMode.flat;
    return Semantics(
      label: flat ? 'Bubble level, x ${_x.toStringAsFixed(1)} degrees, y ${_y.toStringAsFixed(1)} degrees' : 'Tube level, ${_edge.toStringAsFixed(1)} degrees',
      child: CustomPaint(
        painter: flat
            ? BubblePainter(colors: colors, x: _x, y: _y, isLevel: _isLevel)
            : TubePainter(colors: colors, angle: _edge, isLevel: _isLevel),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final flat = _mode == LevelMode.flat;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiStatusPill(
          _isLevel ? 'Level' : (flat ? 'Phone flat: 2 axes' : 'Phone on its edge: 1 axis'),
          status: _isLevel ? UiStatus.success : UiStatus.neutral,
        ),
        const UiGap(UiSpace.md),
        if (flat)
          Row(
            children: [
              Expanded(child: _Readout(label: 'X', degrees: _x)),
              const UiGap(UiSpace.md),
              Expanded(child: _Readout(label: 'Y', degrees: _y)),
            ],
          )
        else
          _Readout(label: 'Tilt', degrees: _edge),
        const UiGap(UiSpace.lg),
        Row(
          children: [
            Expanded(
              child: UiToggleButton(
                _held ? 'Held' : 'Hold',
                icon: _held ? Icons.lock_rounded : Icons.lock_open_rounded,
                selected: _held,
                expand: true,
                onChanged: (v) => setState(() => _held = v),
              ),
            ),
            const UiGap(UiSpace.sm),
            if (flat) ...[
              Expanded(child: UiButton('Zero X', variant: UiButtonVariant.outline, onPressed: () => _calibrate(x: true))),
              const UiGap(UiSpace.sm),
              Expanded(child: UiButton('Zero Y', variant: UiButtonVariant.outline, onPressed: () => _calibrate(y: true))),
            ] else
              Expanded(flex: 2, child: UiButton('Calibrate', variant: UiButtonVariant.outline, onPressed: () => _calibrate(edge: true))),
          ],
        ),
      ],
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.label, required this.degrees});

  final String label;
  final double degrees;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    // Avoid "-0.0".
    final value = degrees.abs() < 0.05 ? 0.0 : degrees;
    return UiCard(
      padding: const EdgeInsets.symmetric(vertical: UiSpace.md, horizontal: UiSpace.lg),
      child: Column(
        children: [
          Text(label, style: text.labelMedium?.copyWith(color: context.colors.textMuted)),
          Text('${value.toStringAsFixed(1)}°', style: text.headlineLarge),
        ],
      ),
    );
  }
}
