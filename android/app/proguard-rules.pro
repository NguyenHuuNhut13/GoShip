# Flutter Wrapper Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve line numbers for debugging release crashes
-keepattributes SourceFile,LineNumberTable

# Agora RTC Engine Rules
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Firebase & Google Play Services Rules
-keepattributes *Annotation*,InnerClasses,EnclosingMethod
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Google Play Core (Flutter deferred components)
-dontwarn com.google.android.play.core.**
