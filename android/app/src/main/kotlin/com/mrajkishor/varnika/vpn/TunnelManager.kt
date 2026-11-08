package com.mrajkishor.varnika.vpn

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.wireguard.android.backend.BackendException
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Process-wide owner of the single WireGuard tunnel.
 *
 * All backend calls run on one background thread; listeners are always
 * notified on the main thread. The Flutter bridge, notification, Quick
 * Settings tile and always-on callback all talk to this object.
 */
object TunnelManager {
    private const val TAG = "VarnikaTunnel"
    private const val LAST_TUNNEL = "last_tunnel"

    enum class State { DOWN, CONNECTING, UP, DISCONNECTING, ERROR }

    data class Status(
        val state: State = State.DOWN,
        val tunnelId: String? = null,
        val tunnelName: String? = null,
        val since: Long = 0,
        val error: String? = null,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "state" to state.name.lowercase(),
            "tunnelId" to tunnelId,
            "tunnelName" to tunnelName,
            "since" to since,
            "error" to error,
        )
    }

    data class Stats(val rx: Long = 0, val tx: Long = 0, val handshake: Long = 0) {
        fun toMap(): Map<String, Any> = mapOf("rx" to rx, "tx" to tx, "handshake" to handshake)
    }

    private lateinit var appContext: Context
    private val backend: GoBackend by lazy { GoBackend(appContext) }
    private val worker = Executors.newSingleThreadExecutor { Thread(it, "varnika-wg") }
    private val main = Handler(Looper.getMainLooper())
    private val listeners = CopyOnWriteArraySet<(Status) -> Unit>()

    private lateinit var secure: SecureStore
    lateinit var history: SessionHistory
        private set

    @Volatile var status = Status()
        private set
    @Volatile private var lastStats = Stats()
    @Volatile private var active: TunnelRequest? = null

    /** The one [Tunnel] instance the backend knows; its name must be short and simple. */
    private val tunnel = object : Tunnel {
        override fun getName() = "varnika"
        override fun onStateChange(newState: Tunnel.State) {
            // Called by GoBackend when the system tears the VPN down
            // (permission revoked, another VPN app took over, …).
            // Our own connect/disconnect calls move the status off UP *before*
            // asking the backend to stop, so they never land here.
            if (newState == Tunnel.State.DOWN && status.state == State.UP) {
                worker.execute {
                    if (status.state == State.UP) {
                        finishSession()
                        publish(Status())
                    }
                }
            }
        }
    }

    fun init(context: Context) {
        if (::appContext.isInitialized) return
        appContext = context.applicationContext
        secure = SecureStore(appContext)
        history = SessionHistory(appContext)
        TunnelNotifier.createChannel(appContext)
        // Android starts our VpnService directly when "Always-on VPN" is set.
        GoBackend.setAlwaysOnCallback { connectLast() }
    }

    fun addListener(l: (Status) -> Unit) { listeners.add(l) }
    fun removeListener(l: (Status) -> Unit) { listeners.remove(l) }

    private fun publish(s: Status) {
        status = s
        main.post {
            listeners.forEach { runCatching { it(s) } }
            TunnelNotifier.update(appContext, s, lastStats)
            VarnikaTileService.requestUpdate(appContext)
        }
    }

    fun lastRequest(): TunnelRequest? =
        secure.get(LAST_TUNNEL)?.let { runCatching { TunnelRequest.fromJson(it) }.getOrNull() }

    fun connectLast(onDone: ((String?) -> Unit)? = null) {
        val req = lastRequest()
        if (req == null) {
            onDone?.invoke("No tunnel has been used yet. Open Varnika to pick one.")
            return
        }
        connect(req, onDone)
    }

    /** Brings [req] up, replacing any tunnel that is already running. */
    fun connect(req: TunnelRequest, onDone: ((String?) -> Unit)? = null) {
        worker.execute {
            val error = try {
                val config = req.buildConfig()
                if (status.state == State.UP) {
                    // Switching servers: close the current session first.
                    publish(status.copy(state = State.DISCONNECTING))
                    finishSession()
                    backend.setState(tunnel, Tunnel.State.DOWN, null)
                }
                publish(Status(State.CONNECTING, req.id, req.name))
                backend.setState(tunnel, Tunnel.State.UP, config)
                active = req
                lastStats = Stats()
                runCatching { secure.put(LAST_TUNNEL, req.toJson()) }
                publish(Status(State.UP, req.id, req.name, System.currentTimeMillis()))
                startTicker()
                null
            } catch (e: Exception) {
                Log.w(TAG, "connect failed", e)
                val msg = friendly(e, req)
                publish(Status(State.ERROR, req.id, req.name, error = msg))
                publish(Status())
                msg
            }
            onDone?.let { cb -> main.post { cb(error) } }
        }
    }

    fun disconnect(onDone: ((String?) -> Unit)? = null) {
        worker.execute {
            val error = try {
                if (status.state == State.UP || status.state == State.CONNECTING) {
                    publish(status.copy(state = State.DISCONNECTING))
                    finishSession()
                    backend.setState(tunnel, Tunnel.State.DOWN, null)
                }
                publish(Status())
                null
            } catch (e: Exception) {
                Log.w(TAG, "disconnect failed", e)
                publish(Status())
                friendly(e)
            }
            onDone?.let { cb -> main.post { cb(error) } }
        }
    }

    fun toggle(onDone: ((String?) -> Unit)? = null) =
        if (status.state == State.UP) disconnect(onDone) else connectLast(onDone)

    /** Reads live counters; safe to call from any thread. */
    fun stats(): Stats {
        if (status.state != State.UP) return lastStats
        return try {
            val s = backend.getStatistics(tunnel)
            var handshake = 0L
            for (k in s.peers()) {
                val p = s.peer(k) ?: continue
                handshake = maxOf(handshake, p.latestHandshakeEpochMillis())
            }
            Stats(s.totalRx(), s.totalTx(), handshake).also { lastStats = it }
        } catch (e: Exception) {
            lastStats
        }
    }

    /** Always-on and lockdown flags; null if Android won't tell us right now. */
    fun killSwitchStatus(): Map<String, Boolean?> {
        val f = worker.submit<Map<String, Boolean?>> {
            mapOf(
                "alwaysOn" to runCatching { backend.isAlwaysOn }.getOrNull(),
                "lockdown" to runCatching { backend.isLockdownEnabled }.getOrNull(),
            )
        }
        return runCatching { f.get(3, TimeUnit.SECONDS) }
            .getOrDefault(mapOf("alwaysOn" to null, "lockdown" to null))
    }

    fun backendVersion(): String = runCatching { backend.version }.getOrDefault("unknown")

    private fun finishSession() {
        val s = status
        if (s.state != State.UP && s.state != State.DISCONNECTING) return
        val st = stats()
        history.add(s.tunnelName ?: "Tunnel", s.since, System.currentTimeMillis(), st.rx, st.tx)
        active = null
    }

    private val ticker = object : Runnable {
        override fun run() {
            if (status.state != State.UP) return
            worker.execute {
                val st = stats()
                main.post { TunnelNotifier.update(appContext, status, st) }
            }
            main.postDelayed(this, 2000)
        }
    }

    private fun startTicker() {
        main.removeCallbacks(ticker)
        main.postDelayed(ticker, 1000)
    }

    private fun friendly(e: Exception): String = when (e) {
        is BackendException -> when (e.reason) {
            BackendException.Reason.VPN_NOT_AUTHORIZED ->
                "Varnika isn't allowed to create a VPN. Tap connect again and accept the request."
            BackendException.Reason.DNS_RESOLUTION_FAILURE ->
                "Couldn't resolve the server address. Check your internet connection or the Endpoint."
            BackendException.Reason.UNABLE_TO_START_VPN ->
                "Android refused to start the VPN. Another VPN with lockdown may be active."
            BackendException.Reason.TUN_CREATION_ERROR ->
                "Couldn't create the VPN interface. Check the Address and DNS values."
            BackendException.Reason.TUNNEL_MISSING_CONFIG -> "The tunnel has no configuration."
            else -> "WireGuard error: ${e.reason.name.lowercase().replace('_', ' ')}"
        }
        else -> e.message ?: e.javaClass.simpleName
    }

    private fun friendly(e: Exception, req: TunnelRequest): String =
        if (e is com.wireguard.config.BadConfigException) {
            TunnelRequest.validate(req.config) ?: "Invalid configuration"
        } else {
            friendly(e)
        }
}
