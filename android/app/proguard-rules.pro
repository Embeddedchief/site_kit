# Release shrinking (R8) rules.
#
# shared_preferences_android is called from Dart through JNI, which R8 cannot
# see, so without this it strips methods such as getAll() and every
# preferences read fails in release builds (the app then hangs on the splash).
-keep class io.flutter.plugins.sharedpreferences.** { *; }
