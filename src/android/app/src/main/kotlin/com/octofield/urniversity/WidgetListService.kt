package com.octofield.urniversity

import android.content.Context
import android.graphics.drawable.Icon
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.octofield.urniversity.WidgetData.str
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

/**
 * Feeds the widget's list on Android 11 and below.
 *
 * Android 12+ does not come through here: TaskWidgetProvider hands the rows
 * over directly as RemoteCollectionItems. A service-backed list makes the
 * system defer every update, and the Pixel launcher on API 37 was seen never
 * applying those — the widget froze on whatever it showed first.
 */
class WidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        WidgetListFactory(applicationContext)
}

private class WidgetListFactory(private val context: Context) :
    RemoteViewsService.RemoteViewsFactory {

    private var rows: List<JSONObject> = emptyList()
    private var state = WidgetData.State()
    private var style: WidgetStyle? = null

    override fun onCreate() = Unit

    // Called on every notifyAppWidgetViewDataChanged, which is what a tab
    // switch triggers — so this re-reads the state as well as the snapshot
    override fun onDataSetChanged() {
        val prefs = HomeWidgetPlugin.getData(context)
        state = WidgetData.readState(prefs)
        style = WidgetStyle.of(prefs)
        rows = WidgetData.visibleRows(WidgetData.snapshot(prefs), state)
    }

    override fun onDestroy() = Unit

    override fun getCount(): Int = rows.size

    override fun getViewAt(position: Int): RemoteViews {
        val row = rows.getOrNull(position)
            ?: return RemoteViews(context.packageName, R.layout.widget_row)
        return WidgetRowViews.build(context, state, style ?: WidgetStyle.of(HomeWidgetPlugin.getData(context)), row)
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = WidgetRowViews.VIEW_TYPE_COUNT

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false
}

/**
 * Draws one list row. Knows nothing about tasks, goals or filters — WidgetData
 * picks the rows and this only draws them, for both the service above and the
 * direct collection on Android 12+.
 */
object WidgetRowViews {
    // A regular row and a picker section header
    const val VIEW_TYPE_COUNT = 2

    fun build(context: Context, state: WidgetData.State, style: WidgetStyle, row: JSONObject): RemoteViews {
        val title = row.str("title").orEmpty()

        if (row.optBoolean("header", false)) {
            return RemoteViews(context.packageName, R.layout.widget_row_header).apply {
                setTextViewText(R.id.row_title, title)
                TaskWidgetProvider.setColorRes(context, this, R.id.row_title, "setTextColor", style.muted)
            }
        }

        val views = RemoteViews(context.packageName, R.layout.widget_row)
        val checkAction = row.str("check_action")
        val tap = row.str("tap")
        // Only a task can be ticked from here, and only a ticked task is struck
        // through. A finished goal shows its tick but keeps its title as is
        val struck = checkAction != null && row.str("check") == WidgetData.CHECK_CHECKED

        views.setTextViewText(R.id.row_title, if (struck) strikethrough(title) else title)
        val titleColor = when {
            struck -> style.muted
            state.mode == WidgetData.MODE_PICKER && isCurrentFilter(tap, state) -> style.accent
            else -> style.text
        }
        TaskWidgetProvider.setColorRes(context, views, R.id.row_title, "setTextColor", titleColor)

        // Hidden rather than blank, so a row with nothing to add under its title
        // centres the title instead of leaving an empty line
        val subtitle = row.str("subtitle")
        views.setTextViewText(R.id.row_subtitle, subtitle.orEmpty())
        views.setViewVisibility(
            R.id.row_subtitle,
            if (subtitle == null) View.GONE else View.VISIBLE,
        )
        TaskWidgetProvider.setColorRes(context, views, R.id.row_subtitle, "setTextColor",
            if (struck) style.muted else style.accent)

        // ARGB arrives as an unsigned 32-bit number; toInt() wraps it back into
        // the signed colour Android expects
        val color = row.optLong("color", 0L).toInt()
        views.setViewVisibility(R.id.row_color, if (color == 0) View.INVISIBLE else View.VISIBLE)
        if (color != 0) views.setInt(R.id.row_color, "setBackgroundColor", color)

        bindCheck(context, views, state, style, row.str("check"), checkAction)

        // A collection shares one PendingIntent template, so each row carries
        // only the part that differs — the action URI
        tap?.let {
            views.setOnClickFillInIntent(R.id.row_body, Intent().setData(Uri.parse(it)))
        }

        return views
    }

    private fun bindCheck(
        context: Context,
        views: RemoteViews,
        state: WidgetData.State,
        style: WidgetStyle,
        check: String?,
        action: String?,
    ) {
        if (check != WidgetData.CHECK_CHECKED && check != WidgetData.CHECK_UNCHECKED) {
            // The picker has no tick box column at all; the goal lists keep the
            // space so their colour bars line up with the ticked ones
            views.setViewVisibility(
                R.id.row_check,
                if (state.mode == WidgetData.MODE_PICKER) View.GONE else View.INVISIBLE,
            )
            return
        }
        views.setViewVisibility(R.id.row_check, View.VISIBLE)
        val checked = check == WidgetData.CHECK_CHECKED
        val fillIn = action?.let { Intent().setData(Uri.parse(it)) }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // The style's tick box: CompoundButton.setButtonIcon is the one
            // way RemoteViews can swap a CheckBox's drawable
            views.setIcon(R.id.row_check, "setButtonIcon", Icon.createWithResource(context, style.checkSelector))
            views.setCompoundButtonChecked(R.id.row_check, checked)
            // A goal's tick is only a display; disabled so tapping cannot flip
            // a box that nothing would ever write
            views.setBoolean(R.id.row_check, "setEnabled", fillIn != null)
            fillIn?.let {
                views.setOnCheckedChangeResponse(R.id.row_check,
                    RemoteViews.RemoteResponse.fromFillInIntent(it))
            }
        } else {
            views.setImageViewResource(R.id.row_check,
                if (checked) style.checkOn else style.checkOff)
            fillIn?.let { views.setOnClickFillInIntent(R.id.row_check, it) }
        }
    }

    private fun isCurrentFilter(tap: String?, state: WidgetData.State): Boolean =
        tap != null && Uri.parse(tap).getQueryParameter("id") == state.filterId

    private fun strikethrough(text: String): CharSequence = SpannableString(text).apply {
        setSpan(StrikethroughSpan(), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }
}
