package app.schoolzip.schoolzip

import android.app.AlarmManager
import android.net.Uri
import android.app.PendingIntent
import android.app.job.*
import android.appwidget.*
import android.content.*

import android.view.View
import org.json.JSONArray
import android.widget.RemoteViews
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class TodayWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = refresh(context)
    override fun onEnabled(context: Context) = refresh(context)
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            BOUNDARY, Intent.ACTION_TIME_CHANGED, Intent.ACTION_DATE_CHANGED -> render(context)
            else -> super.onReceive(context, intent)
        }
    }

    override fun onDisabled(context: Context) {
        context.getSystemService(AlarmManager::class.java).cancel(boundaryIntent(context))
    }

    companion object {
        private const val BOUNDARY = "app.schoolzip.schoolzip.WIDGET_BOUNDARY"

        private fun boundaryIntent(c: Context) = PendingIntent.getBroadcast(
            c, 0, Intent(c, TodayWidget::class.java).setAction(BOUNDARY), PendingIntent.FLAG_IMMUTABLE
        )
        private const val JOB = 8317
        private val zone = TimeZone.getTimeZone("Asia/Seoul")
        fun prefs(c: Context) = c.getSharedPreferences("schoolzip-today", Context.MODE_PRIVATE)
        fun configure(c: Context, url: String, grade: String, room: String) {
            val config = JSONObject().put("url",url).put("grade",grade).put("room",room).toString()
            val store = prefs(c)
            if (store.getString("config",null) != config) {
                store.edit().putString("config",config).remove("days").apply()
            }
            refresh(c)
        }
        fun refresh(c: Context) {
            if (!render(c) || prefs(c).getString("config",null)==null) return
            c.getSystemService(JobScheduler::class.java).schedule(JobInfo.Builder(JOB,ComponentName(c, TodayJob::class.java))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY).build())
        }
        fun render(c: Context): Boolean {
            val manager = AppWidgetManager.getInstance(c)
            val ids = manager.getAppWidgetIds(ComponentName(c, TodayWidget::class.java))
            val store = prefs(c)
            if (ids.isEmpty()) return false
            val now = Calendar.getInstance(zone)
            val minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone=zone }.format(now.time)
            val day = JSONObject(store.getString("days","{}")!!).optJSONArray(date)
            val message = when {
                store.getString("config",null)==null -> "앱에서 학년·반을 선택해 주세요"
                day == null -> "오늘 시간표를 기다리는 중"
                else -> "오늘은 수업이 없어요"
            }
            val views = RemoteViews(c.packageName,R.layout.today_widget)
            val stamp = SimpleDateFormat("M.d (E)",Locale.KOREA).apply { timeZone=zone }
            val dateLabel = stamp.format(now.time)
            val config = JSONObject(store.getString("config", "{}")!!)
            val uri = Uri.parse(config.optString("url"))
            val school = uri.getQueryParameter("name")
            val code = uri.getQueryParameter("code")
            val names = JSONObject(store.getString("teacherNames.$code", "{}")!!)
            views.setTextViewText(R.id.widget_school, school ?: "오늘 과목")
            val classLabel = if (config.has("room")) "${config.getString("grade")}학년 ${config.getString("room")}반" else ""
            var status = dateLabel
            var nextMinute = 1440
            views.setTextViewText(R.id.subjects,message)
            val hasLessons = day != null && day.length() > 0
            views.setViewVisibility(R.id.subjects,if(hasLessons) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.lesson_grid,if(hasLessons) View.VISIBLE else View.GONE)
            views.removeAllViews(R.id.lesson_grid)
            if (day != null) for (start in 0 until day.length() step 2) {
                val row = RemoteViews(c.packageName, R.layout.widget_lesson_row)
                for (index in start..start+1) {
                    val item = RemoteViews(c.packageName, R.layout.widget_lesson)
                    val lesson = day.optJSONObject(index)
                    if (lesson == null) {
                        item.setViewVisibility(R.id.lesson_cell, View.INVISIBLE)
                    } else {
                        item.setTextViewText(R.id.period, "${lesson.getInt("period")}교시")
                        item.setTextViewText(R.id.subject, lesson.getString("subject"))
                        val original = if (lesson.isNull("teacher")) "" else lesson.getString("teacher").trim()
                        val teacher = names.optJSONObject(lesson.getString("subject"))?.optString(original, original) ?: original
                        item.setTextViewText(R.id.teacher, teacher)
                        item.setViewVisibility(R.id.teacher, if (teacher.isEmpty()) View.GONE else View.VISIBLE)

                        val begin = lesson.optInt("startMinute", -1)
                        val end = lesson.optInt("endMinute", -1)
                        if (begin in 0..1439 && end in (begin + 1)..1440) {
                            if (minute in begin until end) {
                                status = "$dateLabel  ·  ${lesson.getInt("period")}교시 진행 중"
                                item.setInt(R.id.lesson_cell, "setBackgroundResource", R.drawable.widget_tile_active)
                            }
                            if (begin > minute) nextMinute = minOf(nextMinute, begin)
                            if (end > minute) nextMinute = minOf(nextMinute, end)
                        }
                    }
                    row.addView(R.id.lesson_row, item)
                }
                views.addView(R.id.lesson_grid, row)
            }
            views.setTextViewText(R.id.day_stamp, status)
            views.setTextViewText(R.id.widget_class, classLabel)
            views.setViewVisibility(R.id.widget_class, if (classLabel.isEmpty()) View.GONE else View.VISIBLE)
            val boundary = (now.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.MINUTE, nextMinute)
            }
            c.getSystemService(AlarmManager::class.java).set(AlarmManager.RTC, boundary.timeInMillis, boundaryIntent(c))
            views.setOnClickPendingIntent(R.id.today_card,PendingIntent.getActivity(c,0,Intent(c,MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
            ids.forEach { manager.updateAppWidget(it,views) }
            return ids.isNotEmpty()
        }
        fun week(config: JSONObject): JSONObject {
            val conn = URL(config.getString("url")).openConnection() as HttpURLConnection
            val data = try {
                conn.connectTimeout=8000; conn.readTimeout=35000
                JSONObject(conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() })
            } finally { conn.disconnect() }
            val lessons=data.getJSONObject("grades").getJSONObject(config.getString("grade")).getJSONArray(config.getString("room"))
            val fmt=SimpleDateFormat("yyyy-MM-dd",Locale.US).apply { timeZone=zone }
            val cal=Calendar.getInstance(zone).apply { time=fmt.parse(data.getString("start"))!! }
            val days=JSONObject()
            for (i in 0 until maxOf(7,lessons.length())) {
                val day=lessons.optJSONArray(i)
                val subjects=(0 until (day?.length() ?: 0)).map { day!!.getJSONObject(it) }
                    .sortedBy { it.getInt("period") }
                days.put(fmt.format(cal.time),JSONArray(subjects)); cal.add(Calendar.DATE,1)
            }
            return days
        }
    }
}

class TodayJob : JobService() {
    private var generation=0
    override fun onStartJob(params:JobParameters):Boolean {
        val store=TodayWidget.prefs(this)
        val config=store.getString("config",null) ?: return false
        val ticket=++generation
        Thread {
            val days=runCatching { TodayWidget.week(JSONObject(config)) }.onFailure { android.util.Log.w("SchoolzipToday", "Weekly widget refresh failed", it) }.getOrNull()
            android.os.Handler(mainLooper).post {
                if(ticket==generation) {
                    if(days!=null && store.getString("config",null)==config) store.edit().putString("days",days.toString()).apply()
                    TodayWidget.render(this)
                    jobFinished(params,days==null)
                }
            }
        }.start()
        return true
    }
    override fun onStopJob(params:JobParameters):Boolean { generation++; return true }
}
