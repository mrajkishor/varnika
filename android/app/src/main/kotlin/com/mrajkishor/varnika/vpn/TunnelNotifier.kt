package com.mrajkishor.varnika.vpn

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.mrajkishor.varnika.MainActivity
import com.mrajkishor.varnika.R
import java.util.Locale

/** The ongoing "Connected to …" notification with live traffic and a Disconnect action. */
object TunnelNotifier {
    private const val CHANNEL = "vpn_status"
    private const val ID = 4242

    fun createChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = ctx.getSystemService(NotificationManager::class.java)
        val ch = NotificationChannel(CHANNEL, "VPN status", NotificationManager.IMPORTANCE_LOW).apply {
            description = "Shows when Varnika is connected, with live traffic"
            setShowBadge(false)
        }
        nm.createNotificationChannel(ch)
    }

    private fun canPost(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    fun update(ctx: Context, status: TunnelManager.Status, stats: TunnelManager.Stats) {
        val nm = NotificationManagerCompat.from(ctx)
        if (status.state != TunnelManager.State.UP && status.state != TunnelManager.State.CONNECTING) {
            nm.cancel(ID)
            return
        }
        if (!canPost(ctx)) return

        val open = PendingIntent.getActivity(
            ctx, 0,
            Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getBroadcast(
            ctx, 1,
            Intent(ctx, DisconnectReceiver::class.java).setAction(DisconnectReceiver.ACTION),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val name = status.tunnelName ?: "WireGuard"
        val builder = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_varnika)
            .setColor(0xFFE8833A.toInt())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(open)
            .addAction(0, "Disconnect", stop)

        if (status.state == TunnelManager.State.CONNECTING) {
            builder.setContentTitle("Connecting to $name…").setProgress(0, 0, true)
        } else {
            builder.setContentTitle("Protected · $name")
                .setContentText("↓ ${bytes(stats.rx)}   ↑ ${bytes(stats.tx)}")
                .setWhen(status.since)
                .setUsesChronometer(true)
                .setShowWhen(true)
        }
        try {
            nm.notify(ID, builder.build())
        } catch (_: SecurityException) {
            // Permission revoked between the check and the call.
        }
    }

    fun bytes(b: Long): String {
        if (b < 1024) return "$b B"
        val units = arrayOf("KB", "MB", "GB", "TB")
        var v = b / 1024.0
        var i = 0
        while (v >= 1024 && i < units.size - 1) { v /= 1024; i++ }
        return String.format(Locale.US, if (v < 10) "%.1f %s" else "%.0f %s", v, units[i])
    }
}
