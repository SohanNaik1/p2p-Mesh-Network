package com.example.flutter_frontend // Use your actual package name

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import backend.Backend // This imports your compiled Go code
import kotlin.concurrent.thread

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Start the Go server in a background thread
        thread {
            try {
                Backend.startServer()
            } catch (e: Exception) {
                // Log the error if the server fails to start
                e.printStackTrace()
            }
        }
    }
}
