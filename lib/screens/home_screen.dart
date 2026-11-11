import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../platform/device_channel.dart';
import '../settings/settings_store.dart';
import 'angle_screen.dart';
import 'compass_screen.dart';
import 'level_screen.dart';
import 'ruler_screen.dart';
import 'settings_screen.dart';
import 'sound_screen.dart';

/// The five tools in a bottom navigation shell. Only the open tool runs its
/// sensor; the screen stays on while Levelr is in the foreground.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.device, required this.settings});

  final DeviceChannel device;
  final SettingsStore settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _items = [
    UiNavItem(Icons.vertical_align_center_rounded, 'Level'),
    UiNavItem(Icons.square_foot_rounded, 'Angle'),
    UiNavItem(Icons.straighten_rounded, 'Ruler'),
    UiNavItem(Icons.graphic_eq_rounded, 'Sound'),
    UiNavItem(Icons.explore_outlined, 'Compass', selectedIcon: Icons.explore_rounded),
  ];

  int _tab = 0;

  @override
  void initState() {
    super.initState();
    widget.device.keepScreenOn(true);
  }

  @override
  void dispose() {
    widget.device.keepScreenOn(false);
    super.dispose();
  }

  Widget _page() {
    final device = widget.device;
    final settings = widget.settings;
    return switch (_tab) {
      0 => LevelScreen(key: const ValueKey('level'), device: device, settings: settings),
      1 => AngleScreen(key: const ValueKey('angle'), device: device),
      2 => RulerScreen(key: const ValueKey('ruler'), device: device, settings: settings),
      3 => SoundScreen(key: const ValueKey('sound'), device: device, settings: settings),
      _ => CompassScreen(key: const ValueKey('compass'), device: device),
    };
  }

  @override
  Widget build(BuildContext context) {
    return UiShell(
      items: _items,
      index: _tab,
      onChanged: (i) => setState(() => _tab = i),
      appBar: UiAppBar(
        title: _items[_tab].label,
        actions: [
          UiIconButton(
            Icons.settings_rounded,
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => SettingsScreen(settings: widget.settings)),
            ),
          ),
        ],
      ),
      // One page at a time, so the sensors of the other tools are released.
      body: _page(),
    );
  }
}
