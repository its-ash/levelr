import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'platform/device_channel.dart';
import 'screens/home_screen.dart';
import 'settings/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load();
  runApp(LevelrApp(settings: settings, device: const DeviceChannel()));
}

class LevelrApp extends StatelessWidget {
  const LevelrApp({super.key, required this.settings, required this.device});

  final SettingsStore settings;
  final DeviceChannel device;

  @override
  Widget build(BuildContext context) {
    return UiApp(
      title: 'Levelr',
      themeMode: ThemeMode.system,
      home: HomeScreen(device: device, settings: settings),
    );
  }
}
