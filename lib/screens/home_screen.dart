import 'package:flutter/material.dart';

import '../models/tunnel_profile.dart';
import '../models/vpn_status.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/connect_orb.dart';
import '../widgets/sparkline.dart';
import 'add_tunnel_sheet.dart';
import 'kill_switch_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final status = app.status;
    final tunnel = app.selectedTunnel;

    return Scaffold(
      appBar: AppBar(
        title: const Wordmark(),
        actions: [
          IconButton(
            tooltip: 'Kill switch',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const KillSwitchScreen())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !app.loaded
          ? const Center(child: CircularProgressIndicator())
          : tunnel == null
          ? EmptyState(
              icon: Icons.vpn_key_rounded,
              title: 'Add your first tunnel',
              message:
                  'Import a WireGuard .conf file, scan a QR code from your server, '
                  'or paste a config to get started.',
              action: FilledButton.icon(
                onPressed: () => showAddTunnelSheet(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add tunnel'),
              ),
            )
          : RefreshIndicator(
              onRefresh: app.refreshIp,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  _Headline(status: status),
                  const SizedBox(height: 4),
                  Center(
                    child: ConnectOrb(state: status.state, onTap: app.toggle),
                  ),
                  _TunnelPicker(
                    tunnel: tunnel,
                    locked: status.isUp || status.isBusy,
                  ),
                  const SizedBox(height: 20),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: status.isUp
                        ? const Column(
                            children: [
                              _LiveStats(),
                              SizedBox(height: 14),
                              _ThroughputCard(),
                              SizedBox(height: 14),
                            ],
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const _IpCard(),
                ],
              ),
            ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.status});
  final VpnStatus status;

  @override
  Widget build(BuildContext context) {
    final (title, sub, color) = switch (status.state) {
      VpnState.up => (
        'You\'re protected',
        'Traffic is encrypted with WireGuard',
        context.vc.protected,
      ),
      VpnState.connecting => (
        'Connecting…',
        'Setting up a secure tunnel',
        context.vc.unprotected,
      ),
      VpnState.disconnecting => (
        'Disconnecting…',
        'Closing the tunnel',
        context.vc.unprotected,
      ),
      _ => (
        'You\'re not protected',
        'Tap the button to connect',
        context.vc.unprotected,
      ),
    };
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Dot(color: color, size: 10),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: context.tt.headlineSmall,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: context.tt.bodyMedium?.copyWith(
            color: context.cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TunnelPicker extends StatelessWidget {
  const _TunnelPicker({required this.tunnel, required this.locked});
  final TunnelProfile tunnel;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Material(
      color: context.cs.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: context.cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _pick(context, app),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Text(tunnel.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tunnel.name,
                      style: context.tt.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        tunnel.endpointLabel,
                        if (tunnel.splitMode != SplitMode.all) 'Split tunnel',
                      ].join(' · '),
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.unfold_more_rounded,
                color: context.cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pick(BuildContext context, AppState app) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Choose a tunnel', style: ctx.tt.titleLarge),
              ),
              for (final t in app.sortedTunnels)
                ListTile(
                  leading: Text(t.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(t.name),
                  subtitle: Text(
                    t.endpointLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: t.id == tunnel.id
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: ctx.vc.protected,
                        )
                      : (t.favorite
                            ? const Icon(
                                Icons.star_rounded,
                                color: VColors.marigold,
                              )
                            : null),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (locked && t.id != tunnel.id) {
                      app.connect(t); // switch servers live
                    } else {
                      app.selectTunnel(t);
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('Add another tunnel'),
                onTap: () {
                  Navigator.pop(ctx);
                  showAddTunnelSheet(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveStats extends StatelessWidget {
  const _LiveStats();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final since = app.status.since;
    final elapsed = since == null
        ? Duration.zero
        : DateTime.now().difference(since);
    final hs = app.stats.lastHandshake;
    final hsAge = hs == null ? null : DateTime.now().difference(hs);
    // WireGuard re-handshakes every ~2 minutes; older than ~3 min means trouble.
    final (hsLabel, hsColor) = hsAge == null
        ? ('Waiting', context.vc.unprotected)
        : hsAge.inSeconds < 150
        ? ('Healthy', context.vc.protected)
        : hsAge.inSeconds < 300
        ? ('Stale', VColors.marigold)
        : ('No reply', VColors.rose);

    return SectionCard(
      title: 'Session',
      trailing: Text(
        formatClock(elapsed),
        style: context.tt.titleMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      child: Row(
        children: [
          _Stat(
            icon: Icons.south_rounded,
            color: context.vc.download,
            label: 'Download',
            value: formatBytes(app.stats.rxBytes),
            sub: formatRate(app.rxRate),
          ),
          _Stat(
            icon: Icons.north_rounded,
            color: context.vc.upload,
            label: 'Upload',
            value: formatBytes(app.stats.txBytes),
            sub: formatRate(app.txRate),
          ),
          _Stat(
            icon: Icons.handshake_outlined,
            color: hsColor,
            label: 'Handshake',
            value: hsLabel,
            sub: hs == null ? '—' : formatAgo(hs),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
  });

  final IconData icon;
  final Color color;
  final String label, value, sub;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: context.tt.labelMedium?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: context.tt.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          sub,
          style: context.tt.bodySmall?.copyWith(
            color: context.cs.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _ThroughputCard extends StatelessWidget {
  const _ThroughputCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SectionCard(
      title: 'Last minute',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Dot(color: context.vc.download),
          const SizedBox(width: 4),
          Text('Down', style: context.tt.labelSmall),
          const SizedBox(width: 10),
          Dot(color: context.vc.upload),
          const SizedBox(width: 4),
          Text('Up', style: context.tt.labelSmall),
        ],
      ),
      child: Sparkline(
        a: app.samples.map((s) => s.rx).toList(),
        b: app.samples.map((s) => s.tx).toList(),
        colorA: context.vc.download,
        colorB: context.vc.upload,
        capacity: AppState.sampleCount,
      ),
    );
  }
}

class _IpCard extends StatelessWidget {
  const _IpCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final info = app.ipInfo;
    return SectionCard(
      title: app.status.isUp ? 'The internet now sees' : 'Your visible address',
      trailing: app.ipLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : InkWell(
              customBorder: const CircleBorder(),
              onTap: app.refreshIp,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.refresh_rounded, size: 20),
              ),
            ),
      child: info == null
          ? Text(
              app.ipError ??
                  (app.ipLoading
                      ? 'Checking…'
                      : 'Tap refresh to check your public IP'),
              style: context.tt.bodyMedium?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
            )
          : Row(
              children: [
                Text(info.flag, style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(info.ip, style: context.tt.titleMedium),
                      if (info.place.isNotEmpty)
                        Text(info.place, style: context.tt.bodyMedium),
                      if (info.org != null)
                        Text(
                          info.org!,
                          style: context.tt.bodySmall?.copyWith(
                            color: context.cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
