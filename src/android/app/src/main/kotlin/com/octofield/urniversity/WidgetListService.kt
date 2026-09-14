package com.octofield.urniversity

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

/**
 * Feeds the widget's list.
 *
 * Knows nothing about tasks, goals or filters — it renders whatever rows the
 * Dart snapshot contains. Adding a new kind of row never needs a change here.
 */
class WidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        WidgetListFactory(applicationContext)
}

private class WidgetListFactory(private val context: Context) :
    RemoteViewsService.RemoteViewsFactory {

    private var rows: JSONArray = JSONArray()

    override fun onCreate() = Unit

    // Called on every notifyAppWidgetViewDataChanged, which is what re-reads
    // the snapshot Dart last wrote
    override fun onDataSetChanged() {
        val raw = HomeWidgetPlugin.getData(context).getString(KEY_SNAPSHOT, null)
        rows = try {
            if (raw == null) JSONArray() else JSONObject(raw).optJSONArray("rows") ?: JSONArray()
        } catch (e: Exception) {
            // A snapshot this build cannot read means an empty list, not a crash
            // inside the launcher's process
            JSONArray()
        }
    }

    override fun onDestroy() = Unit

    override fun getCount(): Int = rows.length()

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_row)
        val row = rows.optJSONObject(position) ?: return views

        val isHeader = row.optBoolean("header", false)
        views.setTextViewText(R.id.row_title, row.optString("title"))
        views.setTextColor(R.id.row_title, if (isHeader) COLOR_HEADER else COLOR_TITLE)

        val subtitle = row.optString("subtitle").takeUnless { it.isNullOrEmpty() }
        views.setTextViewText(R.id.row_subtitle, subtitle.orEmpty())
        views.setViewVisibility(
            R.id.row_subtitle,
            if (subtitle == null) View.GONE else View.VISIBLE,
        )

        val color = row.optInt("color", 0)
        views.setViewVisibility(R.id.row_color, if (color == 0) View.INVISIBLE else View.VISIBLE)
        if (color != 0) views.setInt(R.id.row_color, "setBackgroundColor", color)

        // The tick box is only drawn where ticking means something
        when (row.optString("check")) {
            CHECK_UNCHECKED -> showCheck(views, android.R.drawable.checkbox_off_background)
            CHECK_CHECKED -> showCheck(views, android.R.drawable.checkbox_on_background)
            else -> views.setViewVisibility(R.id.row_check, View.INVISIBLE)
        }

        // A collection shares one PendingIntent template, so each row carries
        // only the part that differs — the action URI
        row.optString("check_action").takeUnless { it.isNullOrEmpty() }?.let {
            views.setOnClickFillInIntent(R.id.row_check, Intent().setData(Uri.parse(it)))
        }
        row.optString("tap").takeUnless { it.isNullOrEmpty() }?.let {
            views.setOnClickFillInIntent(R.id.row_body, Intent().setData(Uri.parse(it)))
        }

        return views
    }

    private fun showCheck(views: RemoteViews, drawable: Int) {
        views.setViewVisibility(R.id.row_check, View.VISIBLE)
        views.setImageViewResource(R.id.row_check, drawable)
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    companion object {
        private const val KEY_SNAPSHOT = "widget_snapshot"
        private const val CHECK_UNCHECKED = "unchecked"
        private const val CHECK_CHECKED = "checked"

        // AppColors.textPrimary and AppColors.textTertiary
        private const val COLOR_TITLE = 0xFF2A1E12.toInt()
        private const val COLOR_HEADER = 0xFFB09A84.toInt()
    }
}
