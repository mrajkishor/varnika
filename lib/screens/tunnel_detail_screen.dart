import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/tunnel_profile.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import 'config_editor_screen.dart';
import 'split_tunnel_screen.dart';

class TunnelDetailScreen extends StatelessWidget {
  const TunnelDetailScreen({super.key, required this.tunnelId});
  final String tunnelId;

  static const _emojis = [
    '🛡️',
    '🌏',
    '🏠',
    '💼',
    '🚀',
    '🪔',
    '🌙',
    '⚡',
    '🏔️',
    '🌊',
    '🎮',
    '📺',
    '🇮🇳',
    '🇺🇸',
    '🇩🇪',
    '🇸🇬',
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.tunnelById(tunnelId);
    if (t == null) {
      return const Scaffold(body: Center(child: Text('Tunnel removed')));
    }
    final p = t.parsed;
    final peer = p?.primaryPeer;
    final active = app.status.tunnelId == t.id && app.status.isUp;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: t.favorite ? 'Unfavorite' : 'Favorite',
            icon: Icon(
              t.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: t.favorite ? VColors.marigold : null,
            ),
            onPressed: () => app.updateTunnel(
              t.copyWith(favorite: !t.favorite),
              reconnectIfActive: false,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'rename' => _rename(context, app, t),
              'edit' => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConfigEditorScreen(existing: t),
                ),
              ),
              'delete' => _delete(context, app, t),
              _ => null,
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'edit', child: Text('Edit config')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _pickEmoji(context, app, t),
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(t.emoji, style: const TextStyle(fontSize: 34)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active ? 'Connected' : 'Not connected',
                      style: context.tt.titleMedium?.copyWith(
                        color: active
                            ? context.vc.protected
                            : context.cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      t.lastConnectedAt == null
                          ? 'Never used'
                          : 'Last used ${formatAgo(t.lastConnectedAt!)}',
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(110, 48),
                  backgroundColor: active
                      ? context.cs.surfaceContainerHighest
                      : context.vc.protected,
                  foregroundColor: active ? context.cs.onSurface : Colors.white,
                ),
                onPressed: () => active ? app.disconnect() : app.connect(t),
                child: Text(active ? 'Disconnect' : 'Connect'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Server',
            child: p == null
                ? const Text('This config could not be read. Edit it to fix.')
                : Column(
                    children: [
                      _KV('Endpoint', peer?.endpoint ?? '—', copy: true),
                      _KV(
                        'Server key',
                        peer?.publicKey ?? '—',
                        copy: true,
                        mono: true,
                      ),
                      _KV('Address', p.addresses.join(', ')),
                      _KV(
                        'DNS',
                        p.dns.isEmpty ? 'System default' : p.dns.join(', '),
                      ),
                      _KV('Allowed IPs', peer?.allowedIps.join(', ') ?? '—'),
                      if (p.mtu != null) _KV('MTU', '${p.mtu}'),
                      if (peer?.persistentKeepalive != null)
                        _KV('Keepalive', '${peer!.persistentKeepalive}s'),
                      if (p.peers.length > 1) _KV('Peers', '${p.peers.length}'),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.call_split_rounded),
                  title: const Text('Split tunneling'),
                  subtitle: Text(switch (t.splitMode) {
                    SplitMode.all => 'All apps use the VPN',
                    SplitMode.exclude => '${t.apps.length} apps bypass the VPN',
                    SplitMode.include =>
                      'Only ${t.apps.length} apps use the VPN',
                  }),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SplitTunnelScreen(tunnelId: t.id),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_2_rounded),
                  title: const Text('Show as QR code'),
                  subtitle: const Text('Move this tunnel to another device'),
                  onTap: () => _showQr(context, t),
                ),
                ListTile(
                  leading: const Icon(Icons.save_alt_rounded),
                  title: const Text('Export .conf file'),
                  onTap: () async {
                    final ok = await app.channel.saveFile(
                      _fileName(t),
                      t.config,
                    );
                    if (context.mounted && ok) showSnack(context, 'Exported');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy config'),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: t.config));
                    if (context.mounted) {
                      showSnack(
                        context,
                        'Config copied. It contains your private key!',
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fileName(TunnelProfile t) {
    final slug = t.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return '${slug.isEmpty ? 'tunnel' : slug}.conf';
  }

  Future<void> _rename(
    BuildContext context,
    AppState app,
    TunnelProfile t,
  ) async {
    final c = TextEditingController(text: t.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename tunnel'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await app.updateTunnel(t.copyWith(name: name), reconnectIfActive: false);
    }
  }

  Future<void> _delete(
    BuildContext context,
    AppState app,
    TunnelProfile t,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${t.name}"?'),
        content: const Text(
          'The config and its private key will be removed from this phone. '
          'Export it first if you might need it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: VColors.rose,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await app.deleteTunnel(t);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  void _pickEmoji(BuildContext context, AppState app, TunnelProfile t) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _emojis)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(ctx);
                    app.updateTunnel(
                      t.copyWith(emoji: e),
                      reconnectIfActive: false,
                    );
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e == t.emoji
                          ? VColors.marigold.withValues(alpha: 0.2)
                          : ctx.cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQr(BuildContext context, TunnelProfile t) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox.square(
                dimension: 240,
                child: QrImageView(
                  data: t.config,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This QR contains your private key. Only scan it on devices you trust.',
              textAlign: TextAlign.center,
              style: ctx.tt.bodySmall?.copyWith(color: ctx.cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v, {this.copy = false, this.mono = false});
  final String k, v;
  final bool copy, mono;

  @override
  Widget build(BuildContext context) => InkWell(
    onLongPress: copy
        ? () {
            Clipboard.setData(ClipboardData(text: v));
            showSnack(context, '$k copied');
          }
        : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              k,
              style: context.tt.bodyMedium?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: context.tt.bodyMedium?.copyWith(
                fontFamily: mono ? 'monospace' : null,
                fontSize: mono ? 12.5 : null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
