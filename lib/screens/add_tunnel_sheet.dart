import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wg_config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'config_editor_screen.dart';
import 'qr_scan_screen.dart';

/// Bottom sheet listing every way to add a tunnel.
Future<void> showAddTunnelSheet(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (ctx) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text('Add a tunnel', style: ctx.tt.titleLarge),
          ),
          _Option(
            icon: Icons.file_open_rounded,
            title: 'Import .conf file',
            subtitle: 'Pick a WireGuard config from your phone',
            onTap: () {
              Navigator.pop(ctx);
              _importFile(context);
            },
          ),
          _Option(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan QR code',
            subtitle: 'From your server\'s terminal or another device',
            onTap: () {
              Navigator.pop(ctx);
              _scanQr(context);
            },
          ),
          _Option(
            icon: Icons.content_paste_rounded,
            title: 'Paste config',
            subtitle: 'Paste the text of a config from the clipboard',
            onTap: () async {
              Navigator.pop(ctx);
              final clip = await Clipboard.getData(Clipboard.kTextPlain);
              if (!context.mounted) return;
              _openEditor(context, config: clip?.text ?? '');
            },
          ),
          _Option(
            icon: Icons.auto_awesome_rounded,
            title: 'Create from scratch',
            subtitle: 'Generate fresh keys and fill in your server details',
            onTap: () async {
              Navigator.pop(ctx);
              final app = AppScope.read(context);
              final kp = await app.channel.generateKeyPair();
              if (!context.mounted) return;
              _openEditor(
                context,
                name: 'New tunnel',
                config:
                    '[Interface]\n'
                    'PrivateKey = ${kp.privateKey}\n'
                    '# Your public key (add it to the server): ${kp.publicKey}\n'
                    'Address = 10.0.0.2/32\n'
                    'DNS = 1.1.1.1, 1.0.0.1\n'
                    '\n'
                    '[Peer]\n'
                    'PublicKey = <server public key>\n'
                    'Endpoint = vpn.example.com:51820\n'
                    'AllowedIPs = 0.0.0.0/0, ::/0\n'
                    'PersistentKeepalive = 25\n',
              );
            },
          ),
        ],
      ),
    ),
  ),
);

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VColors.marigold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: VColors.marigold),
    ),
    title: Text(title, style: context.tt.titleSmall),
    subtitle: Text(subtitle),
    onTap: onTap,
  );
}

Future<void> _importFile(BuildContext context) async {
  final app = AppScope.read(context);
  try {
    final file = await app.channel.pickConfigFile();
    if (file == null || !context.mounted) return;
    final name = WgConfig.suggestName(file.name);
    final err = await app.addTunnel(name: name, config: file.text);
    if (!context.mounted) return;
    if (err == null) {
      showSnack(context, 'Added "$name"');
    } else {
      // Let the user fix it instead of just failing.
      _openEditor(context, name: name, config: file.text, initialError: err);
    }
  } on PlatformException catch (e) {
    if (context.mounted) {
      showSnack(context, e.message ?? 'Couldn\'t read that file');
    }
  }
}

Future<void> _scanQr(BuildContext context) async {
  final text = await Navigator.of(context)
      .push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
  if (text == null || !context.mounted) return;
  _openEditor(context, name: 'Scanned tunnel', config: text);
}

void _openEditor(
  BuildContext context, {
  String name = '',
  required String config,
  String? initialError,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ConfigEditorScreen(
        initialName: name.isEmpty ? 'My tunnel' : name,
        initialConfig: config,
        initialError: initialError,
      ),
    ),
  );
}
