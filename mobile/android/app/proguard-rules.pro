# R8 rules for release builds.

# google_mlkit_text_recognition references the Chinese/Devanagari/Japanese/Korean
# recognizer options, but the app only bundles the Latin recognizer.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# tflite_flutter references the GPU delegate factory options; the GPU delegate
# artifact is optional and loading falls back to CPU when it is unavailable.
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
