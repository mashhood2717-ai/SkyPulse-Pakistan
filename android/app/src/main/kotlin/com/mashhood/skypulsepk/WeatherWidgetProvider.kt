package com.mashhood.skypulsepk

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent

class WeatherWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Called when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Called when the last widget is removed
    }

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
        
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            
            // Get weather data from SharedPreferences (set by Flutter)
            val city = prefs.getString("city", "Loading...") ?: "Loading..."
            val temperature = prefs.getString("temperature", "--") ?: "--"
            val condition = prefs.getString("condition", "--") ?: "--"
            val humidity = prefs.getString("humidity", "--%") ?: "--%"
            val wind = prefs.getString("wind", "-- km/h") ?: "-- km/h"
            val weatherCode = prefs.getInt("weather_code", 0)
            val isDay = prefs.getBoolean("is_day", true)
            
            // Create RemoteViews
            val views = RemoteViews(context.packageName, R.layout.weather_widget)
            
            // Set text values
            views.setTextViewText(R.id.tv_city, city)
            views.setTextViewText(R.id.tv_temperature, temperature)
            views.setTextViewText(R.id.tv_condition, condition)
            views.setTextViewText(R.id.tv_humidity, "💧 $humidity")
            views.setTextViewText(R.id.tv_wind, "💨 $wind")
            
            // Set weather emoji based on weather code
            val emoji = getWeatherEmoji(weatherCode, isDay)
            views.setTextViewText(R.id.tv_weather_emoji, emoji)
            
            // Set click action to open app
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 
                0, 
                intent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            // Update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
        
        private fun getWeatherEmoji(weatherCode: Int, isDay: Boolean): String {
            // Map WMO weather codes to emojis
            return when (weatherCode) {
                0 -> if (isDay) "☀️" else "🌙"
                1 -> if (isDay) "🌤️" else "🌙"
                2 -> if (isDay) "⛅" else "☁️"
                3 -> "☁️"
                45, 48 -> "🌫️"
                51, 53, 55 -> "🌧️"
                56, 57 -> "🌨️"
                61, 63, 65 -> "🌧️"
                66, 67 -> "🌨️"
                71, 73, 75 -> "❄️"
                77 -> "🌨️"
                80, 81, 82 -> "🌧️"
                85, 86 -> "🌨️"
                95 -> "⛈️"
                96, 99 -> "⛈️"
                else -> if (isDay) "🌤️" else "🌙"
            }
        }
    }
}
