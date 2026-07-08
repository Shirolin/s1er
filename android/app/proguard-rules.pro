# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Hive
-keep class com.google.gson.** { *; }
-keepclassmembers class * extends org.apache.hive.** {
    public <init>(...);
}

# Dio
-keepattributes Signature
-keepattributes Exceptions
-keep class io.flutter.plugins.** { *; }

# Cookie Jar
-keep class org.httpunit.** { *; }

# Don't warn about annotations
-dontwarn javax.annotation.**

# Play Core - suppress warnings for missing classes (not used but referenced by Flutter)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
