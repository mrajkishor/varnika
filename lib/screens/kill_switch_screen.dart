import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Explains and checks Android's built-in kill switch
/// (Always-on VPN + Block connections without VPN).
class KillSwitchScreen extends StatefulWidget {
  const KillSwitchScreen({super.key});

  @override
  State<KillSwitchScreen> createState() => _KillSwitchScreenState();
}

class _KillSwitchScreenState extends State<KillSwitchScreen>
    with WidgetsBindingObserver {
  bool? _alwaysOn;
  bool? _lockdown;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when the user comes back from Android settings.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final s = await AppScope.read(context).channel.killSwitchStatus();
      if (mounted) {
        setState(() {
          _alwaysOn = s.alwaysOn;
          _lockdown = s.lockdown;
        });
      }
    } catch (_) {
      // Leave as unknown.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final up = app.status.isUp;
    final armed = _alwaysOn == true && _lockdown == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Kill switch')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: armed
                    ? [
                        context.vc.protected,
                        context.vc.protected.withValues(alpha: 0.75),
                      ]
                    : [VColors.ink, const Color(0xFF3B2F7A)],
              ),
            ),
            child: Row(
              children: [
                Icon(
                  armed ? Icons.gpp_good_rounded : Icons.gpp_maybe_rounded,
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        armed ? 'Kill switch is on' : 'Never leak traffic',
                        style: context.tt.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        armed
                            ? 'If the tunnel drops, Android blocks all internet until it\'s back.'
                            : 'Android has a system-level kill switch. Turn it on for Varnika to block '
                                  'internet whenever the VPN isn\'t connected.',
                        style: context.tt.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Status',
            trailing: _checking
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : InkWell(
                    onTap: _check,
                    child: const Icon(Icons.refresh_rounded, size: 20),
                  ),
            child: Column(
              children: [
                _StatusRow('Always-on VPN', _alwaysOn),
                _StatusRow('Block connections without VPN', _lockdown),
                if (!up && _alwaysOn == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Android only reports this while Varnika is connected. Connect, then refresh.',
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Turn it on',
            child: Column(
              children: const [
                _Step(
                  1,
                  'Connect a tunnel in Varnika at least once, so Android knows which one to start.',
                ),
                _Step(2, 'Tap "Open VPN settings" below.'),
                _Step(3, 'Tap the ⚙ gear next to Varnika.'),
                _Step(4, 'Turn on "Always-on VPN".'),
                _Step(
                  5,
                  'Turn on "Block connections without VPN". This is the kill switch.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: app.channel.openVpnSettings,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open VPN settings'),
          ),
          const SizedBox(height: 12),
          Text(
            'Varnika also reconnects your last tunnel automatically when Android starts it '
            'at boot or after an always-on restart. Split tunneling still applies: bypassed apps '
            'keep using your normal connection.',
            style: context.tt.bodySmall?.copyWith(
              color: context.cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(this.label, this.value);
  final String label;
  final bool? value;

  @override
  Widget build(BuildContext context) {
    final (text, color, icon) = switch (value) {
      true => ('On', context.vc.protected, Icons.check_circle_rounded),
      false => ('Off', context.vc.unprotected, Icons.cancel_rounded),
      null => (
        'Unknown',
        context.cs.onSurfaceVariant,
        Icons.help_outline_rounded,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.tt.bodyLarge)),
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(text, style: context.tt.labelLarge?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.text);
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: VColors.marigold.withValues(alpha: 0.18),
          child: Text(
            '$n',
            style: context.tt.labelMedium?.copyWith(
              color: VColors.marigold,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text),
          ),
        ),
      ],
    ),
  );
}
