# Varnika · वर्णिक

A private, good-looking **WireGuard VPN client for Android**, built with Flutter.

Varnika has no accounts, no servers of its own, and no tracking. You bring a WireGuard config from your own server or provider; Varnika keeps it encrypted on the phone and connects with the official WireGuard engine.

## Features

**Core**
- **One-tap connect** with a live status orb, connection timer, and an ongoing notification that shows live traffic and has a *Disconnect* button.
- **Import tunnels** from a `.conf` file, by scanning a **QR code**, by pasting text, or **create one from scratch** with freshly generated keys.
- **Live traffic stats**: download and upload totals, current speed, a 60-second throughput graph, and **handshake health** (Healthy / Stale / No reply).
- **Split tunneling** per tunnel:
  - *Bypass*: chosen apps skip the VPN (useful for banking/UPI apps that block VPNs).
  - *Only*: only chosen apps use the VPN.
  - Changes apply immediately; Varnika reconnects for you.
- **Kill switch**: a guided setup for Android's system-level *Always-on VPN* + *Block connections without VPN*, with a live status check. Varnika reconnects your last tunnel automatically when Android starts it (at boot or after a restart).

**Extras**
- **Quick Settings tile**: toggle your last tunnel from the notification shade.
- **"What the internet sees"**: your public IP, location, and network before and after connecting (via ipinfo.io; can be turned off).
- **Insights**: total data protected, time connected, longest session, most-used tunnel, a 7-day usage chart, and a session log.
- **Live server switching**: pick another tunnel while connected and Varnika switches over.
- **Share and back up**: show a tunnel as a QR code, export a `.conf`, or copy the config.
- **Key generator**: create a WireGuard key pair, or derive a public key from a private key.
- **Personalise**: an emoji and a favourite star per tunnel; light, dark, or system theme.
- First-run onboarding and a custom adaptive launcher icon.

## Security notes

- Tunnel configs (which include private keys) are stored with `flutter_secure_storage`, which is backed by the Android Keystore.
- The last-used tunnel is also kept natively, encrypted with an AES-256-GCM key that never leaves the Android Keystore, so the Quick Settings tile and always-on VPN work without opening the app.
- Android backups and device-to-device transfer are disabled for app data, so keys are never copied to the cloud.
- Session history stores only tunnel name, times, and byte counts. It records no destinations.
- Exported files, QR codes, and copied configs contain your private key. Treat them like a password.

## Setting up a server (quick start)

Varnika works with any standard WireGuard server. On a Linux VPS:

```bash
sudo apt install wireguard qrencode
wg genkey | tee server.key | wg pubkey > server.pub
```

Create `/etc/wireguard/wg0.conf` on the server:

```ini
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = <contents of server.key>
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
# Your phone. Get its public key from Varnika > Settings > Key generator,
# or from Tunnels > Add > Create from scratch.
PublicKey = <phone public key>
AllowedIPs = 10.8.0.2/32
```

Enable forwarding and start it:

```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-wireguard.conf && sudo sysctl --system
sudo systemctl enable --now wg-quick@wg0
```

On the phone, the matching client config looks like this:

```ini
[Interface]
PrivateKey = <phone private key>
Address = 10.8.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = <contents of server.pub>
Endpoint = <server ip>:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

Tip: if you build the client config on the server, `qrencode -t ansiutf8 < phone.conf` prints a QR code that Varnika can scan.

## Building

Requirements: Flutter (stable; built with 3.47), Android SDK, and JDK 17+.

```bash
flutter pub get
flutter test                 # unit tests (config parser, models, formatting)
flutter run                  # on a connected device or emulator
flutter build apk --release  # build/app/outputs/flutter-apk/app-release.apk
```

VPN features need a real device or an emulator with Google APIs; the VPN permission dialog appears on first connect.

### Release signing

Without a key, release builds are signed with the debug key so they still install. To sign properly:

```bash
keytool -genkey -v -keystore ~/varnika-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias varnika
```

Then create `android/key.properties` (this file is git-ignored):

```properties
storeFile=/home/you/varnika-release.jks
storePassword=...
keyAlias=varnika
keyPassword=...
```

## Architecture

```
lib/
  main.dart, app.dart          App shell, theme, bottom navigation, onboarding gate
  theme.dart                   Indigo / marigold / teal design system (light + dark)
  models/                      WgConfig parser, TunnelProfile, VpnStatus, stats, sessions
  services/vpn_channel.dart    Typed platform-channel API to Kotlin
  services/tunnel_store.dart   Encrypted tunnel storage
  services/ip_lookup.dart      Public IP / location check
  state/app_state.dart         ChangeNotifier: tunnels, status, live stats, history
  screens/                     Home, Tunnels, Tunnel detail, Config editor, QR scan,
                               Split tunnel, Kill switch, Insights, Settings, Key tools
  widgets/                     Connect orb, sparkline, shared UI

android/app/src/main/kotlin/com/mrajkishor/varnika/
  MainActivity.kt              Hosts Flutter; forwards activity results
  VpnBridge.kt                 Method channel `varnika/vpn` + event channel `varnika/vpn/status`
  VarnikaApplication.kt        Initialises the tunnel manager
  vpn/TunnelManager.kt         Owns the WireGuard GoBackend; connect/disconnect/stats/always-on
  vpn/TunnelRequest.kt         Config parsing + split-tunnel rules (official WireGuard parser)
  vpn/TunnelNotifier.kt        Ongoing notification with live traffic + Disconnect
  vpn/VarnikaTileService.kt    Quick Settings tile
  vpn/DisconnectReceiver.kt    Notification action handler
  vpn/SecureStore.kt           Keystore AES-GCM storage for the last tunnel
  vpn/SessionHistory.kt        Rolling session log
```

The VPN itself runs on [`com.wireguard.android:tunnel`](https://git.zx2c4.com/wireguard-android/), the userspace Go implementation behind the official WireGuard Android app. Flutter never touches packets: it sends the config and split-tunnel choice to Kotlin, which builds a `com.wireguard.config.Config` and brings the tunnel up through Android's `VpnService`.

## License

Apache License 2.0. See [LICENSE](LICENSE).
WireGuard is a registered trademark of Jason A. Donenfeld.
