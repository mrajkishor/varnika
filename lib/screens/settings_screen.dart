import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'key_tools_screen.dart';
import 'kill_switch_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _backend;

  @override
  void initState() {
    super.initState();
    AppScope.read(context).channel
        .backendVersion()
        .then((v) {
          if (mounted) setState(() => _backend = v);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          SectionCard(
            title: 'Appearance',
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_rounded),
                  ),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => app.setThemeMode(v.first),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Protection',
            padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Kill switch & always-on'),
                  subtitle: const Text('Block internet if the VPN drops'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const KillSwitchScreen()),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.travel_explore_rounded),
                  title: const Text('Check my IP on connect'),
                  subtitle: const Text(
                    'Shows the address websites see (via ipinfo.io)',
                  ),
                  value: s.checkIpOnConnect,
                  onChanged: app.setCheckIp,
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Status notification'),
                  subtitle: const Text('Live traffic and a Disconnect button'),
                  onTap: () async {
                    final ok = await app.channel
                        .requestNotificationPermission();
                    if (context.mounted) {
                      showSnack(
                        context,
                        ok
                            ? 'Notifications are on'
                            : 'Enable notifications in Android settings',
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Tools',
            padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.key_rounded),
                  title: const Text('Key generator'),
                  subtitle: const Text(
                    'Create a WireGuard key pair for a new server peer',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const KeyToolsScreen()),
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.dashboard_customize_outlined),
                  title: Text('Quick Settings tile'),
                  subtitle: Text(
                    'Swipe down, tap ✎ edit, and drag "Varnika VPN" into your tiles '
                    'for one-tap connect',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'About',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wordmark(size: 20),
                const SizedBox(height: 8),
                Text(
                  'A private WireGuard client. Your configs and keys stay encrypted on this phone. '
                  'Varnika has no accounts, no servers of its own and no tracking.',
                  style: context.tt.bodyMedium?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'WireGuard backend: ${_backend ?? '…'}',
                  style: context.tt.bodySmall,
                ),
                Text(
                  'WireGuard is a registered trademark of Jason A. Donenfeld.',
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
