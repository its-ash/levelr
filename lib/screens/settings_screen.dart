import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../settings/settings_store.dart';
import '../widgets/sound_offset_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsStore settings;

  Future<void> _reset(BuildContext context) async {
    final ok = await UiDialog.confirm(
      context,
      title: 'Reset calibrations?',
      message: 'This clears the level zero points, the ruler card calibration and the sound offset.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (ok) settings.resetCalibrations();
  }

  @override
  Widget build(BuildContext context) {
    return UiScaffold(
      appBar: const UiAppBar(title: 'Settings'),
      scrollable: true,
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiListGroup(
              header: 'Measuring',
              children: [
                UiListTile(
                  'Units',
                  icon: Icons.straighten_rounded,
                  subtitle: 'Used by the ruler',
                  trailing: SizedBox(
                    width: 190,
                    child: UiSegmentedControl<UnitSystem>(
                      [
                        const UiSegment(UnitSystem.metric, label: 'Metric'),
                        const UiSegment(UnitSystem.imperial, label: 'Imperial'),
                      ],
                      value: settings.units,
                      size: UiSize.sm,
                      expand: true,
                      onChanged: settings.setUnits,
                    ),
                  ),
                ),
                UiSwitchTile(
                  'Haptics',
                  subtitle: 'A tick when the level is exactly flat',
                  icon: Icons.vibration_rounded,
                  value: settings.haptics,
                  onChanged: settings.setHaptics,
                ),
              ],
            ),
            const UiGap(UiSpace.lg),
            UiListGroup(
              header: 'Calibration',
              footer: 'Zero the level on a surface you know is flat from the Level tab. '
                  'Calibrate the ruler with a bank card from the Ruler tab.',
              children: [
                UiListTile(
                  'Sound meter offset',
                  icon: Icons.graphic_eq_rounded,
                  value: formatOffset(settings.soundOffset),
                  chevron: true,
                  onTap: () => showSoundOffsetSheet(context, settings),
                ),
                UiListTile(
                  'Reset calibrations',
                  icon: Icons.restart_alt_rounded,
                  destructive: true,
                  enabled: settings.hasCalibration,
                  onTap: () => _reset(context),
                ),
              ],
            ),
            const UiGap(UiSpace.lg),
            const UiListGroup(
              header: 'Privacy',
              children: [
                UiListTile(
                  'Everything stays on this phone',
                  subtitle: 'The microphone is used only to measure volume, never recorded. '
                      'Levelr uses the internet only to check for app updates.',
                  icon: Icons.lock_rounded,
                  iconStatus: UiStatus.success,
                ),
              ],
            ),
            const UiGap(UiSpace.lg),
            const UiUpdateSection(storeId: 'levelr'),
            const UiGap(UiSpace.lg),
            const UiDeveloperSection(),
          ],
        ),
      ),
    );
  }
}
