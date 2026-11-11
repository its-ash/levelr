import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:theme/theme.dart';

import '../core/sound_math.dart';
import '../platform/device_channel.dart';
import '../settings/settings_store.dart';
import '../widgets/sound_offset_sheet.dart';

enum _MicState { starting, running, paused, denied, deniedForever, unavailable }

/// Approximate sound level from the microphone, with statistics and a chart.
class SoundScreen extends StatefulWidget {
  const SoundScreen({super.key, required this.device, required this.settings});

  final DeviceChannel device;
  final SettingsStore settings;

  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> with WidgetsBindingObserver {
  static const _historyLength = 120;

  final _stats = SoundStats();
  final _history = RollingWindow(_historyLength);
  StreamSubscription<double>? _sub;
  _MicState _state = _MicState.starting;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _state == _MicState.running) {
      _stop();
    } else if (state == AppLifecycleState.resumed && _sub == null && _state == _MicState.running) {
      _listen();
    }
  }

  Future<void> _start() async {
    setState(() => _state = _MicState.starting);
    var status = await Permission.microphone.status;
    if (!status.isGranted) status = await Permission.microphone.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _state = _MicState.running);
      _listen();
    } else {
      setState(() => _state = status.isPermanentlyDenied ? _MicState.deniedForever : _MicState.denied);
    }
  }

  void _listen() {
    _sub?.cancel();
    _sub = widget.device.micRms().listen(
      (rms) {
        final db = rmsToSpl(rms, offset: widget.settings.soundOffset);
        _stats.add(db);
        _history.add(db);
        if (mounted) setState(() {});
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _state = (e is SensorUnavailable && e.permissionDenied) ? _MicState.denied : _MicState.unavailable;
          _error = e is SensorUnavailable ? e.message : 'The microphone could not be read.';
        });
      },
      cancelOnError: true,
    );
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
  }

  void _togglePause() {
    if (_state == _MicState.running) {
      _stop();
      setState(() => _state = _MicState.paused);
    } else if (_state == _MicState.paused) {
      setState(() => _state = _MicState.running);
      _listen();
    }
  }

  void _reset() => setState(() {
        _stats.reset();
        _history.clear();
      });

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _MicState.starting:
        return const Center(child: UiSpinner());
      case _MicState.denied:
      case _MicState.deniedForever:
        final forever = _state == _MicState.deniedForever;
        return UiEmptyState(
          icon: Icons.mic_off_rounded,
          title: 'Microphone access needed',
          message: 'Levelr listens only to measure the volume. Nothing is recorded or sent anywhere.',
          action: UiButton(
            forever ? 'Open app settings' : 'Allow microphone',
            icon: forever ? Icons.settings_rounded : Icons.mic_rounded,
            onPressed: forever ? openAppSettings : _start,
          ),
        );
      case _MicState.unavailable:
        return UiErrorState(
          title: 'Microphone not available',
          message: _error ?? 'The microphone could not be opened. Another app may be using it.',
          onRetry: _start,
        );
      case _MicState.running:
      case _MicState.paused:
        return _meter(context);
    }
  }

  Widget _meter(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final current = _stats.current;
    final band = current == null ? null : LoudnessBand.of(current);
    final paused = _state == _MicState.paused;
    return ListView(
      padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.md, UiSpace.page, UiSpace.xl),
      children: [
        Center(
          child: UiGauge(
            value: (current ?? 0) / 120,
            size: 260,
            status: _statusOf(band),
            label: band?.label ?? 'Listening',
            center: Text(current == null ? '--' : '${current.round()} dB', style: text.displayMedium),
          ),
        ),
        const UiGap(UiSpace.lg),
        UiCard(
          padding: const EdgeInsets.symmetric(vertical: UiSpace.md),
          child: Row(
            children: [
              _Stat('Min', _stats.min),
              _Stat('Average', _stats.average),
              _Stat('Max', _stats.max),
            ],
          ),
        ),
        const UiGap(UiSpace.lg),
        if (_history.values.length >= 2)
          UiLineChart(
            series: [UiChartSeries('Level', _history.values, color: colors.accent)],
            height: 160,
            showLegend: false,
            yFormat: (v) => '${v.round()}',
          )
        else
          const SizedBox(height: 160, child: Center(child: UiSpinner())),
        const UiGap(UiSpace.lg),
        Row(
          children: [
            Expanded(
              child: UiButton(
                paused ? 'Resume' : 'Pause',
                icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                onPressed: _togglePause,
              ),
            ),
            const UiGap(UiSpace.sm),
            Expanded(child: UiButton('Reset', icon: Icons.restart_alt_rounded, variant: UiButtonVariant.outline, onPressed: _reset)),
            const UiGap(UiSpace.sm),
            UiIconButton(
              Icons.tune_rounded,
              tooltip: 'Calibrate',
              variant: UiButtonVariant.outline,
              onPressed: () => showSoundOffsetSheet(context, widget.settings),
            ),
          ],
        ),
        const UiGap(UiSpace.lg),
        UiListGroup(
          header: 'What it sounds like',
          children: [
            for (final b in LoudnessBand.values)
              UiListTile(
                b.label,
                value: b == LoudnessBand.harmful ? '${b.fromDb.round()}+ dB' : '${b.fromDb.round()}-${b.toDb.round()} dB',
                selected: b == band,
              ),
          ],
        ),
        const UiGap(UiSpace.lg),
        UiAlert(
          'Phone microphones are not calibrated, so this is an estimate'
          '${widget.settings.soundOffset == 0 ? '' : ' (offset ${formatOffset(widget.settings.soundOffset)})'}. '
          'Use the calibrate button to match a reference meter.',
        ),
      ],
    );
  }

  UiStatus _statusOf(LoudnessBand? band) => switch (band) {
        null => UiStatus.neutral,
        LoudnessBand.quiet => UiStatus.success,
        LoudnessBand.conversation => UiStatus.accent,
        LoudnessBand.traffic => UiStatus.warning,
        LoudnessBand.loud || LoudnessBand.harmful => UiStatus.danger,
      };
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: text.labelMedium?.copyWith(color: context.colors.textMuted)),
          Text(value == null ? '--' : '${value!.round()} dB', style: text.titleLarge),
        ],
      ),
    );
  }
}
