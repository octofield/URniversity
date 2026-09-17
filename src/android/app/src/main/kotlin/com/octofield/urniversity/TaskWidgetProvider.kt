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
import androidx.annotation.RequiresApi
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/**
 * The home screen widget.
 *
 * Deliberately thin: it draws the header for the current state and hands the
 * list to WidgetListService. Which rows exist and what each tap means are
 * decided by buildWidgetSnapshot() on the Dart side; which of those views is
 * showing is decided locally, so a tab switch redraws without waking Dart.
 */
class TaskWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        render(context, appWidgetManager, appWidgetIds, widgetData)
    }

    companion object {
        private const val ROW_ACTION = "com.octofield.urniversity.WIDGET_ROW"

        /** Redraws every instance from what is on disk. What a tab switch calls. */
        fun redrawAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TaskWidgetProvider::class.java))
            if (ids.isEmpty()) return
            render(context, manager, ids, HomeWidgetPlugin.getData(context))
        }

        /**
         * Sets a colour from a resource. On Android 12+ the launcher resolves it
         * itself, so the widget follows a light/dark switch without a redraw;
         * before that the colour is fixed at the moment of drawing.
         */
        fun setColorRes(
            context: Context,
            views: RemoteViews,
            viewId: Int,
            method: String,
            colorRes: Int,
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setColor(viewId, method, colorRes)
            } else {
                views.setInt(viewId, method, context.getColor(colorRes))
            }
        }

        private fun render(
            context: Context,
            manager: AppWidgetManager,
            ids: IntArray,
            prefs: SharedPreferences,
        ) {
            val snapshot = WidgetData.snapshot(prefs)
            val state = WidgetData.readState(prefs)

            for (widgetId in ids) {
                val views = RemoteViews(context.packageName, R.layout.widget_task_list)

                bindChoice(context, views, R.id.tab_tasks, state.mode == WidgetData.MODE_TASKS,
                    action("mode", "value" to WidgetData.MODE_TASKS))
                bindChoice(context, views, R.id.tab_targets, state.mode == WidgetData.MODE_TARGETS,
                    action("mode", "value" to WidgetData.MODE_TARGETS))
                bindChoice(context, views, R.id.tab_goals, state.mode == WidgetData.MODE_GOALS,
                    action("mode", "value" to WidgetData.MODE_GOALS))

                // + adds whatever the current tab lists. It opens the app
                // directly: there is nothing to decide first, so no receiver hop
                views.setOnClickPendingIntent(R.id.add_button, HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(action("new", "kind" to newKind(state.mode))),
                ))

                // The period and the filter only mean anything for the task list
                val taskish = state.mode == WidgetData.MODE_TASKS ||
                    state.mode == WidgetData.MODE_PICKER
                views.setViewVisibility(R.id.period_row, if (taskish) View.VISIBLE else View.GONE)

                for ((viewId, period) in listOf(
                    R.id.period_all to WidgetData.PERIOD_ALL,
                    R.id.period_day to "day",
                    R.id.period_week to "week",
                    R.id.period_month to "month",
                )) {
                    bindChoice(context, views, viewId, state.period == period,
                        action("period", "value" to period))
                }

                val filterLabel = WidgetData.filterLabel(snapshot, state)
                    .ifEmpty { context.getString(R.string.widget_filter) }
                views.setTextViewText(R.id.filter_label, filterLabel)
                val filterColor = colorFor(state.mode == WidgetData.MODE_PICKER || state.filterId != null)
                setColorRes(context, views, R.id.filter_label, "setTextColor", filterColor)
                setColorRes(context, views, R.id.filter_arrow, "setColorFilter", filterColor)
                views.setOnClickPendingIntent(R.id.filter_button,
                    actionIntent(context, action("mode", "value" to WidgetData.MODE_PICKER)))

                views.setTextViewText(R.id.empty_label, WidgetData.emptyLabel(snapshot, state))
                views.setEmptyView(R.id.widget_list, R.id.empty_label)

                // A collection cannot carry a PendingIntent per row: it gets one
                // template, and each row supplies the rest through a fill-in intent
                views.setPendingIntentTemplate(R.id.widget_list, rowTemplate(context))

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Rows travel inside this one update. A service-backed list
                    // makes the system defer the update to the launcher, and the
                    // Pixel launcher on API 37 never applied those at all
                    views.setRemoteAdapter(R.id.widget_list, collectionItems(context, snapshot, state))
                    manager.updateAppWidget(widgetId, views)
                } else {
                    // The list is fed by WidgetListService. Each widget id needs its
                    // own data URI or the system hands every instance one factory
                    val serviceIntent = Intent(context, WidgetListService::class.java).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                    }
                    @Suppress("DEPRECATION")
                    views.setRemoteAdapter(R.id.widget_list, serviceIntent)
                    manager.updateAppWidget(widgetId, views)
                    @Suppress("DEPRECATION")
                    manager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
                }
            }
        }

        @RequiresApi(Build.VERSION_CODES.S)
        private fun collectionItems(
            context: Context,
            snapshot: JSONObject?,
            state: WidgetData.State,
        ): RemoteViews.RemoteCollectionItems {
            val builder = RemoteViews.RemoteCollectionItems.Builder()
                .setViewTypeCount(WidgetRowViews.VIEW_TYPE_COUNT)
            WidgetData.visibleRows(snapshot, state).forEachIndexed { index, row ->
                builder.addItem(index.toLong(), WidgetRowViews.build(context, state, row))
            }
            return builder.build()
        }

        // Matches the kinds homeWidgetLaunchProvider knows how to open
        private fun newKind(mode: String): String = when (mode) {
            WidgetData.MODE_TARGETS -> "semesterGoal"
            WidgetData.MODE_GOALS -> "futureGoal"
            else -> "task"
        }

        private fun colorFor(selected: Boolean): Int =
            if (selected) R.color.widget_accent else R.color.widget_muted

        private fun bindChoice(
            context: Context,
            views: RemoteViews,
            viewId: Int,
            selected: Boolean,
            uri: String,
        ) {
            setColorRes(context, views, viewId, "setTextColor", colorFor(selected))
            views.setOnClickPendingIntent(viewId, actionIntent(context, uri))
        }

        fun action(host: String, vararg params: Pair<String, String>): String {
            val query = params.joinToString("&") { "${it.first}=${it.second}" }
            return if (query.isEmpty()) "urniversity://$host" else "urniversity://$host?$query"
        }

        /**
         * A header tap. Goes to WidgetActionReceiver, which switches locally —
         * not to home_widget's background receiver, which would start a Flutter
         * engine for what is only a redraw.
         */
        private fun actionIntent(context: Context, uri: String): PendingIntent {
            val intent = Intent(context, WidgetActionReceiver::class.java).apply {
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
            val intent = Intent(context, WidgetActionReceiver::class.java).apply {
                action = ROW_ACTION
            }
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 31) flags = flags or PendingIntent.FLAG_MUTABLE
            return PendingIntent.getBroadcast(context, 0, intent, flags)
        }
    }
}
