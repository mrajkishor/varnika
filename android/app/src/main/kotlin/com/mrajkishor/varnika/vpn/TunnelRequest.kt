package com.mrajkishor.varnika.vpn

import com.wireguard.config.BadConfigException
import com.wireguard.config.Config
import com.wireguard.config.Interface
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream

/** Everything needed to bring a tunnel up, as sent from Flutter. */
data class TunnelRequest(
    val id: String,
    val name: String,
    val config: String,
    /** "all", "exclude" or "include". */
    val splitMode: String,
    val apps: List<String>,
) {
    fun toJson(): String = JSONObject()
        .put("id", id)
        .put("name", name)
        .put("config", config)
        .put("splitMode", splitMode)
        .put("apps", JSONArray(apps))
        .toString()

    /**
     * Parses [config] with the official WireGuard parser and applies Varnika's
     * split-tunneling choice on top of the [Interface] section.
     */
    fun buildConfig(): Config {
        val parsed = parseConfig(config)
        val src = parsed.`interface`
        val b = Interface.Builder()
            .addAddresses(src.addresses)
            .addDnsServers(src.dnsServers)
            .addDnsSearchDomains(src.dnsSearchDomains)
            .setKeyPair(src.keyPair)
        src.listenPort.ifPresent { b.setListenPort(it) }
        src.mtu.ifPresent { b.setMtu(it) }

        val cleanApps = apps.filter { it.isNotBlank() }.toSet()
        when {
            splitMode == "exclude" && cleanApps.isNotEmpty() -> b.excludeApplications(cleanApps)
            splitMode == "include" && cleanApps.isNotEmpty() -> b.includeApplications(cleanApps)
            else -> {
                // Respect any app rules already written in the .conf file.
                if (src.includedApplications.isNotEmpty()) b.includeApplications(src.includedApplications)
                else if (src.excludedApplications.isNotEmpty()) b.excludeApplications(src.excludedApplications)
            }
        }
        return Config.Builder()
            .setInterface(b.build())
            .addPeers(parsed.peers)
            .build()
    }

    companion object {
        fun fromJson(json: String): TunnelRequest {
            val o = JSONObject(json)
            val arr = o.optJSONArray("apps") ?: JSONArray()
            return TunnelRequest(
                id = o.getString("id"),
                name = o.getString("name"),
                config = o.getString("config"),
                splitMode = o.optString("splitMode", "all"),
                apps = List(arr.length()) { arr.getString(it) },
            )
        }

        fun fromArgs(args: Map<*, *>): TunnelRequest = TunnelRequest(
            id = args["id"] as String,
            name = args["name"] as String,
            config = args["config"] as String,
            splitMode = (args["splitMode"] as? String) ?: "all",
            apps = (args["apps"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
        )

        fun parseConfig(text: String): Config =
            Config.parse(ByteArrayInputStream(text.toByteArray(Charsets.UTF_8)))

        /** Returns null when the config is valid, otherwise a readable reason. */
        fun validate(text: String): String? = try {
            val cfg = parseConfig(text)
            when {
                cfg.peers.isEmpty() -> "The config has no [Peer] section"
                cfg.`interface`.addresses.isEmpty() -> "[Interface] is missing an Address"
                else -> null
            }
        } catch (e: BadConfigException) {
            val section = e.section.name.lowercase().replaceFirstChar { it.uppercase() }
            val location = e.location.name.lowercase().replace('_', ' ')
            val reason = e.reason.name.lowercase().replace('_', ' ')
            val text1 = e.text?.toString()?.takeIf { it.isNotBlank() }?.let { " (\"$it\")" } ?: ""
            "[$section] $location: $reason$text1"
        } catch (e: Exception) {
            e.message ?: "Invalid configuration"
        }
    }
}
