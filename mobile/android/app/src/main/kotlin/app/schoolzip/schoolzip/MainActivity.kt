package app.schoolzip.schoolzip

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "schoolzip/today").setMethodCallHandler { call, result ->
            if (call.method == "reset") {
                TodayWidget.prefs(this).edit().clear().apply()
                TodayWidget.render(this)
                result.success(null)
                return@setMethodCallHandler
            }
            if (call.method == "teacherNames") {
                val code = call.argument<String>("code")!!
                val names = call.argument<String>("names")!!
                val store = TodayWidget.prefs(this)
                val key = "teacherNames.$code"
                if (store.getString(key, "{}") != names) {
                    store.edit().putString(key, names).apply()
                    TodayWidget.render(this)
                }
                result.success(null)
                return@setMethodCallHandler
            }
            if (call.method == "cacheWeek") {
                val store = TodayWidget.prefs(this)
                val config = org.json.JSONObject(store.getString("config","{}")!!)
                val code = android.net.Uri.parse(config.optString("url")).getQueryParameter("code")
                if (code == call.argument<String>("code") && config.optString("grade") == call.argument<String>("grade") &&
                    config.optString("room") == call.argument<String>("room")) {
                    store.edit().putString("days",call.argument<String>("days")).apply()
                    TodayWidget.render(this)
                }
                result.success(null)
                return@setMethodCallHandler
            }
            if (call.method != "configure") { result.notImplemented(); return@setMethodCallHandler }
            TodayWidget.configure(this,call.argument<String>("url")!!,call.argument<String>("grade")!!,call.argument<String>("room")!!)
            result.success(null)
        }
    }
}
