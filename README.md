# Varnika · वर्णिक

A private, good-looking **WireGuard VPN client for Android**, built with Flutter.

Varnika has no accounts, no servers of its own, and no tracking. You bring a WireGuard config from your own server or a provider; Varnika keeps it encrypted on the phone and connects using the official WireGuard engine.

### ▶ [See how Varnika works: the interactive guide](https://htmlpreview.github.io/?https://github.com/mrajkishor/varnika/blob/main/docs/index.html)

An interactive, visual walkthrough of the complete flow ([`docs/index.html`](docs/index.html)):

- **Live tunnel simulator:** flip the VPN on and watch readable traffic turn into scrambled data, and see what the Wi‑Fi owner and websites can see.
- **Two halves and the handshake:** why your phone and the server must know each other's keys.
- **The complete flow in 9 steps:** a phone mockup for each screen, plus what the app does underneath (Flutter → Kotlin → WireGuard).
- **`.conf` explorer:** tap any line to learn what it does, and try `AllowedIPs` values to see where traffic goes.
- **Where configs come from:** VPN providers, server tools, by hand, and Create from scratch.
- **Split tunneling playground:** tick apps and see which go through the tunnel and which go direct.
- **Kill switch simulator:** drop the tunnel on a train ride and see what leaks, with and without the kill switch.
- **Use cases and case studies:** a student on public Wi‑Fi, a self-hoster with a home NAS, a design studio team, and a researcher abroad.
- **Inside the app:** an animated architecture diagram that traces one tap on Connect through every layer.

> Prefer a cleaner URL? Turn on GitHub Pages (**Settings → Pages → Deploy from a branch → `main` / `/docs`**) and the guide will also be available at `https://mrajkishor.github.io/varnika/`.

---

## Contents

0. [Interactive guide (visual walkthrough)](https://htmlpreview.github.io/?https://github.com/mrajkishor/varnika/blob/main/docs/index.html)
1. [What is this app for?](#1-what-is-this-app-for)
2. [Explain it like I'm six](#2-explain-it-like-im-six)
3. [How a VPN works (and where Varnika fits)](#3-how-a-vpn-works-and-where-varnika-fits)
4. [Who should use Varnika](#4-who-should-use-varnika)
5. [A day with Varnika: a complete example](#5-a-day-with-varnika-a-complete-example)
6. [The `.conf` file explained](#6-the-conf-file-explained)
7. [Where do `.conf` files come from?](#7-where-do-conf-files-come-from)
8. [Example configs for common situations](#8-example-configs-for-common-situations)
9. [Setting up your own server, step by step](#9-setting-up-your-own-server-step-by-step)
10. [Using every feature: worked examples](#10-using-every-feature-worked-examples)
11. [Troubleshooting](#11-troubleshooting)
12. [FAQ](#12-faq)
13. [Features at a glance](#13-features-at-a-glance)
14. [Security and privacy](#14-security-and-privacy)
15. [Building the app](#15-building-the-app)
16. [Architecture](#16-architecture)
17. [License](#17-license)

---

## 1. What is this app for?

Varnika is **the phone side of a VPN**. It builds an encrypted tunnel from your Android phone to a WireGuard server and sends your internet traffic through it.

It is **not** a VPN service like NordVPN or Proton VPN. Those companies give you an app *and* their servers. Varnika gives you only the app. You connect it to:

- **your own server**, such as a cheap cloud server or a computer at home or the office, or
- **a provider that gives out WireGuard config files**, such as Mullvad or Proton VPN.

Once connected, you get three things:

| Without a VPN | With Varnika connected |
|---|---|
| The Wi‑Fi owner, your ISP or your mobile carrier can see which sites you visit | They only see encrypted data going to one server |
| Websites see your real IP address and approximate location | Websites see your **server's** address and location |
| You can't reach devices on your home or office network from outside | You can, if your server is on that network |

## 2. Explain it like I'm six

Imagine passing a secret note to a friend across the classroom. Normally the note goes from kid to kid, and every kid can open it and read it. That's the internet without a VPN.

Now imagine a **secret tube** from your desk straight to your best friend's desk. You drop the note in, it zooms through, and nobody in the middle can see it. Your best friend then hands the note to whoever it's for, so the teacher only sees your friend handing it over, not you.

- The **secret tube** is the VPN.
- **Your best friend** is the server.
- **Varnika** is the button on your desk that builds the tube and tells you "tube is working!" or "uh oh, tube is broken!"

Varnika is only the button. You still need a friend at the other end of the tube, which means a server.

## 3. How a VPN works (and where Varnika fits)

```
WITHOUT VPN
  Phone ──── café Wi‑Fi ──── ISP ──── website
            (can see)      (can see)  (sees your real IP)

WITH VARNIKA
  Phone ══════ encrypted WireGuard tunnel ══════ Your server ──── website
            (café Wi‑Fi and ISP see only scrambled data)        (sees the server's IP)
```

There are always **two halves**:

| Half | What it is | Who provides it |
|---|---|---|
| **Server** | A computer running WireGuard that forwards your traffic | You, your company, or a VPN provider |
| **Client** | The app on your phone that builds the tunnel | **Varnika** |

The two halves are matched by a small text file called a **`.conf` file** (explained in [section 6](#6-the-conf-file-explained)). You load that file into Varnika, tap connect, and you're done.

**WireGuard** is the VPN protocol, meaning the rules for how the encrypted tunnel works. It's modern, fast and open source, and it's built into Linux. Varnika uses the official WireGuard Android library under the hood.

## 4. Who should use Varnika

| You are… | Why Varnika helps |
|---|---|
| **Someone who uses public Wi‑Fi** (airports, cafés, hotels, college) | Nobody on that network can snoop on your traffic |
| **Privacy-minded** and you don't trust VPN companies | With your own server, nobody else sees or logs your traffic |
| **A self-hoster** with a NAS, Home Assistant, CCTV or Plex at home | Reach them securely from anywhere, as if you were at home |
| **A developer or IT admin** | Reach staging servers, internal dashboards and databases on a private network |
| **Travelling abroad** | Put a server in your home country to keep using home services and apps |
| **A small team** | Give each member a config to the office network |
| **Already a WireGuard user** | You get a nicer client: split tunneling, live stats, kill switch guide, Quick Settings tile, usage history |

**Who it's not for (yet):** someone who just wants "a VPN" with no setup. They'd need a server first. Commercial VPN apps solve that with a backend that creates configs automatically after login; see [section 7](#7-where-do-conf-files-come-from) and the [FAQ](#12-faq).

## 5. A day with Varnika: a complete example

**Meet Riya.** She lives in Bhubaneswar. Her brother rents a small server in Mumbai and runs WireGuard on it.

### One-time setup (5 minutes)

1. Her brother runs a command on the server to add her (see [section 9](#9-setting-up-your-own-server-step-by-step)). The server creates her keys and a file called `riya-mumbai.conf`, and prints it as a QR code.
2. Riya installs Varnika and goes through the 3-page welcome.
3. She taps **Add tunnel → Scan QR code** and points the camera at her brother's screen.
4. Varnika shows the config with a **Preview** (endpoint, address, DNS). She names it **"Mumbai"** and taps **Save tunnel**.
5. In the tunnel's details she taps the emoji and picks 🏠, and taps ☆ to make it a favourite.

### At the airport

1. Riya is on free airport Wi‑Fi. She opens Varnika.
   - The screen says **"You're not protected"**.
   - The *Your visible address* card shows something like 🇮🇳 *Bhubaneswar, Odisha · Airport Wi‑Fi ISP*.
2. She taps the big round button.
   - The first time, Android asks *"Varnika wants to set up a VPN connection"*. She taps **OK**. This happens only once.
   - Android may also ask to allow notifications. She allows it so she can see the status notification.
3. The button turns teal and says **Protected**.
   - The headline says **"You're protected"**.
   - The address card now says 🇮🇳 *Mumbai, Maharashtra · (her brother's hosting company)*.
   - The **Session** card shows a running timer, download and upload totals, current speed, and **Handshake: Healthy**.
   - A **Last minute** graph shows her live download and upload speed.
4. A notification appears: **Protected · Mumbai ↓ 12 MB ↑ 1.4 MB**, with a **Disconnect** button.

### A problem: her UPI app refuses to work

Her UPI app says *"VPN detected, please disable it"*. Many Indian banking and UPI apps do this.

1. She goes to **Tunnels → Mumbai → Split tunneling**.
2. She chooses **Bypass**, searches for her UPI app, ticks it, and taps **Save**.
3. Because she's connected, Varnika reconnects automatically to apply the change.
4. Now the UPI app uses normal internet and works; everything else stays protected.

### Boarding

She pulls down the notification shade and taps **Disconnect** in the notification. Or she uses the **Varnika VPN** tile she added to Quick Settings.

### Later that evening

In **Insights** she sees *Data protected: 58 MB · Time connected: 41m*, a 7-day bar chart, and today's session in **Recent sessions**.

## 6. The `.conf` file explained

The `.conf` file is **WireGuard's standard configuration format**, not a protocol of its own. Every WireGuard app reads the same format, whether on Android, iOS, Windows, macOS or Linux, so a file made for one works in all of them.

### A complete example

```ini
# Riya's phone → Mumbai server
[Interface]                       # ── about YOU (this phone)
PrivateKey = yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk=
Address = 10.8.0.2/32, fd42:42:42::2/128
DNS = 1.1.1.1, 1.0.0.1
MTU = 1420

[Peer]                            # ── about the SERVER
PublicKey = xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=
PresharedKey = FpCyhws9cxwWoV4xELtfJvjJN+zQVRPISllRWgeopVE=
Endpoint = 203.0.113.10:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

> The keys above are examples. Never use keys from a README; always generate your own.

### Every line explained

**`[Interface]`: your phone**

| Key | Required? | Meaning | Example |
|---|---|---|---|
| `PrivateKey` | **Yes** | Your secret key, like a house key. Never share it. | `yAnz5…BmK=` |
| `Address` | **Yes** (for Varnika) | Your phone's address *inside* the tunnel. Usually `/32` for IPv4 and `/128` for IPv6. | `10.8.0.2/32` |
| `DNS` | No | Who turns website names into addresses while connected. If missing, Android uses its default. | `1.1.1.1, 9.9.9.9` |
| `MTU` | No | Max packet size. Leave it out unless you have problems; `1280`–`1420` are common. | `1420` |
| `ListenPort` | No | Local port. Not needed on phones. | `51820` |
| `ExcludedApplications` | No | Android-only: apps that skip the VPN, by package name | `com.phonepe.app` |
| `IncludedApplications` | No | Android-only: only these apps use the VPN | `org.mozilla.firefox` |

**`[Peer]`: the server**

| Key | Required? | Meaning | Example |
|---|---|---|---|
| `PublicKey` | **Yes** | The server's identity. Proves you're talking to the real server. | `xTIB…p8Dg=` |
| `Endpoint` | Yes, for phones | Where the server is: `host:port`. Can be an IP or a domain name. | `vpn.example.com:51820` |
| `AllowedIPs` | **Yes** | Which destinations go through the tunnel (see below). | `0.0.0.0/0, ::/0` |
| `PresharedKey` | No | An extra shared secret for added protection. Must match the server. | `FpCy…pVE=` |
| `PersistentKeepalive` | No | Sends a tiny ping every N seconds so mobile networks don't drop the connection. `25` is typical. | `25` |

### `AllowedIPs`: the most important line

| Value | What goes through the tunnel | Use case |
|---|---|---|
| `0.0.0.0/0, ::/0` | **Everything** (IPv4 + IPv6) | Privacy, public Wi‑Fi |
| `0.0.0.0/0` | All IPv4 only | Like above, but IPv6 traffic may bypass the VPN. Add `::/0` to avoid leaks. |
| `192.168.1.0/24` | Only your home network | Reach your NAS or cameras while normal browsing stays direct |
| `10.0.0.0/8, 172.16.0.0/12` | Only private company networks | Office/intranet access |

### What's flexible and what's not

**Flexible**
- Comments start with `#`, anywhere on a line.
- Blank lines and the order of lines don't matter.
- Key names are case-insensitive: `PrivateKey`, `privatekey` and `PRIVATEKEY` are the same.
- Lists are comma-separated, and `Address` or `DNS` can be repeated on separate lines.
- Optional lines can simply be left out.
- More than one `[Peer]` is allowed.

**Strict**
- Exactly **one** `[Interface]` and **at least one** `[Peer]`.
- Only known setting names. A typo like `Adress =` makes the file invalid.
- Keys must be real WireGuard keys: **44 characters** of base64 ending in `=`.
- Linux-server-only lines such as `PostUp`, `PostDown`, `Table` and `SaveConfig` belong on servers. Don't put them in a phone config.

Varnika checks every file twice: first with its own parser, for friendly line-numbered messages like *"Line 3: expected Key = Value"*, then with the official WireGuard parser before connecting.

### Other VPN formats (not supported)

| VPN type | File or link format | Works in Varnika? |
|---|---|---|
| **WireGuard** | `.conf` | ✅ Yes |
| OpenVPN | `.ovpn` | ❌ No |
| V2Ray / Xray | `vless://…`, `vmess://…` | ❌ No |
| IPsec / IKEv2 | system settings / profiles | ❌ No |

## 7. Where do `.conf` files come from?

Usually **software generates them**, but a person can also write one by hand. Either way, the **keys** are always generated by software.

### Way 1: a VPN provider (easiest)

Some providers let you download WireGuard configs from their website. The exact menu names change over time, but the flow is roughly:

1. Log in to the provider's website.
2. Find the **WireGuard configuration** or **config generator** page.
3. Pick a country or server and click **Download** (a `.conf` file) or **Show QR code**.
4. In Varnika: **Add tunnel → Import .conf file** or **Scan QR code**.

Providers known to offer WireGuard config files include **Mullvad**, **Proton VPN**, **IVPN**, and **AirVPN**. Check your provider's help pages for "WireGuard manual configuration".

### Way 2: a setup tool on your own server (most common for self-hosters)

| Tool | What it is | How you add a phone |
|---|---|---|
| **wg-easy** | Docker container with a web dashboard | Click **+ New**, enter "riya", then download the file or show its QR code |
| **PiVPN** | Installer for Raspberry Pi or Debian/Ubuntu | `pivpn add -n riya`, then `pivpn -qr riya` to show a QR code |
| **wireguard-install.sh** (angristan) | One-file install script | Run the script again and choose "Add a new client" |
| **Firewalla, OPNsense, pfSense, UniFi, many home routers** | Built-in WireGuard server | Use the router's VPN page to add a peer and export its config |

Each tool does the same three things: it creates the phone's keys, registers the phone on the server, and writes `riya.conf`, often also showing it as a QR code.

### Way 3: by hand (for learning, or full control)

You generate keys with `wg genkey` and type the rest yourself. [Section 9](#9-setting-up-your-own-server-step-by-step) walks through this completely.

### Way 4: Varnika's "Create from scratch"

**Tunnels → Add → Create from scratch** makes Varnika:
- generate a **fresh key pair** on the phone, so the private key never leaves the phone, and
- fill in a template like this:

```ini
[Interface]
PrivateKey = (generated by Varnika)
# Your public key (add it to the server): (generated by Varnika)
Address = 10.8.0.2/32
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = <server public key>
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

You then (1) give the **public key** shown in the comment to whoever runs the server, and (2) replace `<server public key>` and the `Endpoint` with the real values. Varnika can't fill those in, because the server belongs to someone else.

### Why the app can't make a working config on its own

Both sides must agree:

```
 Phone knows:  its own private key  +  server's PUBLIC key  +  server address
 Server knows: its own private key  +  phone's PUBLIC key   +  phone's tunnel address
```

If the server hasn't been told your phone's public key, it silently ignores you, and Varnika will show **Handshake: Waiting** or **No reply**. That's why a working `.conf` always needs something on the server side to register you. Commercial VPN apps hide this step behind a login and a backend API.

## 8. Example configs for common situations

Replace every `<…>` with your real values.

### A. Full privacy (all traffic through the VPN)

```ini
[Interface]
PrivateKey = <phone private key>
Address = 10.8.0.2/32, fd42:42:42::2/128
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = <server public key>
Endpoint = <server-ip-or-domain>:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

### B. Only reach your home network (browsing stays normal)

Your home LAN is `192.168.1.0/24` and the WireGuard server runs at home (on a Raspberry Pi or router). Use a dynamic DNS name if your home IP changes.

```ini
[Interface]
PrivateKey = <phone private key>
Address = 10.8.0.3/32
# DNS = 192.168.1.1   # optional: use your home router as DNS (e.g. Pi-hole)

[Peer]
PublicKey = <home server public key>
Endpoint = myhome.duckdns.org:51820
AllowedIPs = 10.8.0.0/24, 192.168.1.0/24
PersistentKeepalive = 25
```

Now `http://192.168.1.50` (your NAS) opens from anywhere, while YouTube still goes direct.

### C. Office / intranet access

```ini
[Interface]
PrivateKey = <phone private key>
Address = 10.20.0.15/32
DNS = 10.20.0.1

[Peer]
PublicKey = <office gateway public key>
PresharedKey = <shared secret from IT>
Endpoint = vpn.company.example:51820
AllowedIPs = 10.20.0.0/16, 10.30.0.0/16
PersistentKeepalive = 25
```

### D. Full tunnel, but banking apps bypass it (written in the file)

Usually you'd set this in **Split tunneling** instead (see [10.4](#104-split-tunneling)), but Varnika also honours these Android-only lines in a `.conf` file:

```ini
[Interface]
PrivateKey = <phone private key>
Address = 10.8.0.2/32
DNS = 1.1.1.1
ExcludedApplications = com.phonepe.app, net.one97.paytm, com.google.android.apps.nbu.paisa.user

[Peer]
PublicKey = <server public key>
Endpoint = <server>:51820
AllowedIPs = 0.0.0.0/0, ::/0
```

When a tunnel's split-tunnel mode in the app is **All apps**, the file's own `ExcludedApplications`/`IncludedApplications` lines are used. When you choose **Bypass** or **Only** in the app, the app's choice wins.

### E. Only one app through the VPN

```ini
[Interface]
PrivateKey = <phone private key>
Address = 10.8.0.4/32
DNS = 1.1.1.1
IncludedApplications = org.mozilla.firefox

[Peer]
PublicKey = <server public key>
Endpoint = <server>:51820
AllowedIPs = 0.0.0.0/0, ::/0
```

### F. Unreliable mobile network (smaller packets)

If websites half-load or some apps hang while connected, lower the MTU:

```ini
[Interface]
PrivateKey = <phone private key>
Address = 10.8.0.2/32
DNS = 1.1.1.1
MTU = 1280
```

## 9. Setting up your own server, step by step

This example uses an **Ubuntu 22.04/24.04** cloud server (DigitalOcean, Hetzner, AWS Lightsail, Oracle Cloud free tier, etc.). It takes about 10 minutes.

### Step 1: Install WireGuard

```bash
sudo apt update
sudo apt install -y wireguard qrencode
```

### Step 2: Create the server's keys

```bash
cd /etc/wireguard
umask 077
wg genkey | sudo tee server.key | wg pubkey | sudo tee server.pub
```

The second line prints the **server public key**. Every phone config needs it.

### Step 3: Find the server's internet-facing network interface

```bash
ip route list default
# default via 203.0.113.1 dev eth0 ...   ← here it's "eth0" (could be ens3, enp1s0, …)
```

### Step 4: Create the server config `/etc/wireguard/wg0.conf`

```ini
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = <paste contents of server.key>
# Share the server's internet with VPN clients (replace eth0 if different):
PostUp   = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
```

### Step 5: Allow traffic forwarding and open the port

```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-wireguard.conf
sudo sysctl --system

# If you use ufw:
sudo ufw allow 51820/udp
```

Also open **UDP 51820** in your cloud provider's firewall or security group if it has one. This is the most commonly missed step.

### Step 6: Start WireGuard

```bash
sudo systemctl enable --now wg-quick@wg0
sudo wg show       # should list interface wg0
```

### Step 7: Add a phone (Riya)

```bash
cd /etc/wireguard
wg genkey | sudo tee riya.key | wg pubkey | sudo tee riya.pub
```

Add her as a peer at the end of `/etc/wireguard/wg0.conf`:

```ini
[Peer]
# Riya's phone
PublicKey = <contents of riya.pub>
AllowedIPs = 10.8.0.2/32
```

Each phone gets a different address: `10.8.0.2`, `10.8.0.3`, `10.8.0.4`, …

Apply it:

```bash
sudo systemctl restart wg-quick@wg0
```

### Step 8: Write Riya's phone config

Create `riya-mumbai.conf`:

```ini
[Interface]
PrivateKey = <contents of riya.key>
Address = 10.8.0.2/32
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = <contents of server.pub>
Endpoint = <server public IP>:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

### Step 9: Get it onto the phone

Pick one:

- **QR code (easiest):** `qrencode -t ansiutf8 < riya-mumbai.conf` prints a QR code in the terminal. In Varnika, tap **Add tunnel → Scan QR code**.
- **File:** send `riya-mumbai.conf` to the phone securely, then use **Add tunnel → Import .conf file**.
- **Paste:** copy the text, then use **Add tunnel → Paste config**.

Then delete `riya.key` and `riya-mumbai.conf` from the server if you don't need them, since they contain her private key.

### Step 10: Check it works

On the server, after Riya connects:

```bash
sudo wg show
# peer: <riya public key>
#   latest handshake: 5 seconds ago        ← success
#   transfer: 1.20 MiB received, 8.43 MiB sent
```

In Varnika: **Handshake: Healthy**, and the address card shows the server's location.

### Using the Key generator instead

To keep Riya's private key off the server entirely:

1. Riya opens **Tunnels → Add → Create from scratch**. Varnika makes her keys on the phone.
2. She sends her brother only the **public key** from the comment line.
3. He adds it as a `[Peer]` (Step 7, skipping key generation) and tells her the server's public key and IP.
4. She fills those into the template and saves.

## 10. Using every feature: worked examples

### 10.1 Adding tunnels

**Tunnels tab → Add** (or **Add tunnel** on the home screen when you have none):

| Option | What happens | Example |
|---|---|---|
| **Import .conf file** | Opens Android's file picker. The name comes from the file name. If the file has a problem, the editor opens with the error so you can fix it. | `in_mumbai_01.conf` becomes tunnel **"in mumbai 01"** |
| **Scan QR code** | Opens the camera and accepts only WireGuard configs (must contain `[Interface]` and `PrivateKey`). Has a torch button. | Scan from `qrencode` or wg-easy |
| **Paste config** | Opens the editor pre-filled with your clipboard | Copied from an email or chat |
| **Create from scratch** | Generates keys and a template ([section 7](#way-4-varnikas-create-from-scratch)) | Your own new server |

The **editor** shows a live **Preview** (Endpoint, Address, DNS, Peers, Routing) as you type, and a clear error box if something's wrong, for example:

- *"PrivateKey is not a valid WireGuard key"*
- *"Peer 1 has a missing or invalid PublicKey"*
- *"Line 7: expected "Key = Value""*
- *"[Interface] is missing an Address"*

### 10.2 Connecting and disconnecting

| Where | How |
|---|---|
| **Home screen** | Tap the big round button. It shows **Connect**, then **Connecting** (spinning ring), then **Protected** (teal with ripples). |
| **Tunnels tab** | Use the switch on any tunnel card |
| **Tunnel details** | **Connect** / **Disconnect** button |
| **Notification** | **Disconnect** button |
| **Quick Settings tile** | Tap to toggle the last-used tunnel |

The first connect shows Android's VPN permission dialog. That's normal and only happens once.

### 10.3 Reading the live stats

While connected, the home screen shows:

| Card | Example | Meaning |
|---|---|---|
| **Session timer** | `00:41:07` | How long you've been connected |
| **Download** | `58 MB · 4.2 Mbps` | Total received, current speed |
| **Upload** | `6.1 MB · 320 Kbps` | Total sent, current speed |
| **Handshake** | `Healthy · 32s ago` | Last time the server answered |
| **Last minute** graph | Two lines | Download (teal) and upload (violet) speed over 60 seconds |
| **The internet now sees** | 🇩🇪 `Frankfurt, DE` | Your public IP as websites see it |

**Handshake meanings:**

| Shows | Means | What to do |
|---|---|---|
| **Waiting** | No reply from the server yet | Normal for a few seconds; see [Troubleshooting](#11-troubleshooting) if it stays |
| **Healthy** | Server replied within ~2.5 minutes | All good |
| **Stale** | No reply for 2.5–5 minutes | Network may be flaky |
| **No reply** | No reply for 5+ minutes | The tunnel is effectively down; check the server or network |

### 10.4 Split tunneling

**Tunnels → (a tunnel) → Split tunneling**

| Mode | Meaning | Example |
|---|---|---|
| **All apps** | Every app uses the VPN | Maximum privacy on public Wi‑Fi |
| **Bypass** | Ticked apps skip the VPN | PhonePe, Paytm, Google Pay and bank apps that block VPNs; Netflix if your server's country has a different catalogue |
| **Only** | Only ticked apps use the VPN | Just Firefox goes through your server; everything else stays fast and direct |

- Use the search box to find apps; ticked apps are listed first.
- **System apps** shows pre-installed apps too.
- If the tunnel is connected when you save, Varnika **reconnects automatically** to apply it.
- Leaving with unsaved changes asks *"Discard changes?"*.

### 10.5 Kill switch (never leak traffic)

Android only lets the **system** block internet when a VPN drops, so Varnika guides you there.

**Home → 🛡 icon** (top right), or **Settings → Kill switch & always-on**:

1. Connect a tunnel at least once, so Android knows which one to start.
2. Tap **Open VPN settings**.
3. Tap the ⚙ gear next to **Varnika**.
4. Turn on **Always-on VPN**.
5. Turn on **Block connections without VPN**. This is the kill switch.

Back in Varnika, the **Status** card shows **Always-on VPN: On** and **Block connections without VPN: On**, and the banner turns green: *"Kill switch is on"*. Android only reports this while Varnika is connected; tap refresh if it says *Unknown*.

With always-on enabled, Android starts Varnika's VPN at boot and after crashes, and **Varnika reconnects your last-used tunnel automatically**.

> With "Block connections without VPN" on, apps you set to **Bypass** in split tunneling still use your normal connection.

### 10.6 Switching servers while connected

Tap the tunnel card under the big button on **Home** and pick another tunnel. Varnika closes the current tunnel, saves that session to history, and connects to the new one. For example, switch from 🏠 *Mumbai* to 🇩🇪 *Frankfurt* in one tap.

### 10.7 Quick Settings tile

1. Swipe down twice from the top of the screen.
2. Tap ✎ **Edit**.
3. Drag **Varnika VPN** into your active tiles.

The tile shows *On* with the tunnel name, *Connecting…*, or *Off* with the last tunnel's name. Tapping it toggles the **last-used tunnel**. If Android hasn't granted VPN permission yet, or you haven't used a tunnel yet, it opens the app instead. Long-press the tile to open Varnika.

### 10.8 "What the internet sees" (IP check)

The bottom card on Home shows your public IP, city, country flag and network owner, before and after connecting. It's the quickest way to prove the VPN works.

| Before connecting | After connecting |
|---|---|
| 🇮🇳 `49.37.x.x` · Bhubaneswar, Odisha · *Your ISP* | 🇮🇳 `203.0.113.10` · Mumbai, Maharashtra · *Your hosting company* |

Pull down to refresh. The lookup uses **ipinfo.io**; turn it off in **Settings → Check my IP on connect**.

### 10.9 Insights

The **Insights** tab shows:
- **Data protected**: total download + upload across all sessions
- **Time connected**: total
- **Longest session**
- **Most used** tunnel
- **Last 7 days** bar chart (download + upload per day; tap a bar for exact numbers)
- **Recent sessions**: tunnel, date, time, duration, data

Sessions are recorded when a tunnel disconnects, including disconnects from the notification, the tile, or Android. The last 300 sessions are kept. Use the 🗑 icon to clear them. Only tunnel names, times and byte counts are stored, never websites or destinations.

### 10.10 Sharing, exporting and backing up a tunnel

**Tunnels → (a tunnel)**:

| Action | Use it to |
|---|---|
| **Show as QR code** | Scan it into Varnika or the official WireGuard app on another phone or tablet |
| **Export .conf file** | Save a backup (e.g. to Downloads or Drive) via Android's "Save as" dialog |
| **Copy config** | Paste it into a password manager |
| Long-press **Endpoint** or **Server key** | Copy just that value |

⚠️ All of these include your **private key**. Anyone with it can use your tunnel. Share only with devices you own, and store backups somewhere private.

> Each device should have its **own** config and keys. Using the same config on two devices at once causes them to fight over the connection.

### 10.11 Organising tunnels

- **Emoji**: tap the big emoji in tunnel details and pick one (🏠 💼 🇮🇳 🇺🇸 🎮 …).
- **Favourite**: tap ☆. Favourites stay at the top of the list.
- **Rename**, **Edit config**, **Delete**: in the ⋮ menu. Editing a connected tunnel reconnects it with the new settings.
- The list is sorted by favourites first, then most recently used.

### 10.12 Key generator

**Settings → Key generator**:
- **New key pair**: a fresh private key (hidden by default; tap 👁 to show) and public key, each with a copy button. Tap ↻ for another pair.
- **Public key from private key**: paste a private key to get its public key, handy if you only kept the private key.

### 10.13 Appearance and settings

- **Theme**: System / Light / Dark.
- **Check my IP on connect**: on/off.
- **Status notification**: tap to (re)request notification permission (Android 13+).
- **About**: shows the WireGuard backend version.

## 11. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| **Handshake stays "Waiting" / "No reply"** | Server not reachable, or keys don't match | Check UDP **51820** is open in the server firewall **and** cloud security group; confirm `Endpoint` IP/port; make sure the server has *this phone's* public key as a `[Peer]`; run `sudo wg show` on the server |
| **"Couldn't resolve the server address"** | `Endpoint` uses a domain name that can't be looked up | Check spelling, or use the IP address; check that your normal internet works |
| **Connected, handshake Healthy, but no websites load** | Server isn't forwarding traffic, or DNS problem | On the server, enable `net.ipv4.ip_forward=1` and check the `PostUp` MASQUERADE line uses the right interface name; add `DNS = 1.1.1.1` to the phone config |
| **Some sites or apps half-load or hang** | MTU too large for your network | Add `MTU = 1280` under `[Interface]` |
| **Banking / UPI app says "VPN detected"** | The app blocks VPNs | Add it to **Split tunneling → Bypass** |
| **"Android refused to start the VPN"** | Another VPN app is set as always-on with lockdown | Turn off always-on for the other VPN in Android VPN settings |
| **"Varnika isn't allowed to create a VPN"** | VPN permission was declined | Tap connect again and choose **OK** |
| **Import fails with a line-numbered error** | Typo or missing value in the file | The editor opens; fix the line shown and save |
| **"Peer 1 has a missing or invalid PublicKey"** | The template placeholder `<server public key>` is still there | Replace it with the real 44-character server key |
| **QR scan says "That QR code isn't a WireGuard config"** | It's a link or a different VPN type | Make sure the QR encodes the full `.conf` text |
| **Camera doesn't open for QR** | Camera permission denied | Android Settings → Apps → Varnika → Permissions → Camera |
| **No status notification** | Notification permission denied (Android 13+) | **Settings → Status notification**, or Android Settings → Apps → Varnika → Notifications |
| **IP card still shows your real location** | `AllowedIPs` doesn't include everything, or the check ran before connecting | Use `0.0.0.0/0, ::/0` for full tunnel; pull down to refresh |
| **Kill switch status says "Unknown"** | Android only reports it while connected | Connect, then tap refresh |
| **Two devices keep disconnecting each other** | Same config used on both | Give each device its own keys and address |

## 12. FAQ

**Is Varnika a free VPN?**
Varnika is a free *app*, but it isn't a VPN *service*. You need a server or a provider's config. A small cloud server costs roughly ₹300–500 per month, and some cloud providers have free tiers.

**Does Varnika see or log my traffic?**
No. Varnika has no servers or accounts. Traffic goes from your phone directly to *your* server. The only network request Varnika makes itself is the optional IP check to ipinfo.io.

**Can I use configs from the official WireGuard app?**
Yes. Export them (or show the QR code) from the official app and import or scan them into Varnika. It works the other way round too.

**Can I connect to two tunnels at once?**
No. Android allows one VPN at a time. You can switch between tunnels instantly from the home screen.

**Does it work on iPhone?**
Not currently; Varnika is Android-only (Android 7.0 and newer).

**Why does Android show a key icon 🔑 in the status bar?**
That's Android's standard indicator that a VPN is active.

**Will the VPN slow down my internet?**
WireGuard is very fast. Speed mostly depends on your server's location and bandwidth. A nearby server is faster than one on another continent.

**Can Varnika get configs automatically, like NordVPN?**
Not today. That needs a backend service that creates a config for each user after they sign in (generating keys, registering the peer on the server, and sending the config to the app). It's a natural next step for this project.

**Is it legal?**
Using a VPN is legal in most countries, including India, but some countries restrict VPNs. Follow your local laws and your network's rules.

## 13. Features at a glance

**Core**
- One-tap connect with an animated status orb, session timer, and an ongoing notification with live traffic and a *Disconnect* button
- Import from `.conf` file, QR code, or pasted text, or create from scratch with generated keys
- Live stats: totals, current speed, 60-second throughput graph, handshake health
- Per-tunnel split tunneling: *Bypass* or *Only* selected apps; applied instantly
- Kill switch: guided Always-on + Block-without-VPN setup with live status; auto-reconnect of the last tunnel when Android starts the VPN

**Extras**
- Quick Settings tile
- Public IP and location check (optional)
- Insights: totals, longest session, most-used tunnel, 7-day chart, session log
- Live server switching
- Share as QR, export `.conf`, copy config
- Key generator and public-key derivation
- Emoji and favourites per tunnel; light/dark/system themes
- First-run onboarding, branded launcher icon and splash screen

## 14. Security and privacy

- Tunnel configs (including private keys) are stored with `flutter_secure_storage`, which is backed by the **Android Keystore**.
- The last-used tunnel is also stored natively, encrypted with an **AES-256-GCM** key that never leaves the Android Keystore, so the Quick Settings tile and always-on VPN work without opening the app.
- **Android backups and device-to-device transfer are disabled** for app data, so keys are never copied to the cloud.
- Session history stores only tunnel name, times and byte counts. **No destinations or websites** are recorded.
- "Create from scratch" generates keys **on the phone**; the private key never needs to leave it.
- Exported files, QR codes and copied configs contain your private key. Treat them like a password.
- The VPN engine is the official [WireGuard Android library](https://git.zx2c4.com/wireguard-android/).

## 15. Building the app

Requirements: Flutter (stable; built with 3.47), Android SDK, JDK 17+.

```bash
flutter pub get
flutter test                 # unit + widget tests (config parser, models, formatting, screens)
flutter run                  # on a connected device or emulator
flutter build apk --release  # → build/app/outputs/flutter-apk/app-release.apk
```

VPN features need a real device or an emulator with Google APIs. The VPN permission dialog appears on first connect.

### Release signing

Without a key, release builds are signed with the debug key so they still install. To sign properly:

```bash
keytool -genkey -v -keystore ~/varnika-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias varnika
```

Then create `android/key.properties` (git-ignored):

```properties
storeFile=/home/you/varnika-release.jks
storePassword=...
keyAlias=varnika
keyPassword=...
```

## 16. Architecture

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
                               Split tunnel, Kill switch, Insights, Settings, Key tools,
                               Onboarding
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

**How a connect works:**

```
Tap Connect (Flutter)
  → VpnChannel.prepare()      Android VPN permission dialog (first time only)
  → VpnChannel.connect()      sends config text + split-tunnel choice to Kotlin
      → TunnelRequest.buildConfig()   official WireGuard parser + app include/exclude rules
      → GoBackend.setState(UP)        WireGuard starts via Android VpnService
      → status events → Flutter UI, notification, Quick Settings tile
  → AppState polls stats every second → speeds, graph, handshake health
```

Flutter never touches packets: it sends the config and split-tunnel choice to Kotlin, which builds a `com.wireguard.config.Config` and brings the tunnel up through Android's `VpnService` using [`com.wireguard.android:tunnel`](https://git.zx2c4.com/wireguard-android/).

## 17. License

Apache License 2.0. See [LICENSE](LICENSE).
WireGuard is a registered trademark of Jason A. Donenfeld.
