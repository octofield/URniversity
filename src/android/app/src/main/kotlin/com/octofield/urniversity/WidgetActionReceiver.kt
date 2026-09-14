package com.octofield.urniversity

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Splits a tap on a list row into the two things it can mean.
 *
 * A collection in a widget gets exactly ONE PendingIntent template for all of
 * its rows, but this widget has both silent actions (ticking a task off) and
 * ones that must bring the app forward (opening an item). The template points
 * here, and this decides which it was from the URI the row filled in.
 */
class WidgetActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val uri = intent.data ?: return

        if (uri.host == HOST_OPEN) {
            // Reuses home_widget's launcher, which already deals with the
            // background-activity-start rules on Android 14 and 15
            runCatching {
                HomeWidgetLaunchIntent
                    .getActivity(context, MainActivity::class.java, uri)
                    .send()
            }.onFailure { Log.w(TAG, "could not open the app for $uri", it) }
            return
        }

        // Everything else is silent: hand it to the Dart background engine the
        // same way home_widget's own helper would have
        val forwarded = Intent().apply {
            component = ComponentName(context.packageName, BACKGROUND_RECEIVER)
            action = BACKGROUND_ACTION
            data = uri
        }
        context.sendBroadcast(forwarded)
    }

    companion object {
        private const val TAG = "WidgetActionReceiver"
        private const val HOST_OPEN = "open"
        private const val BACKGROUND_ACTION = "es.antonborri.home_widget.action.BACKGROUND"
        private const val BACKGROUND_RECEIVER =
            "es.antonborri.home_widget.HomeWidgetBackgroundReceiver"
    }
}
