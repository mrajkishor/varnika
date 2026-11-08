import 'package:flutter/material.dart';

import '../models/tunnel_profile.dart';
import '../models/vpn_status.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'add_tunnel_sheet.dart';
import 'tunnel_detail_screen.dart';

class TunnelsScreen extends StatelessWidget {
  const TunnelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tunnels = app.sortedTunnels;

    return Scaffold(
      appBar: AppBar(title: const Text('Tunnels')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddTunnelSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
        backgroundColor: VColors.marigold,
        foregroundColor: Colors.white,
      ),
      body: tunnels.isEmpty
          ? EmptyState(
              icon: Icons.dns_rounded,
              title: 'No tunnels yet',
              message: 'Tunnels are WireGuard configs from your own server or VPN provider.',
              action: OutlinedButton.icon(
                onPressed: () => showAddTunnelSheet(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add tunnel'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              itemCount: tunnels.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _TunnelTile(tunnel: tunnels[i]),
            ),
    );
  }
}

class _TunnelTile extends StatelessWidget {
  const _TunnelTile({required this.tunnel});
  final TunnelProfile tunnel;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isActive = app.status.tunnelId == tunnel.id;
    final up = isActive && app.status.isUp;
    final busy = isActive && app.status.isBusy;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: up
              ? context.vc.protected
              : context.cs.outlineVariant.withValues(alpha: 0.6),
          width: up ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TunnelDetailScreen(tunnelId: tunnel.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Text(tunnel.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tunnel.name,
                            style: context.tt.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tunnel.favorite) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: VColors.marigold,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tunnel.endpointLabel,
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tunnel.splitMode != SplitMode.all) ...[
                      const SizedBox(height: 6),
                      _Chip(
                        tunnel.splitMode == SplitMode.exclude
                            ? '${tunnel.apps.length} apps bypass'
                            : 'Only ${tunnel.apps.length} apps',
                      ),
                    ],
                  ],
                ),
              ),
              busy
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : Switch(
                      value: up,
                      activeTrackColor: context.vc.protected,
                      onChanged: (on) =>
                          on ? app.connect(tunnel) : app.disconnect(),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: context.cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.call_split_rounded,
          size: 13,
          color: context.cs.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(text, style: context.tt.labelSmall),
      ],
    ),
  );
}

/// Used by other screens to show status without importing the tile.
bool isTunnelUp(AppState app, TunnelProfile t) =>
    app.status.tunnelId == t.id && app.status.state == VpnState.up;
