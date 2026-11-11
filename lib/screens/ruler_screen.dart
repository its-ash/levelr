import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/ruler_math.dart';
import '../platform/device_channel.dart';
import '../settings/settings_store.dart';
import '../widgets/ruler_painter.dart';

/// On-screen ruler at true scale, with draggable markers and a bank card
/// calibration step.
class RulerScreen extends StatefulWidget {
  const RulerScreen({super.key, required this.device, required this.settings});

  final DeviceChannel device;
  final SettingsStore settings;

  @override
  State<RulerScreen> createState() => _RulerScreenState();
}

class _RulerScreenState extends State<RulerScreen> {
  late final Future<DeviceMetrics> _metrics = widget.device.displayMetrics();

  double _markerA = 20;
  double _markerB = 70;
  bool _calibrating = false;

  /// Which marker the current drag moves: 0 = A, 1 = B.
  int? _dragging;

  SettingsStore get _settings => widget.settings;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettings);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  void _startCalibration() {
    setState(() {
      _calibrating = true;
      _markerA = 0;
      _markerB = bankCardWidthMm;
    });
  }

  void _applyCalibration() {
    final measured = (_markerB - _markerA).abs();
    _settings.setRulerCorrection(
      calibratedCorrection(currentCorrection: _settings.rulerCorrection, measuredMm: measured),
    );
    setState(() {
      _calibrating = false;
      _markerA = 20;
      _markerB = 70;
    });
    context.showToast('Ruler calibrated');
  }

  void _dragStart(double y, double pxPerMm) {
    if (_calibrating) {
      _dragging = 1;
      return;
    }
    final a = (mmToPx(_markerA, pxPerMm) - y).abs();
    final b = (mmToPx(_markerB, pxPerMm) - y).abs();
    _dragging = a < b ? 0 : 1;
  }

  void _dragUpdate(double y, double pxPerMm, double maxMm) {
    final mm = pxToMm(y, pxPerMm).clamp(0.0, maxMm).toDouble();
    setState(() {
      if (_dragging == 0) {
        _markerA = mm;
      } else {
        _markerB = mm;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeviceMetrics>(
      future: _metrics,
      builder: (context, snapshot) {
        final metrics = snapshot.data;
        if (metrics == null) return const Center(child: UiSpinner());
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final pxPerMm = logicalPxPerMm(dpi: metrics.ydpi, devicePixelRatio: dpr, correction: _settings.rulerCorrection);
        final colors = context.colors;
        final text = context.text;
        return LayoutBuilder(
          builder: (context, box) {
            final maxMm = box.maxHeight / pxPerMm;
            final a = _markerA.clamp(0.0, maxMm).toDouble();
            final b = _markerB.clamp(0.0, maxMm).toDouble();
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (d) => _dragStart(d.localPosition.dy, pxPerMm),
                    onVerticalDragUpdate: (d) => _dragUpdate(d.localPosition.dy, pxPerMm, maxMm),
                    child: CustomPaint(
                      painter: RulerPainter(
                        colors: colors,
                        labelStyle: text.labelMedium!.copyWith(color: colors.text),
                        pxPerMm: pxPerMm,
                        markerA: a,
                        markerB: b,
                        showA: !_calibrating,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 64,
                  right: 64,
                  bottom: UiSpace.lg,
                  child: _calibrating
                      ? _CalibrationCard(
                          reading: (b - a).abs(),
                          onCancel: () => setState(() {
                            _calibrating = false;
                            _markerA = 20;
                            _markerB = 70;
                          }),
                          onApply: _applyCalibration,
                        )
                      : _ReadoutCard(
                          mm: (b - a).abs(),
                          metric: _settings.isMetric,
                          calibrated: _settings.rulerCorrection != 1,
                          reliable: metrics.isReliable,
                          onCalibrate: _startCalibration,
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ReadoutCard extends StatelessWidget {
  const _ReadoutCard({
    required this.mm,
    required this.metric,
    required this.calibrated,
    required this.reliable,
    required this.onCalibrate,
  });

  final double mm;
  final bool metric;
  final bool calibrated;
  final bool reliable;
  final VoidCallback onCalibrate;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final primary = metric ? formatCentimetres(mm) : formatInches(mm);
    final secondary = metric ? formatInches(mm) : formatCentimetres(mm);
    return UiCard(
      variant: UiCardVariant.elevated,
      padding: const EdgeInsets.all(UiSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(primary, style: text.headlineLarge),
          Text(secondary, style: text.bodySmall),
          const UiGap(UiSpace.sm),
          if (!reliable && !calibrated) ...[
            Text(
              'This phone does not report its screen size. Calibrate with a bank card.',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const UiGap(UiSpace.sm),
          ],
          UiButton(
            calibrated ? 'Recalibrate' : 'Calibrate with a card',
            icon: Icons.credit_card_rounded,
            variant: UiButtonVariant.soft,
            size: UiSize.sm,
            onPressed: onCalibrate,
          ),
        ],
      ),
    );
  }
}

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({required this.reading, required this.onCancel, required this.onApply});

  final double reading;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return UiCard(
      variant: UiCardVariant.elevated,
      padding: const EdgeInsets.all(UiSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Lay a bank card along the ruler with its short end on the 0 line. '
            'Drag the line to the other end of the card.',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
          const UiGap(UiSpace.sm),
          Text('Reads ${reading.toStringAsFixed(1)} mm, card is ${bankCardWidthMm.toStringAsFixed(1)} mm', style: text.labelMedium),
          const UiGap(UiSpace.md),
          Row(
            children: [
              Expanded(child: UiButton('Cancel', variant: UiButtonVariant.outline, size: UiSize.sm, onPressed: onCancel)),
              const UiGap(UiSpace.sm),
              Expanded(child: UiButton('Apply', size: UiSize.sm, onPressed: onApply)),
            ],
          ),
        ],
      ),
    );
  }
}
