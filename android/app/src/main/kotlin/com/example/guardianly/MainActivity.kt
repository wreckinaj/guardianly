package com.example.guardianly

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

// Minimal MainActivity using Flutter v2 embedding and explicitly registering plugins
class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "onCreate - FlutterActivity started")
    }

    // Ensure plugins are registered on the engine (helps avoid "Unable to establish connection on channel.")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        Log.d("MainActivity", "configureFlutterEngine - plugins registered")
    }
}
