package com.octofield.urniversity

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Every tap on the widget lands here and goes one of three ways.
 *
 * - Switching tab, period or filter is done right here against views Dart
 *   already computed. It used to go through WorkManager, a background Flutter
 *   engine and five Supabase queries — over a second per tap — for what is
 *   really just picking a different list.
 * - Opening an item, or the + button, brings the app forward.
 * - Ticking a task off is the only thing that still needs Dart, because it
 *   writes data.
 */
class WidgetActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val uri = intent.data ?: return
        when (uri.host) {
            HOST_OPEN, HOST_NEW -> launchApp(context, uri)
            HOST_MODE, HOST_PERIOD, HOST_FILTER -> switchLocally(context, uri)
            HOST_TOGGLE -> {
                tickLocally(context, uri, intent)
                forwardToDart(context, uri)
            }
            else -> forwardToDart(context, uri)
        }
    }

    /**
     * Strikes the row through before the write, which takes a Flutter engine
     * and a network round trip. On Android 12+ the box has already animated
     * in the launcher by now; this catches the rest of the row up with it.
     * If the write fails, Dart takes the tick back.
     */
    private fun tickLocally(context: Context, uri: Uri, intent: Intent) {
        // A checked-change response says which way the box went. A plain click
        // (Android 11 and below) only exists on unticked rows, so it ticks
        val checked = intent.getBooleanExtra(RemoteViews.EXTRA_CHECKED, true)
        if (WidgetData.setCheck(HomeWidgetPlugin.getData(context), uri.toString(), checked)) {
            TaskWidgetProvider.redrawAll(context)
        }
    }

    private fun launchApp(context: Context, uri: Uri) {
        // Reuses home_widget's launcher, which already deals with the
        // background-activity-start rules on Android 14 and 15
        runCatching {
            HomeWidgetLaunchIntent
                .getActivity(context, MainActivity::class.java, uri)
                .send()
        }.onFailure { Log.w(TAG, "could not open the app for $uri", it) }
    }

    private fun switchLocally(context: Context, uri: Uri) {
        val prefs = HomeWidgetPlugin.getData(context)
        val current = WidgetData.readState(prefs)
        val value = uri.getQueryParameter("value")

        val next = when (uri.host) {
            HOST_MODE -> {
                if (value == null) return
                // Tapping the filter button again while the picker is open closes it
                if (value == WidgetData.MODE_PICKER && current.mode == WidgetData.MODE_PICKER) {
                    current.copy(mode = WidgetData.MODE_TASKS)
                } else {
                    current.copy(mode = value)
                }
            }
            // Picking a period or a filter is the way back to the task list
            HOST_PERIOD -> {
                if (value == null) return
                current.copy(period = value, mode = WidgetData.MODE_TASKS)
            }
            else -> current.copy(
                filterId = uri.getQueryParameter("id")
                    .takeIf { uri.getQueryParameter("kind") != KIND_NONE },
                mode = WidgetData.MODE_TASKS,
            )
        }

        WidgetData.writeState(prefs, next)
        TaskWidgetProvider.redrawAll(context)
    }

    // Silent: hand it to the Dart background engine the way home_widget's own
    // helper would have
    private fun forwardToDart(context: Context, uri: Uri) {
        val forwarded = Intent().apply {
            component = ComponentName(context.packageName, BACKGROUND_RECEIVER)
            action = BACKGROUND_ACTION
            data = uri
        }
        context.sendBroadcast(forwarded)
    }

    companion object {
        private const val TAG = "WidgetActionReceiver"

        const val HOST_OPEN = "open"
        const val HOST_NEW = "new"
        const val HOST_MODE = "mode"
        const val HOST_PERIOD = "period"
        const val HOST_FILTER = "filter"
        const val HOST_TOGGLE = "toggle"
        private const val KIND_NONE = "none"

        private const val BACKGROUND_ACTION = "es.antonborri.home_widget.action.BACKGROUND"
        private const val BACKGROUND_RECEIVER =
            "es.antonborri.home_widget.HomeWidgetBackgroundReceiver"
    }
}
