# Flutter Wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Google Play Core (required for split installs and deferred components)
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.** { *; }
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.**

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

# Google Maps Flutter
-keep class com.google.android.libraries.maps.** { *; }

# Webview Flutter
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Home Widget
-keep class es.antonbordes.homewidget.** { *; }

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

# Google Maps Flutter
-keep class com.google.android.libraries.maps.** { *; }

# Webview Flutter
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Home Widget
-keep class es.antonbordes.homewidget.** { *; }

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
