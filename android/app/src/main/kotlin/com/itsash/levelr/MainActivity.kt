package com.itsash.levelr

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Wires the Dart side to native sensors, the microphone and display info.
 *
 * Channels (names match `lib/platform/channels.dart`):
 * - `com.itsash.levelr/device` (method): `displayMetrics`, `keepScreenOn`.
 * - `com.itsash.levelr/gravity` (events): `[x, y, z]` in m/s2.
 * - `com.itsash.levelr/heading` (events): `[azimuthDegrees, accuracy]`.
 * - `com.itsash.levelr/mic` (events): RMS of each audio window, 0..1.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "$CHANNEL/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "displayMetrics" -> result.success(displayMetrics())
                "keepScreenOn" -> {
                    val on = call.arguments as? Boolean ?: false
                    if (on) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "$CHANNEL/gravity")
            .setStreamHandler(GravityStreamHandler(applicationContext))
        EventChannel(messenger, "$CHANNEL/heading")
            .setStreamHandler(HeadingStreamHandler(applicationContext))
        EventChannel(messenger, "$CHANNEL/mic")
            .setStreamHandler(MicStreamHandler())
    }

    private fun displayMetrics(): Map<String, Double> {
        val m = resources.displayMetrics
        return mapOf(
            "xdpi" to m.xdpi.toDouble(),
            "ydpi" to m.ydpi.toDouble(),
            "density" to m.density.toDouble(),
            "widthPx" to m.widthPixels.toDouble(),
            "heightPx" to m.heightPixels.toDouble(),
        )
    }

    private companion object {
        const val CHANNEL = "com.itsash.levelr"
    }
}
