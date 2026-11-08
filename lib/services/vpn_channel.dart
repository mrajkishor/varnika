import 'dart:async';

import 'package:flutter/services.dart';

import '../models/tunnel_profile.dart';
import '../models/vpn_status.dart';

/// Thin typed wrapper around the Kotlin WireGuard bridge
/// (see `android/app/src/main/kotlin/.../VpnBridge.kt`).
class VpnChannel {
  VpnChannel._();
  static final VpnChannel instance = VpnChannel._();

  static const _method = MethodChannel('varnika/vpn');
  static const _events = EventChannel('varnika/vpn/status');

  Stream<VpnStatus>? _statusStream;

  /// Broadcast stream of tunnel state changes pushed from Android.
  Stream<VpnStatus> get statusStream => _statusStream ??= _events
      .receiveBroadcastStream()
      .map((e) => VpnStatus.fromMap(e as Map<Object?, Object?>))
      .asBroadcastStream();

  Future<VpnStatus> getStatus() async {
    final m = await _method.invokeMapMethod<Object?, Object?>('getStatus');
    return VpnStatus.fromMap(m ?? const {});
  }

  /// Shows the system "connection request" dialog if needed.
  /// Returns true when Varnika is allowed to create a VPN.
  Future<bool> prepare() async =>
      await _method.invokeMethod<bool>('prepare') ?? false;

  Future<void> connect(TunnelProfile p) => _method.invokeMethod('connect', {
    'id': p.id,
    'name': p.name,
    'config': p.config,
    'splitMode': p.splitMode.name,
    'apps': p.apps,
  });

  Future<void> disconnect() => _method.invokeMethod('disconnect');

  Future<TrafficStats> getStats() async {
    final m = await _method.invokeMapMethod<Object?, Object?>('getStats');
    return m == null ? TrafficStats.zero : TrafficStats.fromMap(m);
  }

  /// Validates a config with the official WireGuard parser.
  /// Returns null when valid, otherwise an error message.
  Future<String?> validateConfig(String config) =>
      _method.invokeMethod<String>('validateConfig', {'config': config});

  Future<List<InstalledApp>> listApps({bool includeSystem = false}) async {
    final list =
        await _method.invokeListMethod<Object?>('listApps', {
          'includeSystem': includeSystem,
        }) ??
        const [];
    return list.map((e) {
      final m = e as Map<Object?, Object?>;
      return InstalledApp(
        packageName: m['package'] as String,
        label: m['label'] as String,
        icon: (m['icon'] as Uint8List?),
        isSystem: (m['system'] as bool?) ?? false,
      );
    }).toList();
  }

  /// Opens the Android document picker for a `.conf` file.
  Future<({String name, String text})?> pickConfigFile() async {
    final m = await _method.invokeMapMethod<Object?, Object?>('pickConfigFile');
    if (m == null) return null;
    return (
      name: m['name'] as String? ?? 'tunnel.conf',
      text: m['text'] as String,
    );
  }

  /// Saves text through the system "Save as" dialog. Returns true on success.
  Future<bool> saveFile(String fileName, String text) async =>
      await _method.invokeMethod<bool>('saveFile', {
        'name': fileName,
        'text': text,
      }) ??
      false;

  Future<({String privateKey, String publicKey})> generateKeyPair() async {
    final m = await _method.invokeMapMethod<String, String>('generateKeyPair');
    return (privateKey: m!['private']!, publicKey: m['public']!);
  }

  Future<String?> publicKeyFor(String privateKey) =>
      _method.invokeMethod<String>('publicKeyFor', {'privateKey': privateKey});

  /// Always-on / lockdown status. Values are null when unknown
  /// (Android only reports them while the VPN service is running).
  Future<({bool? alwaysOn, bool? lockdown})> killSwitchStatus() async {
    final m = await _method.invokeMapMethod<String, Object?>(
      'killSwitchStatus',
    );
    return (
      alwaysOn: m?['alwaysOn'] as bool?,
      lockdown: m?['lockdown'] as bool?,
    );
  }

  Future<void> openVpnSettings() => _method.invokeMethod('openVpnSettings');

  Future<bool> requestNotificationPermission() async =>
      await _method.invokeMethod<bool>('requestNotificationPermission') ?? true;

  Future<List<SessionRecord>> getHistory() async {
    final list =
        await _method.invokeListMethod<Object?>('getHistory') ?? const [];
    return list
        .map((e) => SessionRecord.fromMap(e as Map<Object?, Object?>))
        .toList();
  }

  Future<void> clearHistory() => _method.invokeMethod('clearHistory');

  Future<String> backendVersion() async =>
      await _method.invokeMethod<String>('backendVersion') ?? 'unknown';
}
