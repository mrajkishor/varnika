import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.checkIpOnConnect = true,
    this.lastTunnelId,
    this.onboarded = false,
  });

  final ThemeMode themeMode;
  final bool checkIpOnConnect;
  final String? lastTunnelId;
  final bool onboarded;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? checkIpOnConnect,
    String? lastTunnelId,
    bool? onboarded,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    checkIpOnConnect: checkIpOnConnect ?? this.checkIpOnConnect,
    lastTunnelId: lastTunnelId ?? this.lastTunnelId,
    onboarded: onboarded ?? this.onboarded,
  );
}

class SettingsStore {
  static const _theme = 'theme',
      _ip = 'checkIp',
      _last = 'lastTunnel',
      _onb = 'onboarded';

  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == p.getString(_theme),
        orElse: () => ThemeMode.system,
      ),
      checkIpOnConnect: p.getBool(_ip) ?? true,
      lastTunnelId: p.getString(_last),
      onboarded: p.getBool(_onb) ?? false,
    );
  }

  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_theme, s.themeMode.name);
    await p.setBool(_ip, s.checkIpOnConnect);
    await p.setBool(_onb, s.onboarded);
    if (s.lastTunnelId != null) await p.setString(_last, s.lastTunnelId!);
  }
}
