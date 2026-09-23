# maplibre_android 0.3.6 drives the native map from Dart over JNI (jnigen
# bindings) and looks Java/Kotlin types up BY NAME — including its own
# FlutterApi and Flutter's embedding interfaces (it implements
# io.flutter.plugin.platform.PlatformView from Dart). Its consumer rules only
# keep org.maplibre.** + gson, so R8 renames these in release builds: the
# Dart-side PlatformView proxy then never answers getView(), and every map
# platform view dies with a NullPointerException (blank map, release only).
-keep class com.github.josxha.maplibre.** { *; }
-keep class io.flutter.plugin.platform.PlatformView { *; }
-keep class io.flutter.plugin.platform.PlatformViewFactory { *; }
-keep class io.flutter.plugin.common.PluginRegistry { *; }
-keep class io.flutter.plugin.common.PluginRegistry$* { *; }
-keep class io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding { *; }
-keep class io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding$* { *; }
