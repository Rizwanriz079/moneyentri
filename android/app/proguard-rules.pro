# flutter_local_notifications stores scheduled reminders with Gson; keep the
# generic type information it needs after R8 shrinking.
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.** { *; }
