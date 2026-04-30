# ML Kit ProGuard rules to fix R8 missing classes errors
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.ml.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.ml.**

# Specifically for text recognition
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.**
