package com.itsash.levelr

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import kotlin.math.sqrt

/**
 * Streams the RMS level (0..1, full scale = 1) of ~125 ms microphone windows.
 * The dB conversion lives in Dart (`lib/core/sound_math.dart`) so it is tested.
 * The caller must hold RECORD_AUDIO; without it an `no_permission` error is sent.
 */
class MicStreamHandler : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private var thread: Thread? = null
    @Volatile private var running = false

    @SuppressLint("MissingPermission")
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
        if (minBuffer <= 0) {
            events.error("no_mic", "The microphone is not available.", null)
            return
        }
        val window = SAMPLE_RATE / 8
        val record = try {
            AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, CHANNEL, ENCODING, maxOf(minBuffer, window * 4))
        } catch (e: SecurityException) {
            events.error("no_permission", "Microphone permission is missing.", null)
            return
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            events.error("no_mic", "The microphone could not be opened.", null)
            return
        }

        running = true
        thread = Thread {
            val buffer = ShortArray(window)
            record.startRecording()
            try {
                while (running) {
                    val read = record.read(buffer, 0, buffer.size)
                    if (read <= 0) continue
                    var sum = 0.0
                    for (i in 0 until read) {
                        val s = buffer[i] / 32768.0
                        sum += s * s
                    }
                    val rms = sqrt(sum / read)
                    main.post { if (running) events.success(rms) }
                }
            } finally {
                runCatching { record.stop() }
                record.release()
            }
        }.also { it.name = "levelr-mic"; it.start() }
    }

    override fun onCancel(arguments: Any?) {
        running = false
        thread = null
    }

    private companion object {
        const val SAMPLE_RATE = 44100
        const val CHANNEL = AudioFormat.CHANNEL_IN_MONO
        const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }
}
