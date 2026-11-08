package com.mrajkishor.varnika.vpn

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast
import com.mrajkishor.varnika.MainActivity

/** Quick Settings tile that toggles the last-used tunnel. */
class VarnikaTileService : TileService() {
    private val listener: (TunnelManager.Status) -> Unit = { refresh() }

    override fun onStartListening() {
        super.onStartListening()
        TunnelManager.init(this)
        TunnelManager.addListener(listener)
        refresh()
    }

    override fun onStopListening() {
        TunnelManager.removeListener(listener)
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        val state = TunnelManager.status.state
        if (state == TunnelManager.State.UP || state == TunnelManager.State.CONNECTING) {
            TunnelManager.disconnect()
            return
        }
        // Need the user's consent or a tunnel choice? Open the app instead.
        if (VpnService.prepare(this) != null || TunnelManager.lastRequest() == null) {
            openApp()
            return
        }
        TunnelManager.connectLast { err ->
            if (err != null) Toast.makeText(applicationContext, err, Toast.LENGTH_LONG).show()
        }
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(
                PendingIntent.getActivity(this, 2, intent, PendingIntent.FLAG_IMMUTABLE)
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    private fun refresh() {
        val tile = qsTile ?: return
        val s = TunnelManager.status
        tile.state = when (s.state) {
            TunnelManager.State.UP -> Tile.STATE_ACTIVE
            else -> Tile.STATE_INACTIVE
        }
        tile.label = "Varnika"
        if (Build.VERSION.SDK_INT >= 29) {
            tile.subtitle = when (s.state) {
                TunnelManager.State.UP -> s.tunnelName ?: "On"
                TunnelManager.State.CONNECTING -> "Connecting…"
                else -> TunnelManager.lastRequest()?.name ?: "Off"
            }
        }
        tile.updateTile()
    }

    companion object {
        fun requestUpdate(ctx: Context) {
            runCatching {
                requestListeningState(ctx, ComponentName(ctx, VarnikaTileService::class.java))
            }
        }
    }
}
