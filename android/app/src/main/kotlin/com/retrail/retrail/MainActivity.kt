package com.retrail.retrail

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The countdown cue speaks only while the ringer is on (#81): silent
        // and vibrate mode get the vibration alone.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "retrail/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isRingerNormal" -> {
                        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        result.success(audio.ringerMode == AudioManager.RINGER_MODE_NORMAL)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
