import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levelr/core/angles.dart';
import 'package:levelr/main.dart';
import 'package:levelr/platform/device_channel.dart';
import 'package:levelr/settings/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theme/theme.dart';

/// A sensor stream that counts how many listeners it has right now.
class _Feed<T> {
  final _controller = StreamController<T>.broadcast();
  int listeners = 0;
  int subscriptions = 0;

  Stream<T> open() => Stream<T>.multi((c) {
        listeners++;
        subscriptions++;
        final sub = _controller.stream.listen(c.add);
        c.onCancel = () {
          listeners--;
          return sub.cancel();
        };
      });

  void add(T v) => _controller.add(v);
}

class _FakeDevice extends DeviceChannel {
  final gravityFeed = _Feed<Vec3>();
  final headingFeed = _Feed<Heading>();
  final micFeed = _Feed<double>();

  @override
  Stream<Vec3> gravity() => gravityFeed.open();

  @override
  Stream<Heading> heading() => headingFeed.open();

  @override
  Stream<double> micRms() => micFeed.open();

  @override
  Future<DeviceMetrics> displayMetrics() async => const DeviceMetrics(xdpi: 400, ydpi: 400);

  @override
  Future<void> keepScreenOn(bool on) async {}
}

void main() {
  late _FakeDevice device;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Microphone permission: granted.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => call.method == 'checkPermissionStatus' || call.method == 'requestPermissions' ? (call.method == 'checkPermissionStatus' ? 1 : {7: 1}) : null,
    );
    device = _FakeDevice();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final settings = await SettingsStore.load();
    await tester.pumpWidget(LevelrApp(settings: settings, device: device));
    await tester.pump();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('revisiting Level and Compass shows the last reading, no spinner', (tester) async {
    await pump(tester);

    // First visit: spinner only until the first sample arrives.
    expect(find.byType(UiSpinner), findsOneWidget);
    device.gravityFeed.add(const Vec3(0, 0, 9.81));
    await tester.pump();
    expect(find.byType(UiSpinner), findsNothing);

    await openTab(tester, 'Compass');
    expect(find.byType(UiSpinner), findsOneWidget);
    device.headingFeed.add(const Heading(90, 3));
    await tester.pump();
    expect(find.byType(UiSpinner), findsNothing);
    expect(find.textContaining('90°'), findsOneWidget);

    // Back to Level: instant, no waiting for a new sample.
    await openTab(tester, 'Level');
    expect(find.byType(UiSpinner), findsNothing);

    // And to Compass again: last heading is there without any new event.
    await openTab(tester, 'Compass');
    expect(find.byType(UiSpinner), findsNothing);
    expect(find.textContaining('90°'), findsOneWidget);
  });

  testWidgets('only the visible tab samples its sensor', (tester) async {
    await pump(tester);
    expect(device.gravityFeed.listeners, 1);

    await openTab(tester, 'Compass');
    expect(device.gravityFeed.listeners, 0);
    expect(device.headingFeed.listeners, 1);

    await openTab(tester, 'Level');
    expect(device.headingFeed.listeners, 0);
    expect(device.gravityFeed.listeners, 1);
  });

  testWidgets('Angle and Ruler keep their state across switches', (tester) async {
    await pump(tester);
    device.gravityFeed.add(const Vec3(0, 0, 9.81));
    await tester.pump();

    await openTab(tester, 'Angle');
    expect(find.byType(UiSpinner), findsOneWidget);
    device.gravityFeed.add(const Vec3(0, 9.81, 0.5));
    await tester.pump();
    expect(find.byType(UiSpinner), findsNothing);

    await openTab(tester, 'Ruler');
    await tester.pump();
    expect(find.byType(UiSpinner), findsNothing);

    await openTab(tester, 'Angle');
    expect(find.byType(UiSpinner), findsNothing);
    await openTab(tester, 'Ruler');
    expect(find.byType(UiSpinner), findsNothing);
  });

  testWidgets('Sound tab keeps its stats and releases the mic when hidden', (tester) async {
    await pump(tester);
    await openTab(tester, 'Sound');
    await tester.pump(const Duration(milliseconds: 50));
    expect(device.micFeed.listeners, 1);
    for (final v in [0.01, 0.02, 0.03]) {
      device.micFeed.add(v);
      await tester.pump();
    }
    expect(find.byType(UiSpinner), findsNothing);

    await openTab(tester, 'Level');
    expect(device.micFeed.listeners, 0);

    await openTab(tester, 'Sound');
    // History is kept: no permission or chart spinner on the second visit.
    expect(find.byType(UiSpinner), findsNothing);
    expect(device.micFeed.listeners, 1);
    expect(device.micFeed.subscriptions, 2);
  });
}
