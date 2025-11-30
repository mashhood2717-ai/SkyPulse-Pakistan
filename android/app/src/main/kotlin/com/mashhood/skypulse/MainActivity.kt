package com.mashhood.skypulse

import io.flutter.embedding.android.FlutterActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "weather_alerts"
            val channelName = "Weather Alerts"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = "Notifications for weather alerts"
                enableVibration(true)
                enableLights(true)
            }
            val notificationManager: NotificationManager =
                getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}

