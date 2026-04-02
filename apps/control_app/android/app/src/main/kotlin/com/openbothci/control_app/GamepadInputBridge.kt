package com.openbothci.control_app

import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class GamepadInputBridge : EventChannel.StreamHandler {
    companion object {
        private const val EVENT_CHANNEL = "com.openbothci.control_app/gamepad/events"
    }

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    fun attach(flutterEngine: FlutterEngine) {
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL,
        ).setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun handleKeyEvent(event: KeyEvent): Boolean {
        if (!isGamepadEvent(event.source)) return false

        emitEvent(
            mapOf(
                "event" to "button",
                "button" to keyCodeName(event.keyCode),
                "pressed" to (event.action == KeyEvent.ACTION_DOWN),
                "repeat" to event.repeatCount,
                "deviceId" to event.deviceId,
            ),
        )
        return true
    }

    fun handleMotionEvent(event: MotionEvent): Boolean {
        if (!isGamepadEvent(event.source)) return false

        val device = event.device
        val axes = linkedMapOf<String, Double>()

        fun addAxis(name: String, axis: Int) {
            val value = getCenteredAxis(event, device, axis)
            if (value != null) {
                axes[name] = value.toDouble()
            }
        }

        // Common joystick axes
        addAxis("lx", MotionEvent.AXIS_X)
        addAxis("ly", MotionEvent.AXIS_Y)
        addAxis("rx", MotionEvent.AXIS_Z)
        addAxis("ry", MotionEvent.AXIS_RZ)

        // Alternate right-stick mappings seen on some Android gamepads
        addAxis("hatX", MotionEvent.AXIS_HAT_X)
        addAxis("hatY", MotionEvent.AXIS_HAT_Y)
        addAxis("rxAlt", MotionEvent.AXIS_RX)
        addAxis("ryAlt", MotionEvent.AXIS_RY)

        // Triggers: many controllers use LTRIGGER/RTRIGGER
        addAxis("lt", MotionEvent.AXIS_LTRIGGER)
        addAxis("rt", MotionEvent.AXIS_RTRIGGER)

        // Some controllers report triggers as BRAKE/GAS
        addAxis("brake", MotionEvent.AXIS_BRAKE)
        addAxis("gas", MotionEvent.AXIS_GAS)

        if (axes.isEmpty()) return false

        emitEvent(
            mapOf(
                "event" to "axes",
                "deviceId" to event.deviceId,
                "timestampMs" to (event.eventTime),
                "axes" to axes,
            ),
        )

        return true
    }

    private fun emitEvent(payload: Map<String, Any?>) {
        eventSink?.success(payload)
    }

    private fun isGamepadEvent(source: Int): Boolean {
        val hasJoystick = (source and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
        val hasGamepad = (source and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
        return hasJoystick || hasGamepad
    }

    private fun getCenteredAxis(
        event: MotionEvent,
        device: InputDevice?,
        axis: Int,
    ): Float? {
        val d = device ?: return null
        val range = d.getMotionRange(axis, event.source) ?: return null
        val value = event.getAxisValue(axis)

        // Standard Android deadzone for the hardware.
        if (kotlin.math.abs(value) <= range.flat) {
            return 0f
        }

        return value
    }

    private fun keyCodeName(code: Int): String {
        return when (code) {
            KeyEvent.KEYCODE_BUTTON_START -> "start"
            KeyEvent.KEYCODE_BUTTON_SELECT -> "select"
            KeyEvent.KEYCODE_BUTTON_MODE -> "mode"

            KeyEvent.KEYCODE_BUTTON_A -> "a"
            KeyEvent.KEYCODE_BUTTON_B -> "b"
            KeyEvent.KEYCODE_BUTTON_X -> "x"
            KeyEvent.KEYCODE_BUTTON_Y -> "y"

            KeyEvent.KEYCODE_BUTTON_L1 -> "l1"
            KeyEvent.KEYCODE_BUTTON_R1 -> "r1"
            KeyEvent.KEYCODE_BUTTON_L2 -> "l2"
            KeyEvent.KEYCODE_BUTTON_R2 -> "r2"

            KeyEvent.KEYCODE_DPAD_UP -> "dpad_up"
            KeyEvent.KEYCODE_DPAD_DOWN -> "dpad_down"
            KeyEvent.KEYCODE_DPAD_LEFT -> "dpad_left"
            KeyEvent.KEYCODE_DPAD_RIGHT -> "dpad_right"

            else -> "key_$code"
        }
    }
}
