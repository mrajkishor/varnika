import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wg_config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Generate a key pair, or derive a public key from a private key.
class KeyToolsScreen extends StatefulWidget {
  const KeyToolsScreen({super.key});

  @override
  State<KeyToolsScreen> createState() => _KeyToolsScreenState();
}

class _KeyToolsScreenState extends State<KeyToolsScreen> {
  String? _private, _public;
  final _derive = TextEditingController();
  String? _derived;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _derive.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final kp = await AppScope.read(context).channel.generateKeyPair();
    if (mounted) {
      setState(() {
        _private = kp.privateKey;
        _public = kp.publicKey;
      });
    }
  }

  Future<void> _onDerive(String v) async {
    final key = v.trim();
    if (!WgConfig.isValidKey(key)) {
      setState(() => _derived = null);
      return;
    }
    final pub = await AppScope.read(context).channel.publicKeyFor(key);
    if (mounted) setState(() => _derived = pub);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Key generator')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        SectionCard(
          title: 'New key pair',
          trailing: InkWell(
            onTap: _generate,
            child: const Icon(Icons.refresh_rounded, size: 20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KeyBox(
                label: 'Private key (keep secret)',
                value: _private,
                secret: true,
              ),
              const SizedBox(height: 12),
              _KeyBox(
                label: 'Public key (share with the server)',
                value: _public,
              ),
              const SizedBox(height: 12),
              Text(
                'Add the public key as a [Peer] on your server, then use '
                'Tunnels → Add → Create from scratch.',
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Public key from private key',
          child: Column(
            children: [
              TextField(
                controller: _derive,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Paste a private key',
                ),
                onChanged: _onDerive,
              ),
              if (_derived != null) ...[
                const SizedBox(height: 12),
                _KeyBox(label: 'Public key', value: _derived),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _KeyBox extends StatefulWidget {
  const _KeyBox({
    required this.label,
    required this.value,
    this.secret = false,
  });
  final String label;
  final String? value;
  final bool secret;

  @override
  State<_KeyBox> createState() => _KeyBoxState();
}

class _KeyBoxState extends State<_KeyBox> {
  late bool _hidden = widget.secret;

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: context.tt.labelMedium?.copyWith(
            color: context.cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(
            color: context.cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.cs.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  v == null ? '…' : (_hidden ? '•' * 24 : v),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (widget.secret)
                IconButton(
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: v == null
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: v));
                        showSnack(context, 'Copied');
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
