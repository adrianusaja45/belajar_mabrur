# Zego UIKit & Express Proguard Rules
-keep class com.zego.** { *; }
-keep class org.webrtc.** { *; }
-dontwarn com.zego.**
-dontwarn org.webrtc.**

# Flutter and Firebase
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }