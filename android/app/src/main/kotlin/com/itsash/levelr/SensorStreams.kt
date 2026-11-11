package com.itsash.levelr

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Base for a sensor-backed [EventChannel.StreamHandler]. Registers the listener
 * when Dart starts listening and releases it when Dart cancels, so a closed
 * tool never keeps a sensor awake.
 */
abstract class SensorStreamHandler(context: Context) :
    EventChannel.StreamHandler, SensorEventListener {

    protected val manager: SensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    protected var sink: EventChannel.EventSink? = null

    /** The sensors to try, best first. The first one the device has is used. */
    protected abstract val sensorTypes: IntArray

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val sensor = sensorTypes.asSequence().mapNotNull { manager.getDefaultSensor(it) }.firstOrNull()
        if (sensor == null) {
            events.error("no_sensor", "This device has no suitable sensor.", null)
            events.endOfStream()
            return
        }
        sink = events
        onStart(sensor)
        manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)
    }

    override fun onCancel(arguments: Any?) {
        manager.unregisterListener(this)
        sink = null
    }

    protected open fun onStart(sensor: Sensor) {}

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
}

/** Gravity vector. Falls back to the accelerometer, which includes gravity. */
class GravityStreamHandler(context: Context) : SensorStreamHandler(context) {
    override val sensorTypes = intArrayOf(Sensor.TYPE_GRAVITY, Sensor.TYPE_ACCELEROMETER)

    override fun onSensorChanged(event: SensorEvent) {
        sink?.success(listOf(event.values[0].toDouble(), event.values[1].toDouble(), event.values[2].toDouble()))
    }
}

/**
 * Compass heading in degrees from magnetic north (0..360) and the sensor
 * accuracy (`SensorManager.SENSOR_STATUS_*`, 3 is high, 0 or 1 needs calibration).
 */
class HeadingStreamHandler(context: Context) : SensorStreamHandler(context) {
    override val sensorTypes = intArrayOf(Sensor.TYPE_ROTATION_VECTOR)

    private val rotation = FloatArray(9)
    private val remapped = FloatArray(9)
    private val orientation = FloatArray(3)
    // Android reports accuracy only when it changes, so assume good until told otherwise.
    private var accuracy = SensorManager.SENSOR_STATUS_ACCURACY_HIGH
    private val main = Handler(Looper.getMainLooper())

    override fun onStart(sensor: Sensor) {
        accuracy = SensorManager.SENSOR_STATUS_ACCURACY_HIGH
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
        this.accuracy = accuracy
    }

    override fun onSensorChanged(event: SensorEvent) {
        SensorManager.getRotationMatrixFromVector(rotation, event.values)
        // rotation[8] is the world "up" component along the screen normal:
        // near +-1 when the phone lies flat, near 0 when it stands upright.
        val flat = Math.abs(rotation[8]) > 0.7f
        val matrix = if (flat) {
            rotation
        } else {
            // Upright: the camera (back of the phone) points along the heading.
            SensorManager.remapCoordinateSystem(
                rotation, SensorManager.AXIS_X, SensorManager.AXIS_Z, remapped,
            )
            remapped
        }
        SensorManager.getOrientation(matrix, orientation)
        val degrees = (Math.toDegrees(orientation[0].toDouble()) + 360.0) % 360.0
        val acc = accuracy
        main.post { sink?.success(listOf(degrees, acc.toDouble())) }
    }
}
