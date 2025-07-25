# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Preserve native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Rust JNI methods
-keep class com.lyretune.app.MainActivity {
    native <methods>;
}

# Jetpack Compose rules
-keep class androidx.compose.** { *; }
-keep class kotlin.Metadata { *; }

# Keep data classes
-keep class com.lyretune.app.audio.ScaleData { *; }

# Apache Commons Math
-keep class org.apache.commons.math3.** { *; }
-dontwarn org.apache.commons.math3.**

# Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}