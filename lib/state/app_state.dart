import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tunnel_profile.dart';
import '../models/vpn_status.dart';
import '../services/ip_lookup.dart';
import '../services/settings_store.dart';
import '../services/tunnel_store.dart';
import '../services/vpn_channel.dart';

/// One throughput sample (bytes per second) for the live sparkline.
class RateSample {
  const RateSample(this.rx, this.tx);
  final double rx;
  final double tx;
}

class AppState extends ChangeNotifier {
  AppState({
    VpnChannel? channel,
    TunnelStore? tunnelStore,
    SettingsStore? settingsStore,
    IpLookup? ipLookup,
  }) : _vpn = channel ?? VpnChannel.instance,
       _tunnelStore = tunnelStore ?? TunnelStore(),
       _settingsStore = settingsStore ?? SettingsStore(),
       _ip = ipLookup ?? IpLookup();

  final VpnChannel _vpn;
  final TunnelStore _tunnelStore;
  final SettingsStore _settingsStore;
  final IpLookup _ip;

  bool loaded = false;
  List<TunnelProfile> tunnels = [];
  AppSettings settings = const AppSettings();
  VpnStatus status = const VpnStatus();
  TrafficStats stats = TrafficStats.zero;
  List<SessionRecord> history = [];

  static const sampleCount = 60;
  final List<RateSample> samples = [];
  double rxRate = 0, txRate = 0;

  IpInfo? ipInfo;
  bool ipLoading = false;
  String? ipError;

  /// Transient error to surface as a SnackBar.
  final ValueNotifier<String?> errors = ValueNotifier(null);

  StreamSubscription<VpnStatus>? _sub;
  Timer? _poller;
  bool _askedNotifications = false;

  VpnChannel get channel => _vpn;

  TunnelProfile? tunnelById(String? id) {
    if (id == null) return null;
    for (final t in tunnels) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The tunnel the big connect button acts on.
  TunnelProfile? get selectedTunnel =>
      tunnelById(status.isUp || status.isBusy ? status.tunnelId : null) ??
      tunnelById(settings.lastTunnelId) ??
      (tunnels.isEmpty ? null : tunnels.first);

  List<TunnelProfile> get sortedTunnels {
    final list = [...tunnels];
    list.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      final la = a.lastConnectedAt ?? a.createdAt;
      final lb = b.lastConnectedAt ?? b.createdAt;
      return lb.compareTo(la);
    });
    return list;
  }

  Future<void> init() async {
    settings = await _settingsStore.load();
    tunnels = await _tunnelStore.load();
    try {
      status = await _vpn.getStatus();
      history = await _vpn.getHistory();
    } on MissingPluginException {
      // Running in a test or on a platform without the native bridge.
    }
    loaded = true;
    notifyListeners();

    try {
      _sub = _vpn.statusStream.listen(_onStatus, onError: (_) {});
    } on MissingPluginException {
      // ignore
    }
    if (status.isUp) _startPolling();
    if (settings.checkIpOnConnect) unawaited(refreshIp());
  }

  void _onStatus(VpnStatus s) {
    final wasUp = status.isUp;
    status = s;
    if (s.state == VpnState.error && s.error != null) {
      errors.value = s.error;
    }
    if (s.isUp && !wasUp) {
      _startPolling();
      if (settings.checkIpOnConnect) {
        // Give the tunnel a moment to complete its first handshake.
        Future.delayed(const Duration(seconds: 2), refreshIp);
      }
    } else if (!s.isUp && wasUp) {
      _stopPolling();
      _refreshHistory();
      if (settings.checkIpOnConnect) {
        Future.delayed(const Duration(milliseconds: 800), refreshIp);
      }
    }
    notifyListeners();
  }

  void _startPolling() {
    _poller?.cancel();
    samples.clear();
    stats = TrafficStats.zero;
    _poller = Timer.periodic(const Duration(seconds: 1), (_) => _pollStats());
    _pollStats();
  }

  void _stopPolling() {
    _poller?.cancel();
    _poller = null;
    rxRate = txRate = 0;
  }

  Future<void> _pollStats() async {
    try {
      final next = await _vpn.getStats();
      final prev = stats;
      if (prev.at != null && next.at != null) {
        final secs = max(
          0.2,
          next.at!.difference(prev.at!).inMilliseconds / 1000,
        );
        rxRate = max(0, (next.rxBytes - prev.rxBytes) / secs);
        txRate = max(0, (next.txBytes - prev.txBytes) / secs);
        samples.add(RateSample(rxRate, txRate));
        if (samples.length > sampleCount) samples.removeAt(0);
      }
      stats = next;
      notifyListeners();
    } catch (_) {
      // Stats are best-effort.
    }
  }

  Future<void> _refreshHistory() async {
    try {
      history = await _vpn.getHistory();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshIp() async {
    if (ipLoading) return;
    ipLoading = true;
    ipError = null;
    notifyListeners();
    try {
      ipInfo = await _ip.lookup();
    } catch (e) {
      ipError = 'Could not reach the IP check service';
    } finally {
      ipLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- actions

  Future<void> toggle() async {
    if (status.isUp || status.state == VpnState.connecting) {
      await disconnect();
    } else {
      final t = selectedTunnel;
      if (t == null) {
        errors.value = 'Add a tunnel first';
        return;
      }
      await connect(t);
    }
  }

  Future<void> connect(TunnelProfile t) async {
    try {
      if (!_askedNotifications) {
        _askedNotifications = true;
        await _vpn.requestNotificationPermission();
      }
      final allowed = await _vpn.prepare();
      if (!allowed) {
        errors.value = 'VPN permission was not granted';
        return;
      }
      status = VpnStatus(
        state: VpnState.connecting,
        tunnelId: t.id,
        tunnelName: t.name,
      );
      notifyListeners();
      await _vpn.connect(t);
      settings = settings.copyWith(lastTunnelId: t.id);
      await _settingsStore.save(settings);
      await upsertTunnel(t.copyWith(lastConnectedAt: DateTime.now()));
    } on PlatformException catch (e) {
      errors.value = e.message ?? 'Could not connect';
      try {
        status = await _vpn.getStatus();
      } catch (_) {
        status = const VpnStatus();
      }
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await _vpn.disconnect();
    } on PlatformException catch (e) {
      errors.value = e.message ?? 'Could not disconnect';
    }
  }

  Future<void> selectTunnel(TunnelProfile t) async {
    settings = settings.copyWith(lastTunnelId: t.id);
    notifyListeners();
    await _settingsStore.save(settings);
  }

  Future<void> upsertTunnel(TunnelProfile t) async {
    final i = tunnels.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      tunnels[i] = t;
    } else {
      tunnels.add(t);
    }
    notifyListeners();
    await _tunnelStore.save(tunnels);
  }

  /// Saves edits; if that tunnel is currently connected, reconnects so the
  /// change (e.g. split tunneling) takes effect immediately.
  Future<void> updateTunnel(
    TunnelProfile t, {
    bool reconnectIfActive = true,
  }) async {
    await upsertTunnel(t);
    if (reconnectIfActive && status.isUp && status.tunnelId == t.id) {
      await connect(t);
    }
  }

  Future<void> deleteTunnel(TunnelProfile t) async {
    if (status.tunnelId == t.id && (status.isUp || status.isBusy)) {
      await disconnect();
    }
    tunnels.removeWhere((x) => x.id == t.id);
    notifyListeners();
    await _tunnelStore.save(tunnels);
  }

  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${Random().nextInt(1 << 20).toRadixString(36)}';

  /// Validates and stores a new tunnel. Returns an error message or null.
  Future<String?> addTunnel({
    required String name,
    required String config,
  }) async {
    String? error;
    try {
      error = await _vpn.validateConfig(config);
    } on MissingPluginException {
      error = null;
    }
    if (error != null) return error;
    final t = TunnelProfile(
      id: newId(),
      name: name.trim(),
      config: config.trim(),
    );
    await upsertTunnel(t);
    if (tunnels.length == 1) await selectTunnel(t);
    return null;
  }

  Future<void> setThemeMode(ThemeMode m) async {
    settings = settings.copyWith(themeMode: m);
    notifyListeners();
    await _settingsStore.save(settings);
  }

  Future<void> setCheckIp(bool v) async {
    settings = settings.copyWith(checkIpOnConnect: v);
    notifyListeners();
    await _settingsStore.save(settings);
  }

  Future<void> completeOnboarding() async {
    settings = settings.copyWith(onboarded: true);
    notifyListeners();
    await _settingsStore.save(settings);
  }

  Future<void> clearHistory() async {
    await _vpn.clearHistory();
    history = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poller?.cancel();
    errors.dispose();
    super.dispose();
  }
}

/// Makes [AppState] available to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Access without subscribing to rebuilds (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
