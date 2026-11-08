enum VpnState { down, connecting, up, disconnecting, error }

class VpnStatus {
  const VpnStatus({
    this.state = VpnState.down,
    this.tunnelId,
    this.tunnelName,
    this.since,
    this.error,
  });

  final VpnState state;
  final String? tunnelId;
  final String? tunnelName;
  final DateTime? since;
  final String? error;

  bool get isUp => state == VpnState.up;
  bool get isBusy =>
      state == VpnState.connecting || state == VpnState.disconnecting;

  factory VpnStatus.fromMap(Map<Object?, Object?> m) {
    final s = m['state'] as String? ?? 'down';
    final sinceMs = (m['since'] as num?)?.toInt();
    return VpnStatus(
      state: VpnState.values.firstWhere(
        (v) => v.name == s,
        orElse: () => VpnState.down,
      ),
      tunnelId: m['tunnelId'] as String?,
      tunnelName: m['tunnelName'] as String?,
      since: sinceMs == null || sinceMs <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(sinceMs),
      error: m['error'] as String?,
    );
  }
}

class TrafficStats {
  const TrafficStats({
    this.rxBytes = 0,
    this.txBytes = 0,
    this.lastHandshake,
    this.at,
  });

  final int rxBytes;
  final int txBytes;
  final DateTime? lastHandshake;
  final DateTime? at;

  static const zero = TrafficStats();

  factory TrafficStats.fromMap(Map<Object?, Object?> m) {
    final hs = (m['handshake'] as num?)?.toInt() ?? 0;
    return TrafficStats(
      rxBytes: (m['rx'] as num?)?.toInt() ?? 0,
      txBytes: (m['tx'] as num?)?.toInt() ?? 0,
      lastHandshake: hs > 0 ? DateTime.fromMillisecondsSinceEpoch(hs) : null,
      at: DateTime.now(),
    );
  }
}

/// A completed VPN session, recorded natively when a tunnel goes down.
class SessionRecord {
  const SessionRecord({
    required this.tunnelName,
    required this.start,
    required this.end,
    required this.rxBytes,
    required this.txBytes,
  });

  final String tunnelName;
  final DateTime start;
  final DateTime end;
  final int rxBytes;
  final int txBytes;

  Duration get duration => end.difference(start);
  int get totalBytes => rxBytes + txBytes;

  factory SessionRecord.fromMap(Map<Object?, Object?> m) => SessionRecord(
    tunnelName: m['name'] as String? ?? 'Tunnel',
    start: DateTime.fromMillisecondsSinceEpoch((m['start'] as num).toInt()),
    end: DateTime.fromMillisecondsSinceEpoch((m['end'] as num).toInt()),
    rxBytes: (m['rx'] as num?)?.toInt() ?? 0,
    txBytes: (m['tx'] as num?)?.toInt() ?? 0,
  );
}

class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    this.icon,
    this.isSystem = false,
  });

  final String packageName;
  final String label;
  final List<int>? icon;
  final bool isSystem;
}
