package com.mrajkishor.varnika

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toBitmap
import com.mrajkishor.varnika.vpn.TunnelManager
import com.mrajkishor.varnika.vpn.TunnelRequest
import com.wireguard.crypto.Key
import com.wireguard.crypto.KeyPair
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Implements the `varnika/vpn` method channel and the `varnika/vpn/status`
 * event channel used by `lib/services/vpn_channel.dart`.
 */
class VpnBridge(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val method = MethodChannel(messenger, "varnika/vpn")
    private val events = EventChannel(messenger, "varnika/vpn/status")
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var sink: EventChannel.EventSink? = null
    private val statusListener: (TunnelManager.Status) -> Unit = { sink?.success(it.toMap()) }

    private var pendingPrepare: MethodChannel.Result? = null
    private var pendingPick: MethodChannel.Result? = null
    private var pendingSave: Pair<MethodChannel.Result, String>? = null
    private var pendingNotif: MethodChannel.Result? = null

    init {
        method.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    fun dispose() {
        method.setMethodCallHandler(null)
        events.setStreamHandler(null)
        TunnelManager.removeListener(statusListener)
        io.shutdown()
    }

    // ------------------------------------------------------------- events

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        TunnelManager.addListener(statusListener)
        events.success(TunnelManager.status.toMap())
    }

    override fun onCancel(arguments: Any?) {
        TunnelManager.removeListener(statusListener)
        sink = null
    }

    // ------------------------------------------------------------- methods

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(TunnelManager.status.toMap())
            "prepare" -> prepare(result)
            "connect" -> {
                val req = try {
                    TunnelRequest.fromArgs(call.arguments as Map<*, *>)
                } catch (e: Exception) {
                    result.error("bad_args", "Invalid tunnel data", null); return
                }
                TunnelManager.connect(req) { err ->
                    if (err == null) result.success(null) else result.error("connect_failed", err, null)
                }
            }
            "disconnect" -> TunnelManager.disconnect { err ->
                if (err == null) result.success(null) else result.error("disconnect_failed", err, null)
            }
            "getStats" -> background(result) { TunnelManager.stats().toMap() }
            "validateConfig" -> result.success(TunnelRequest.validate(call.argument<String>("config") ?: ""))
            "listApps" -> background(result) { listApps(call.argument<Boolean>("includeSystem") ?: false) }
            "pickConfigFile" -> pickFile(result)
            "saveFile" -> saveFile(call.argument<String>("name") ?: "tunnel.conf", call.argument<String>("text") ?: "", result)
            "generateKeyPair" -> {
                val kp = KeyPair()
                result.success(mapOf("private" to kp.privateKey.toBase64(), "public" to kp.publicKey.toBase64()))
            }
            "publicKeyFor" -> result.success(
                runCatching { KeyPair(Key.fromBase64(call.argument<String>("privateKey"))).publicKey.toBase64() }
                    .getOrNull()
            )
            "killSwitchStatus" -> background(result) { TunnelManager.killSwitchStatus() }
            "openVpnSettings" -> {
                runCatching { activity.startActivity(Intent(Settings.ACTION_VPN_SETTINGS)) }
                    .onFailure { activity.startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS)) }
                result.success(null)
            }
            "requestNotificationPermission" -> requestNotifications(result)
            "getHistory" -> background(result) { TunnelManager.history.all() }
            "clearHistory" -> { TunnelManager.history.clear(); result.success(null) }
            "backendVersion" -> background(result) { TunnelManager.backendVersion() }
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            val r = runCatching(block)
            main.post {
                r.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("failed", it.message, null) },
                )
            }
        }
    }

    private fun prepare(result: MethodChannel.Result) {
        val intent = VpnService.prepare(activity)
        if (intent == null) { result.success(true); return }
        pendingPrepare?.success(false)
        pendingPrepare = result
        try {
            activity.startActivityForResult(intent, REQ_VPN)
        } catch (e: Exception) {
            pendingPrepare = null
            result.error("prepare_failed", "Couldn't open the VPN permission dialog", null)
        }
    }

    private fun pickFile(result: MethodChannel.Result) {
        pendingPick?.success(null)
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        activity.startActivityForResult(intent, REQ_PICK)
    }

    private fun saveFile(name: String, text: String, result: MethodChannel.Result) {
        pendingSave?.first?.success(false)
        pendingSave = result to text
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, name)
        }
        activity.startActivityForResult(intent, REQ_SAVE)
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) { result.success(true); return }
        pendingNotif?.success(false)
        pendingNotif = result
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIF)
    }

    /** Returns true when the result belonged to this bridge. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQ_VPN -> {
                pendingPrepare?.success(resultCode == Activity.RESULT_OK)
                pendingPrepare = null
            }
            REQ_PICK -> {
                val res = pendingPick ?: return true
                pendingPick = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) { res.success(null); return true }
                io.execute {
                    val out = runCatching { readText(uri) }
                    main.post {
                        out.fold(
                            onSuccess = { res.success(it) },
                            onFailure = { res.error("read_failed", it.message ?: "Couldn't read that file", null) },
                        )
                    }
                }
            }
            REQ_SAVE -> {
                val (res, text) = pendingSave ?: return true
                pendingSave = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) { res.success(false); return true }
                io.execute {
                    val ok = runCatching {
                        activity.contentResolver.openOutputStream(uri, "wt")!!.use {
                            it.write(text.toByteArray(Charsets.UTF_8))
                        }
                    }.isSuccess
                    main.post { res.success(ok) }
                }
            }
            else -> return false
        }
        return true
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQ_NOTIF) return false
        pendingNotif?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingNotif = null
        return true
    }

    private fun readText(uri: Uri): Map<String, String> {
        var name = "tunnel.conf"
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)
            ?.use { c ->
                if (c.moveToFirst()) {
                    c.getString(0)?.let { name = it }
                    if (!c.isNull(1) && c.getLong(1) > MAX_CONF_BYTES) {
                        throw IllegalArgumentException("That file is too large to be a WireGuard config")
                    }
                }
            }
        val bytes = activity.contentResolver.openInputStream(uri)!!.use { it.readBytes() }
        if (bytes.size > MAX_CONF_BYTES) throw IllegalArgumentException("That file is too large to be a WireGuard config")
        return mapOf("name" to name, "text" to String(bytes, Charsets.UTF_8))
    }

    private fun listApps(includeSystem: Boolean): List<Map<String, Any?>> {
        val pm = activity.packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val infos = if (Build.VERSION.SDK_INT >= 33) {
            pm.queryIntentActivities(launcher, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION") pm.queryIntentActivities(launcher, 0)
        }
        val seen = HashSet<String>()
        val own = activity.packageName
        return infos.mapNotNull { ri ->
            val ai = ri.activityInfo?.applicationInfo ?: return@mapNotNull null
            val pkg = ai.packageName
            if (pkg == own || !seen.add(pkg)) return@mapNotNull null
            val system = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0 &&
                (ai.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0
            if (system && !includeSystem) return@mapNotNull null
            val icon = runCatching {
                val bmp = ai.loadIcon(pm).toBitmap(96, 96, Bitmap.Config.ARGB_8888)
                ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
            }.getOrNull()
            mapOf(
                "package" to pkg,
                "label" to ai.loadLabel(pm).toString(),
                "icon" to icon,
                "system" to system,
            )
        }.sortedBy { (it["label"] as String).lowercase() }
    }

    companion object {
        private const val REQ_VPN = 7101
        private const val REQ_PICK = 7102
        private const val REQ_SAVE = 7103
        private const val REQ_NOTIF = 7104
        private const val MAX_CONF_BYTES = 256 * 1024
    }
}
