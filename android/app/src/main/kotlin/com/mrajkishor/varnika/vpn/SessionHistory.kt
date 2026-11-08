package com.mrajkishor.varnika.vpn

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** A small rolling log of finished VPN sessions (no keys, no destinations). */
class SessionHistory(context: Context) {
    private val prefs = context.getSharedPreferences("varnika_history", Context.MODE_PRIVATE)

    @Synchronized
    fun add(name: String, start: Long, end: Long, rx: Long, tx: Long) {
        if (end - start < 1000) return
        val arr = read()
        arr.put(
            JSONObject().put("name", name).put("start", start).put("end", end)
                .put("rx", rx).put("tx", tx)
        )
        val trimmed = JSONArray()
        val from = maxOf(0, arr.length() - MAX)
        for (i in from until arr.length()) trimmed.put(arr.get(i))
        prefs.edit().putString(KEY, trimmed.toString()).apply()
    }

    @Synchronized
    fun all(): List<Map<String, Any>> {
        val arr = read()
        return List(arr.length()) { i ->
            val o = arr.getJSONObject(i)
            mapOf(
                "name" to o.optString("name", "Tunnel"),
                "start" to o.getLong("start"),
                "end" to o.getLong("end"),
                "rx" to o.optLong("rx"),
                "tx" to o.optLong("tx"),
            )
        }.reversed()
    }

    @Synchronized
    fun clear() = prefs.edit().remove(KEY).apply()

    private fun read(): JSONArray = try {
        JSONArray(prefs.getString(KEY, "[]"))
    } catch (e: Exception) {
        JSONArray()
    }

    companion object {
        private const val KEY = "sessions"
        private const val MAX = 300
    }
}
