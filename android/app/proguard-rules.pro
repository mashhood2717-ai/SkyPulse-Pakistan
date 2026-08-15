# Flutter Wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Play Core is referenced by Flutter's deferred-components stubs only.
-dontwarn com.google.android.play.core.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# Keep Firebase Analytics classes
-keep class com.firebase.** { *; }
-keep class com.google.firebase.analytics.** { *; }

# Dart/Flutter reflection
-keep class com.google.dart.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# WorkManager (home screen widget background refresh)
-keep class androidx.work.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }

# Home Widget
-keep class es.antonborri.home_widget.** { *; }

# AndroidX Libraries
-keep class androidx.** { *; }
-dontwarn androidx.**

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep view constructors for inflation from XML
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

# Keep certain view classes used in layouts
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Kotlin related
-keep class kotlin.** { *; }
-keep interface kotlin.** { *; }
-dontwarn kotlin.**

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# WorkManager
-keep class androidx.work.** { *; }

# Remove logging in production
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
}


# Keep Firebase Analytics classes
-keep class com.firebase.** { *; }
-keep class com.google.firebase.analytics.** { *; }

# Dart/Flutter reflection
-keep class com.google.dart.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# WorkManager (home screen widget background refresh)
-keep class androidx.work.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }

# Home Widget
-keep class es.antonborri.home_widget.** { *; }

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep view constructors for inflation from XML
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

# Keep certain view classes used in layouts
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Kotlin related
-keep class kotlin.** { *; }
-keep interface kotlin.** { *; }
-dontwarn kotlin.**

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# Remove logging in production
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
