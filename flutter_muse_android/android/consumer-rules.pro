# The Muse SDK (libmuse_android) is a Djinni library: libmuse_android.so finds
# com.choosemuse.libmuse classes, fields and methods by name through JNI.
# R8 cannot see those references, so keep the whole SDK unshrunk and
# unobfuscated in apps that minify their release builds (Flutter does).
-keep class com.choosemuse.libmuse.** { *; }
-keep interface com.choosemuse.libmuse.** { *; }
-keepclassmembers enum com.choosemuse.libmuse.** { *; }
-dontwarn com.choosemuse.libmuse.**
