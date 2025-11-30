package com.example.weather_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onResume() {
        super.onResume()
        // Create notification channel for Firebase messages
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "weather_alerts"
            val channelName = "Weather Alerts"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = "Notifications for weather alerts"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
