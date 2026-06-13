# TFLite — keep all JNI class names intact
-keep class org.tensorflow.** { *; }
-keep class com.google.flatbuffers.** { *; }
-dontwarn org.tensorflow.**

# ML Kit — prevent stripping text recognition classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**

# react-native-fast-tflite JSI bridge
-keep class com.tflite.** { *; }
-dontwarn com.tflite.**

# op-sqlite JSI bridge
-keep class com.opsqlite.** { *; }

# react-native-keychain
-keep class com.oblador.keychain.** { *; }

# React Native
-keep class com.facebook.react.** { *; }
-keep class com.facebook.hermes.** { *; }
-keep class com.facebook.jni.** { *; }

# Hermes
-keep class com.facebook.hermes.unicode.** { *; }
-keep class com.facebook.jni.** { *; }
