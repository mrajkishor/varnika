import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/tunnel_profile.dart';

/// Persists tunnel profiles (which contain private keys) in the Android
/// Keystore-backed secure storage.
class TunnelStore {
  TunnelStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'varnika.tunnels.v1';

  Future<List<TunnelProfile>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map(
            (e) => TunnelProfile.fromJson((e as Map).cast<String, Object?>()),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<TunnelProfile> tunnels) => _storage.write(
    key: _key,
    value: jsonEncode(tunnels.map((t) => t.toJson()).toList()),
  );
}
