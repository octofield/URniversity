package com.octofield.urniversity

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Reads the snapshot Dart writes and the state the widget keeps for itself.
 *
 * Every view is already computed on the Dart side. This only picks which one is
 * showing and applies the filter by id membership — which tasks fall in a
 * period, and which ids a task counts under, are decided in
 * buildWidgetSnapshot(). Keeping that out of here is what lets a tab switch
 * happen without waking Dart at all.
 */
object WidgetData {
    const val KEY_SNAPSHOT = "widget_snapshot"
    const val KEY_STATE = "widget_state"

    const val MODE_TASKS = "tasks"
    const val MODE_TARGETS = "targets"
    const val MODE_GOALS = "goals"
    const val MODE_CLASSES = "classes"
    const val MODE_PICKER = "filterPicker"
    const val PERIOD_ALL = "all"
    const val PERIOD_DAY = "day"

    const val CHECK_UNCHECKED = "unchecked"
    const val CHECK_CHECKED = "checked"

    data class State(
        val mode: String = MODE_TASKS,
        val period: String = PERIOD_DAY,
        val filterId: String? = null,
    )

    fun readState(prefs: SharedPreferences): State {
        val raw = prefs.getString(KEY_STATE, null) ?: return State()
        return try {
            val json = JSONObject(raw)
            State(
                mode = json.str("mode") ?: MODE_TASKS,
                period = json.str("period") ?: PERIOD_DAY,
                filterId = json.str("filter_id"),
            )
        } catch (e: Exception) {
            // A state this build cannot read just means starting from the task list
            State()
        }
    }

    fun writeState(prefs: SharedPreferences, state: State) {
        val json = JSONObject()
            .put("mode", state.mode)
            .put("period", state.period)
            .put("filter_id", state.filterId ?: JSONObject.NULL)
        // commit, not apply: the redraw that follows reads it straight back
        prefs.edit().putString(KEY_STATE, json.toString()).commit()
    }

    fun snapshot(prefs: SharedPreferences): JSONObject? {
        val raw = prefs.getString(KEY_SNAPSHOT, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }

    private fun viewKey(state: State): String = when (state.mode) {
        MODE_TARGETS -> "targets"
        MODE_GOALS -> "goals"
        MODE_CLASSES -> "classes"
        MODE_PICKER -> "filter_picker"
        else -> "tasks_${state.period}"
    }

    /**
     * Ticks or unticks every row carrying [action], ahead of the write that
     * makes it true, so the row reacts on the tap instead of a second later.
     * A ticked task row also leaves the list at once (see [visibleRows]), the
     * way it does inside the app. Dart's next snapshot replaces this either
     * way, and takes the tick back if the write failed. Returns whether any
     * row changed.
     */
    fun setCheck(prefs: SharedPreferences, action: String, checked: Boolean): Boolean {
        val snapshot = snapshot(prefs) ?: return false
        val views = snapshot.optJSONObject("views") ?: return false
        var changed = false
        for (key in views.keys()) {
            val array = views.optJSONArray(key) ?: continue
            for (i in 0 until array.length()) {
                val row = array.optJSONObject(i) ?: continue
                if (row.str("check_action") != action) continue
                row.put("check", if (checked) CHECK_CHECKED else CHECK_UNCHECKED)
                changed = true
            }
        }
        if (changed) prefs.edit().putString(KEY_SNAPSHOT, snapshot.toString()).commit()
        return changed
    }

    /**
     * The rows to draw right now: the current view, filtered when it is the
     * task list.
     *
     * A ticked task row is dropped. Dart only ever puts outstanding tasks in a
     * task view, so a ticked one is always the row the user just tapped — and
     * it should leave the list there and then, as it does in the app, rather
     * than sit struck through until the write comes back. Target and vision
     * rows keep theirs: a finished target stays on the list, ticked.
     */
    fun visibleRows(snapshot: JSONObject?, state: State): List<JSONObject> {
        val array = snapshot?.optJSONObject("views")?.optJSONArray(viewKey(state))
            ?: return emptyList()
        val isTaskList = state.mode == MODE_TASKS
        val filterId = state.filterId.takeIf { isTaskList }
        return (0 until array.length())
            .mapNotNull { array.optJSONObject(it) }
            .filter { !isTaskList || it.str("check") != CHECK_CHECKED }
            .filter { filterId == null || it.optJSONArray("filters").has(filterId) }
    }

    fun emptyLabel(snapshot: JSONObject?, state: State): String {
        val key = when (state.mode) {
            MODE_TARGETS -> "targets"
            MODE_GOALS -> "goals"
            MODE_CLASSES -> "classes"
            MODE_PICKER -> "filter_picker"
            else -> "tasks"
        }
        return snapshot?.optJSONObject("empty")?.str(key).orEmpty()
    }

    /** The selected target or vision by name, or the generic label when there is none. */
    fun filterLabel(snapshot: JSONObject?, state: State): String {
        val fallback = snapshot?.str("filter_default").orEmpty()
        val id = state.filterId ?: return fallback
        return snapshot?.optJSONObject("filter_labels")?.str(id) ?: fallback
    }

    /**
     * A string field, or null. JSONObject.optString returns the literal text
     * "null" for a JSON null — which is how a missing subtitle ended up printed
     * on the widget — so every read goes through here instead.
     */
    fun JSONObject.str(key: String): String? = if (isNull(key)) null else optString(key)

    private fun JSONArray?.has(value: String): Boolean {
        if (this == null) return false
        return (0 until length()).any { optString(it) == value }
    }
}
