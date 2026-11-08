import 'wg_config.dart';

/// How a tunnel decides which apps go through the VPN.
enum SplitMode {
  /// Every app uses the VPN.
  all,

  /// Every app except the selected ones uses the VPN.
  exclude,

  /// Only the selected apps use the VPN.
  include;

  static SplitMode fromName(String? n) => SplitMode.values.firstWhere(
    (m) => m.name == n,
    orElse: () => SplitMode.all,
  );
}

/// A saved WireGuard tunnel plus Varnika-specific preferences.
class TunnelProfile {
  TunnelProfile({
    required this.id,
    required this.name,
    required this.config,
    this.splitMode = SplitMode.all,
    this.apps = const [],
    this.emoji = '🛡️',
    this.favorite = false,
    DateTime? createdAt,
    this.lastConnectedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;

  /// Raw wg-quick configuration text.
  final String config;
  final SplitMode splitMode;

  /// Package names used by [splitMode] (ignored when [SplitMode.all]).
  final List<String> apps;
  final String emoji;
  final bool favorite;
  final DateTime createdAt;
  final DateTime? lastConnectedAt;

  WgConfig? get parsed {
    try {
      return WgConfig.parse(config);
    } on FormatException {
      return null;
    }
  }

  String get endpointLabel => parsed?.primaryPeer?.endpoint ?? 'No endpoint';

  TunnelProfile copyWith({
    String? name,
    String? config,
    SplitMode? splitMode,
    List<String>? apps,
    String? emoji,
    bool? favorite,
    DateTime? lastConnectedAt,
  }) => TunnelProfile(
    id: id,
    name: name ?? this.name,
    config: config ?? this.config,
    splitMode: splitMode ?? this.splitMode,
    apps: apps ?? this.apps,
    emoji: emoji ?? this.emoji,
    favorite: favorite ?? this.favorite,
    createdAt: createdAt,
    lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'config': config,
    'splitMode': splitMode.name,
    'apps': apps,
    'emoji': emoji,
    'favorite': favorite,
    'createdAt': createdAt.toIso8601String(),
    'lastConnectedAt': lastConnectedAt?.toIso8601String(),
  };

  factory TunnelProfile.fromJson(Map<String, Object?> j) => TunnelProfile(
    id: j['id'] as String,
    name: j['name'] as String,
    config: j['config'] as String,
    splitMode: SplitMode.fromName(j['splitMode'] as String?),
    apps: (j['apps'] as List?)?.cast<String>() ?? const [],
    emoji: (j['emoji'] as String?) ?? '🛡️',
    favorite: (j['favorite'] as bool?) ?? false,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    lastConnectedAt: DateTime.tryParse(j['lastConnectedAt'] as String? ?? ''),
  );
}
