import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/angles.dart';
import '../platform/device_channel.dart';
import '../widgets/dial_painters.dart';
import '../widgets/live_stream.dart';

/// Compass from the rotation vector sensor, with a calibration hint.
class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key, required this.device});

  final DeviceChannel device;

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  double? _heading;
  bool _needsCalibration = false;

  void _onHeading(Heading h) {
    _heading = smoothAngle(_heading, h.degrees, alpha: 0.25);
    _needsCalibration = h.needsCalibration;
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    return LiveStream<Heading>(
      open: widget.device.heading,
      onData: _onHeading,
      builder: (context, latest) {
        final heading = _heading;
        if (latest == null || heading == null) return const Center(child: UiSpinner());
        return OrientationBuilder(
          builder: (context, orientation) {
            final rose = Semantics(
              label: 'Compass, heading ${heading.round()} degrees ${compassPoint(heading)}',
              child: CustomPaint(
                painter: CompassPainter(
                  colors: colors,
                  labelStyle: text.titleLarge!,
                  heading: heading,
                  active: !_needsCalibration,
                ),
                child: const SizedBox.expand(),
              ),
            );
            final panel = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Text('${heading.round() % 360}° ${compassPoint(heading)}', style: text.displayMedium)),
                Center(child: Text('Degrees from magnetic north', style: text.bodySmall)),
                if (_needsCalibration) ...[
                  const UiGap(UiSpace.lg),
                  const UiAlert(
                    'Move the phone in a figure 8 a few times, away from magnets and metal.',
                    title: 'Compass needs calibration',
                    status: UiStatus.warning,
                  ),
                ],
              ],
            );
            const padding = EdgeInsets.fromLTRB(UiSpace.page, UiSpace.md, UiSpace.page, UiSpace.lg);
            if (orientation == Orientation.landscape) {
              return Padding(
                padding: padding,
                child: Row(
                  children: [
                    Expanded(child: rose),
                    const UiGap(UiSpace.xl),
                    SizedBox(width: 300, child: Center(child: SingleChildScrollView(child: panel))),
                  ],
                ),
              );
            }
            return Padding(
              padding: padding,
              child: Column(children: [panel, const UiGap(UiSpace.lg), Expanded(child: rose)]),
            );
          },
        );
      },
    );
  }
}
