import 'dart:convert';

import 'package:http/http.dart' as http;

/// What the internet currently sees as this device's address.
class IpInfo {
  const IpInfo({required this.ip, this.city, this.country, this.org});

  final String ip;
  final String? city;
  final String? country;
  final String? org;

  String get place =>
      [city, country].where((s) => s != null && s.isNotEmpty).join(', ');

  /// Converts an ISO country code like "IN" to a flag emoji 🇮🇳.
  String get flag {
    final c = country;
    if (c == null || c.length != 2) return '🌐';
    final upper = c.toUpperCase();
    return String.fromCharCodes(upper.codeUnits.map((u) => 0x1F1E6 + u - 65));
  }
}

class IpLookup {
  IpLookup({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<IpInfo> lookup() async {
    final res = await _client
        .get(
          Uri.parse('https://ipinfo.io/json'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('IP lookup failed (${res.statusCode})');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return IpInfo(
      ip: j['ip'] as String? ?? '?',
      city: j['city'] as String?,
      country: j['country'] as String?,
      org: j['org'] as String?,
    );
  }
}
