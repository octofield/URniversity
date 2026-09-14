package com.octofield.urniversity

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/**
 * The home screen widget.
 *
 * Deliberately thin: it renders whatever snapshot Dart last wrote and turns
 * taps into action URIs. Which rows to show, what they say, and what each tap
 * means are all decided by buildWidgetSnapshot() on the Dart side, so there is
 * no business logic here that could drift out of step with the app.
 */
class TaskWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val snapshot = widgetData.getString(KEY_SNAPSHOT, null)
        val mode = readString(snapshot, "mode") ?: MODE_TASKS
        val period = readString(snapshot, "period") ?: PERIOD_DAY
        val filterLabel = readString(snapshot, "filter_label").orEmpty()
        val emptyLabel = readString(snapshot, "empty").orEmpty()

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_task_list)

            bindTab(context, views, R.id.tab_tasks, mode == MODE_TASKS, MODE_TASKS)
            bindTab(context, views, R.id.tab_targets, mode == MODE_TARGETS, MODE_TARGETS)
            bindTab(context, views, R.id.tab_goals, mode == MODE_GOALS, MODE_GOALS)

            // The period and the filter only mean anything for the task list
            val taskish = mode == MODE_TASKS || mode == MODE_PICKER
            val rowVisibility = if (taskish) View.VISIBLE else View.GONE
            views.setViewVisibility(R.id.period_row, rowVisibility)

            bindPeriod(context, views, R.id.period_day, period == PERIOD_DAY, PERIOD_DAY)
            bindPeriod(context, views, R.id.period_week, period == PERIOD_WEEK, PERIOD_WEEK)
            bindPeriod(context, views, R.id.period_month, period == PERIOD_MONTH, PERIOD_MONTH)

            views.setTextViewText(R.id.filter_button, filterLabel)
            views.setOnClickPendingIntent(
                R.id.filter_button,
                backgroundIntent(context, action("mode", "value" to MODE_PICKER)),
            )

            views.setTextViewText(R.id.empty_label, emptyLabel)
            views.setEmptyView(R.id.widget_list, R.id.empty_label)

            // The list is fed by WidgetListService, which re-reads the snapshot.
            // Each widget id needs its own data URI or the system hands every
            // instance the same factory
            val serviceIntent = Intent(context, WidgetListService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)

            // A collection cannot carry a PendingIntent per row: it gets one
            // template, and each row supplies the rest through a fill-in intent
            views.setPendingIntentTemplate(R.id.widget_list, rowTemplate(context))

            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
        }
    }

    private fun bindTab(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        selected: Boolean,
        mode: String,
    ) {
        views.setTextColor(viewId, if (selected) COLOR_SELECTED else COLOR_UNSELECTED)
        views.setOnClickPendingIntent(
            viewId,
            backgroundIntent(context, action("mode", "value" to mode)),
        )
    }

    private fun bindPeriod(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        selected: Boolean,
        period: String,
    ) {
        views.setTextColor(viewId, if (selected) COLOR_SELECTED else COLOR_UNSELECTED)
        views.setOnClickPendingIntent(
            viewId,
            backgroundIntent(context, action("period", "value" to period)),
        )
    }

    companion object {
        private const val KEY_SNAPSHOT = "widget_snapshot"

        private const val MODE_TASKS = "tasks"
        private const val MODE_TARGETS = "targets"
        private const val MODE_GOALS = "goals"
        private const val MODE_PICKER = "filterPicker"
        private const val PERIOD_DAY = "day"
        private const val PERIOD_WEEK = "week"
        private const val PERIOD_MONTH = "month"

        // App palette: AppColors.primary and AppColors.textTertiary
        private const val COLOR_SELECTED = 0xFFA07850.toInt()
        private const val COLOR_UNSELECTED = 0xFFB09A84.toInt()

        // home_widget keeps its action string private to that package, and its
        // own helper builds the PendingIntent with FLAG_IMMUTABLE — which
        // silently stops a list row's fill-in intent from ever being applied.
        // The template below has to be mutable, so the value is repeated here.
        private const val BACKGROUND_ACTION = "es.antonborri.home_widget.action.BACKGROUND"
        private const val BACKGROUND_RECEIVER =
            "es.antonborri.home_widget.HomeWidgetBackgroundReceiver"

        fun action(host: String, vararg params: Pair<String, String>): String {
            val query = params.joinToString("&") { "${it.first}=${it.second}" }
            return if (query.isEmpty()) "urniversity://$host" else "urniversity://$host?$query"
        }

        /** Silent: handled by the Dart background engine, the app never opens. */
        fun backgroundIntent(context: Context, uri: String): PendingIntent {
            val intent = Intent().apply {
                component = ComponentName(context.packageName, BACKGROUND_RECEIVER)
                action = BACKGROUND_ACTION
                data = Uri.parse(uri)
            }
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
            // Distinct request codes, or every header button would collapse
            // into one PendingIntent
            return PendingIntent.getBroadcast(context, uri.hashCode(), intent, flags)
        }

        /**
         * The one template every row fills in. Mutable on purpose: an immutable
         * template cannot take the per-row data, and every tap would arrive
         * carrying no URI at all.
         */
        private fun rowTemplate(context: Context): PendingIntent {
            // WidgetActionReceiver, not home_widget's: a row tap can mean two
            // different things and only that receiver can tell them apart
            val intent = Intent(context, WidgetActionReceiver::class.java).apply {
                action = BACKGROUND_ACTION
            }
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 31) flags = flags or PendingIntent.FLAG_MUTABLE
            return PendingIntent.getBroadcast(context, 0, intent, flags)
        }

        private fun readString(json: String?, key: String): String? {
            if (json == null) return null
            return try {
                val value = JSONObject(json).optString(key)
                if (value.isNullOrEmpty()) null else value
            } catch (e: Exception) {
                null
            }
        }
    }
}
