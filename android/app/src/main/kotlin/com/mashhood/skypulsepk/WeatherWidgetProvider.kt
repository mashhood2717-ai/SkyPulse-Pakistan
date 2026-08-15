package com.mashhood.skypulsepk

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews

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

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onEnabled(context: Context) = Unit

    override fun onDisabled(context: Context) = Unit

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val LAYOUT_COMPACT = 0
        private const val LAYOUT_WIDE = 1
        private const val LAYOUT_EXPANDED = 2

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val layoutMode = resolveLayoutMode(appWidgetManager, appWidgetId)
            val layoutId = when (layoutMode) {
                LAYOUT_EXPANDED -> R.layout.weather_widget_expanded
                LAYOUT_WIDE -> R.layout.weather_widget_wide
                else -> R.layout.weather_widget
            }
            val views = RemoteViews(context.packageName, layoutId)

            val city = prefs.getString("city", "Loading...") ?: "Loading..."
            val temperature = prefs.getString("temperature", "--") ?: "--"
            val condition = prefs.getString("condition", "--") ?: "--"
            val humidity = prefs.getString("humidity", "--") ?: "--"
            val windSpeed = prefs.getString(
                "wind_speed",
                prefs.getString("wind", "--") ?: "--"
            ) ?: "--"
            val windDirection = prefs.getString("wind_direction", "--") ?: "--"
            val feelsLike = prefs.getString("feels_like", "--") ?: "--"
            val pressure = prefs.getString("pressure", "--") ?: "--"
            val rainRate = prefs.getString("rain_rate", "0.0 mm/h") ?: "0.0 mm/h"
            val dailyRain = prefs.getString("daily_rain", "0.0 mm") ?: "0.0 mm"
            val aqi = prefs.getString("aqi", "--") ?: "--"
            val highLow = prefs.getString("high_low", "--") ?: "--"
            val source = prefs.getString("source", "LIVE WEATHER") ?: "LIVE WEATHER"
            val updated = prefs.getString("updated", "Updated now") ?: "Updated now"
            val weatherCode = prefs.getInt("weather_code", 0)
            val isDay = prefs.getBoolean("is_day", true)
            val wind = formatWind(windDirection, windSpeed)

            views.setInt(
                R.id.widget_container,
                "setBackgroundResource",
                if (isDay) R.drawable.widget_background else R.drawable.widget_background_night
            )
            views.setTextViewText(R.id.tv_city, city)
            views.setTextViewText(R.id.tv_temperature, temperature)
            views.setTextViewText(R.id.tv_condition, condition)
            views.setImageViewResource(
                R.id.iv_weather_icon,
                getWeatherIcon(weatherCode, isDay, condition)
            )

            when (layoutMode) {
                LAYOUT_EXPANDED -> {
                    views.setTextViewText(R.id.tv_source, source)
                    views.setTextViewText(R.id.tv_updated, updated)
                    setMetric(views, 1, "FEELS", withDegree(feelsLike))
                    setMetric(views, 2, "WIND", wind)
                    setMetric(views, 3, "HUM", humidity)
                    setMetric(views, 4, "PRESS", pressure)
                    setMetric(views, 5, "AQI", aqi)
                    setMetric(views, 6, "RATE", rainRate)
                    setMetric(views, 7, "RAIN", dailyRain)
                    setMetric(views, 8, "H/L", highLow)
                }

                LAYOUT_WIDE -> {
                    views.setTextViewText(R.id.tv_source, source)
                    setMetric(views, 1, "HUM", humidity)
                    setMetric(views, 2, "WIND", wind)
                    setMetric(views, 3, "AQI", aqi)
                    setMetric(views, 4, "RAIN", dailyRain)
                }

                else -> {
                    setMetric(views, 1, "HUM", humidity)
                    setMetric(views, 2, "WIND", compactWind(windSpeed))
                }
            }

            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun resolveLayoutMode(
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ): Int {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)

            return when {
                minWidth >= 250 && minHeight >= 240 -> LAYOUT_EXPANDED
                minWidth >= 250 -> LAYOUT_WIDE
                else -> LAYOUT_COMPACT
            }
        }

        private fun setMetric(views: RemoteViews, index: Int, label: String, value: String) {
            when (index) {
                1 -> {
                    views.setTextViewText(R.id.tv_metric_1_label, label)
                    views.setTextViewText(R.id.tv_metric_1_value, value)
                }

                2 -> {
                    views.setTextViewText(R.id.tv_metric_2_label, label)
                    views.setTextViewText(R.id.tv_metric_2_value, value)
                }

                3 -> {
                    views.setTextViewText(R.id.tv_metric_3_label, label)
                    views.setTextViewText(R.id.tv_metric_3_value, value)
                }

                4 -> {
                    views.setTextViewText(R.id.tv_metric_4_label, label)
                    views.setTextViewText(R.id.tv_metric_4_value, value)
                }

                5 -> {
                    views.setTextViewText(R.id.tv_metric_5_label, label)
                    views.setTextViewText(R.id.tv_metric_5_value, value)
                }

                6 -> {
                    views.setTextViewText(R.id.tv_metric_6_label, label)
                    views.setTextViewText(R.id.tv_metric_6_value, value)
                }

                7 -> {
                    views.setTextViewText(R.id.tv_metric_7_label, label)
                    views.setTextViewText(R.id.tv_metric_7_value, value)
                }

                8 -> {
                    views.setTextViewText(R.id.tv_metric_8_label, label)
                    views.setTextViewText(R.id.tv_metric_8_value, value)
                }
            }
        }

        private fun formatWind(direction: String, speed: String): String {
            val cleanSpeed = compactWind(speed)
            if (cleanSpeed == "--" || cleanSpeed == "Calm") return cleanSpeed

            val cleanDirection = direction.trim()
            if (cleanDirection.isEmpty() ||
                cleanDirection == "--" ||
                cleanDirection.equals("Calm", ignoreCase = true)
            ) {
                return cleanSpeed
            }

            return "$cleanDirection $cleanSpeed"
        }

        private fun compactWind(speed: String): String {
            val cleanSpeed = speed.trim()
            if (cleanSpeed.isEmpty() || cleanSpeed == "--" || cleanSpeed.startsWith("--")) {
                return "--"
            }

            val numeric = cleanSpeed.substringBefore(" ").toDoubleOrNull()
            if (numeric != null && numeric <= 0.0) {
                return "Calm"
            }

            return cleanSpeed
        }

        private fun withDegree(value: String): String {
            val cleanValue = value.trim()
            if (cleanValue.isEmpty() || cleanValue == "--") return "--"
            return "$cleanValue\u00B0"
        }

        private fun getWeatherIcon(weatherCode: Int, isDay: Boolean, condition: String): Int {
            val text = condition.lowercase()

            if (text.contains("storm") || text.contains("thunder")) {
                return R.drawable.widget_ic_storm
            }
            if (text.contains("snow") || text.contains("hail") || text.contains("ice")) {
                return R.drawable.widget_ic_snow
            }
            if (text.contains("rain") ||
                text.contains("drizzle") ||
                text.contains("shower")
            ) {
                return R.drawable.widget_ic_rain
            }
            if (text.contains("fog") ||
                text.contains("mist") ||
                text.contains("haze") ||
                text.contains("smoke") ||
                text.contains("dust")
            ) {
                return R.drawable.widget_ic_fog
            }
            if (text.contains("wind") ||
                text.contains("breeze") ||
                text.contains("breezy") ||
                text.contains("gust")
            ) {
                return R.drawable.widget_ic_wind
            }
            if (text.contains("cloud") || text.contains("overcast")) {
                return R.drawable.widget_ic_cloud
            }

            return when (weatherCode) {
                0 -> if (isDay) R.drawable.widget_ic_sun else R.drawable.widget_ic_moon
                1 -> if (isDay) R.drawable.widget_ic_sun else R.drawable.widget_ic_moon
                2, 3 -> R.drawable.widget_ic_cloud
                45, 48 -> R.drawable.widget_ic_fog
                51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82 -> {
                    R.drawable.widget_ic_rain
                }

                71, 73, 75, 77, 85, 86 -> R.drawable.widget_ic_snow
                95, 96, 99 -> R.drawable.widget_ic_storm
                else -> if (isDay) R.drawable.widget_ic_sun else R.drawable.widget_ic_moon
            }
        }
    }
}
