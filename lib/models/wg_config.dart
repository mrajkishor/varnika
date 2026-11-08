/// Lightweight parser for WireGuard wg-quick style configuration files.
///
/// The Android side re-validates every config with the official
/// `com.wireguard.config.Config` parser before connecting; this Dart parser
/// exists so the UI can show a readable summary (endpoint, addresses, DNS…)
/// without a platform round-trip, and so the logic is unit-testable.
library;

class WgPeer {
  WgPeer({
    required this.publicKey,
    this.endpoint,
    this.allowedIps = const [],
    this.presharedKey,
    this.persistentKeepalive,
  });

  final String publicKey;
  final String? endpoint;
  final List<String> allowedIps;
  final String? presharedKey;
  final int? persistentKeepalive;

  /// True when this peer captures all IPv4 (and optionally IPv6) traffic.
  bool get isFullTunnel =>
      allowedIps.contains('0.0.0.0/0') || allowedIps.contains('::/0');

  String? get endpointHost {
    final e = endpoint;
    if (e == null) return null;
    if (e.startsWith('[')) {
      final close = e.indexOf(']');
      return close > 0 ? e.substring(1, close) : e;
    }
    final colon = e.lastIndexOf(':');
    return colon > 0 ? e.substring(0, colon) : e;
  }
}

class WgConfig {
  WgConfig({
    required this.privateKey,
    this.addresses = const [],
    this.dns = const [],
    this.mtu,
    this.listenPort,
    this.peers = const [],
  });

  final String privateKey;
  final List<String> addresses;
  final List<String> dns;
  final int? mtu;
  final int? listenPort;
  final List<WgPeer> peers;

  WgPeer? get primaryPeer => peers.isEmpty ? null : peers.first;

  static final _base64Key = RegExp(r'^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw480]=$');

  static bool isValidKey(String key) => _base64Key.hasMatch(key.trim());

  static List<String> _splitList(String v) =>
      v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  /// Parses [text]; throws [FormatException] with a human readable message.
  static WgConfig parse(String text) {
    String? section;
    final iface = <String, String>{};
    final peerMaps = <Map<String, String>>[];
    var lineNo = 0;

    for (final raw in text.split(RegExp(r'\r?\n'))) {
      lineNo++;
      var line = raw;
      final hash = line.indexOf('#');
      if (hash >= 0) line = line.substring(0, hash);
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('[') && line.endsWith(']')) {
        final name = line.substring(1, line.length - 1).trim().toLowerCase();
        if (name == 'interface') {
          if (section == 'interface' || iface.isNotEmpty) {
            throw FormatException(
              'Line $lineNo: duplicate [Interface] section',
            );
          }
          section = 'interface';
        } else if (name == 'peer') {
          section = 'peer';
          peerMaps.add({});
        } else {
          throw FormatException('Line $lineNo: unknown section [$name]');
        }
        continue;
      }

      final eq = line.indexOf('=');
      if (eq <= 0) {
        throw FormatException('Line $lineNo: expected "Key = Value"');
      }
      final key = line.substring(0, eq).trim().toLowerCase();
      final value = line.substring(eq + 1).trim();

      switch (section) {
        case 'interface':
          // Repeated keys such as Address/DNS are additive in wg-quick.
          iface[key] = iface.containsKey(key) && _additive.contains(key)
              ? '${iface[key]}, $value'
              : value;
        case 'peer':
          final p = peerMaps.last;
          p[key] = p.containsKey(key) && key == 'allowedips'
              ? '${p[key]}, $value'
              : value;
        default:
          throw FormatException('Line $lineNo: setting outside of a section');
      }
    }

    if (section == null) {
      throw const FormatException('No [Interface] section found');
    }
    final privateKey = iface['privatekey'];
    if (privateKey == null || privateKey.isEmpty) {
      throw const FormatException('[Interface] is missing PrivateKey');
    }
    if (!isValidKey(privateKey)) {
      throw const FormatException('PrivateKey is not a valid WireGuard key');
    }

    int? parseInt(String? v, String label) {
      if (v == null) return null;
      final n = int.tryParse(v);
      if (n == null) throw FormatException('$label must be a number');
      return n;
    }

    final peers = <WgPeer>[];
    for (final (i, p) in peerMaps.indexed) {
      final pk = p['publickey'];
      if (pk == null || !isValidKey(pk)) {
        throw FormatException(
          'Peer ${i + 1} has a missing or invalid PublicKey',
        );
      }
      peers.add(
        WgPeer(
          publicKey: pk,
          endpoint: p['endpoint'],
          allowedIps: _splitList(p['allowedips'] ?? ''),
          presharedKey: p['presharedkey'],
          persistentKeepalive: parseInt(
            p['persistentkeepalive'],
            'PersistentKeepalive',
          ),
        ),
      );
    }

    return WgConfig(
      privateKey: privateKey,
      addresses: _splitList(iface['address'] ?? ''),
      dns: _splitList(iface['dns'] ?? ''),
      mtu: parseInt(iface['mtu'], 'MTU'),
      listenPort: parseInt(iface['listenport'], 'ListenPort'),
      peers: peers,
    );
  }

  static const _additive = {'address', 'dns'};

  /// Best-effort suggested display name from a file name like `in-mumbai-01.conf`.
  static String suggestName(String? fileName, {String fallback = 'My tunnel'}) {
    if (fileName == null || fileName.trim().isEmpty) return fallback;
    var n = fileName.trim();
    final slash = n.lastIndexOf(RegExp(r'[/\\]'));
    if (slash >= 0) n = n.substring(slash + 1);
    if (n.toLowerCase().endsWith('.conf')) n = n.substring(0, n.length - 5);
    n = n.replaceAll(RegExp(r'[_]+'), ' ').trim();
    return n.isEmpty ? fallback : n;
  }
}
