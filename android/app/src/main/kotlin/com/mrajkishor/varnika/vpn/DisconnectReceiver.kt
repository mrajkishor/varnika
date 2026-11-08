package com.mrajkishor.varnika.vpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Handles the notification's "Disconnect" button. */
class DisconnectReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return
        TunnelManager.init(context)
        val pending = goAsync()
        TunnelManager.disconnect { pending.finish() }
    }

    companion object {
        const val ACTION = "com.mrajkishor.varnika.DISCONNECT"
    }
}
