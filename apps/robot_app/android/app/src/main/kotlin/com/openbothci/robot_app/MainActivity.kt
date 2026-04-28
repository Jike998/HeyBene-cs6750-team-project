package com.openbothci.robot_app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private lateinit var phoneControllerLinkBridge: PhoneControllerLinkBridge
    private lateinit var robotLinkClientBridge: RobotLinkClientBridge
    private lateinit var gamepadInputBridge: GamepadInputBridge
    private lateinit var robotBackendBridge: RobotBackendBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        phoneControllerLinkBridge = PhoneControllerLinkBridge(this)
        phoneControllerLinkBridge.attach(flutterEngine)

        robotLinkClientBridge = RobotLinkClientBridge(this)
        robotLinkClientBridge.attach(flutterEngine)

        gamepadInputBridge = GamepadInputBridge()
        gamepadInputBridge.attach(flutterEngine)

        robotBackendBridge = RobotBackendBridge(this)
        robotBackendBridge.attach(flutterEngine)
    }

    override fun dispatchKeyEvent(event: android.view.KeyEvent): Boolean {
        if (this::gamepadInputBridge.isInitialized && gamepadInputBridge.handleKeyEvent(event)) {
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onGenericMotionEvent(event: android.view.MotionEvent): Boolean {
        if (this::gamepadInputBridge.isInitialized && gamepadInputBridge.handleMotionEvent(event)) {
            return true
        }
        return super.onGenericMotionEvent(event)
    }
}
