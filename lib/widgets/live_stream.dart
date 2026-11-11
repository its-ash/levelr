import 'dart:async';

import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../platform/device_channel.dart';
import 'tab_active.dart';

/// Listens to a stream while its tab is the open one and the app is in the
/// foreground.
///
/// The native sensor is released when the tab is left or the app goes to the
/// background and started again on return. The last event is kept meanwhile,
/// so a revisited tab shows its last reading at once instead of a spinner.
///
/// [onData] runs for every event before [builder], so a parent can keep
/// derived state (filters, statistics). [builder] gets the latest event, or
/// null while waiting for the first one.
class LiveStream<T> extends StatefulWidget {
  const LiveStream({
    super.key,
    required this.open,
    required this.builder,
    this.onData,
    this.errorBuilder,
  });

  /// Opens the stream. Called again when the app resumes.
  final Stream<T> Function() open;
  final void Function(T event)? onData;
  final Widget Function(BuildContext context, T? latest) builder;

  /// Replaces the default "sensor not available" message.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<LiveStream<T>> createState() => _LiveStreamState<T>();
}

class _LiveStreamState<T> extends State<LiveStream<T>> with WidgetsBindingObserver {
  StreamSubscription<T>? _sub;
  T? _latest;
  Object? _error;
  bool _foreground = true;
  bool _tabActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabActive = TabActive.of(context);
    _sync();
  }

  /// Samples only while the tab is open and the app is in the foreground.
  void _sync() {
    if (_tabActive && _foreground) {
      if (_sub == null && _error == null) _subscribe();
    } else {
      _sub?.cancel();
      _sub = null;
    }
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = widget.open().listen(
      (event) {
        widget.onData?.call(event);
        if (mounted) setState(() => _latest = event);
      },
      onError: (Object error) {
        if (mounted) setState(() => _error = error);
      },
      cancelOnError: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _foreground = false;
      _sync();
    } else if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _sync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return widget.errorBuilder?.call(context, error) ?? SensorMissing(error: error);
    }
    return widget.builder(context, _latest);
  }
}

/// Default message when a sensor is missing.
class SensorMissing extends StatelessWidget {
  const SensorMissing({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is SensorUnavailable ? (error as SensorUnavailable).message : 'The sensor could not be read.';
    return UiEmptyState(
      icon: Icons.sensors_off_rounded,
      title: 'Sensor not available',
      message: '$message This tool cannot work on this phone.',
    );
  }
}
