import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../settings/settings_store.dart';

/// Formats a dB correction such as `+3.5 dB`.
String formatOffset(double db) => '${db > 0 ? '+' : ''}${db.toStringAsFixed(1)} dB';

/// Lets the user correct the sound meter against a reference meter.
Future<void> showSoundOffsetSheet(BuildContext context, SettingsStore settings) {
  return UiSheet.show<void>(
    context,
    title: 'Calibrate sound meter',
    subtitle: 'Compare with a reference meter and add the difference.',
    child: ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Phone microphones are not measurement microphones, so readings are '
            'approximate. If a reference meter reads 3 dB higher than Levelr, set +3.',
            style: context.text.bodyMedium,
          ),
          const UiGap(UiSpace.lg),
          Center(
            child: UiStepper<double>(
              value: settings.soundOffset,
              min: -40,
              max: 40,
              step: 0.5,
              decimals: 1,
              format: formatOffset,
              semanticLabel: 'Sound offset in decibels',
              onChanged: settings.setSoundOffset,
            ),
          ),
          const UiGap(UiSpace.lg),
          UiButton(
            'Reset to 0 dB',
            variant: UiButtonVariant.outline,
            onPressed: settings.soundOffset == 0 ? null : () => settings.setSoundOffset(0),
          ),
        ],
      ),
    ),
  );
}
