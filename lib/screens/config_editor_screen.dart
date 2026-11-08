import 'package:flutter/material.dart';

import '../models/tunnel_profile.dart';
import '../models/wg_config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Create a tunnel from text, or edit an existing tunnel's config.
class ConfigEditorScreen extends StatefulWidget {
  const ConfigEditorScreen({
    super.key,
    this.existing,
    this.initialName = 'My tunnel',
    this.initialConfig = '',
    this.initialError,
  });

  final TunnelProfile? existing;
  final String initialName;
  final String initialConfig;
  final String? initialError;

  @override
  State<ConfigEditorScreen> createState() => _ConfigEditorScreenState();
}

class _ConfigEditorScreenState extends State<ConfigEditorScreen> {
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.initialName,
  );
  late final _config = TextEditingController(
    text: widget.existing?.config ?? widget.initialConfig,
  );
  late String? _error = widget.initialError;
  WgConfig? _preview;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _config.addListener(_reparse);
    _reparse();
  }

  void _reparse() {
    WgConfig? p;
    try {
      p = WgConfig.parse(_config.text);
    } on FormatException {
      p = null;
    }
    if (p?.privateKey != _preview?.privateKey ||
        p?.primaryPeer?.endpoint != _preview?.primaryPeer?.endpoint ||
        (p == null) != (_preview == null)) {
      setState(() => _preview = p);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _config.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = AppScope.read(context);
    final name = _name.text.trim();
    final config = _config.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the tunnel a name');
      return;
    }
    // Fast local check first for a precise line-level message.
    try {
      WgConfig.parse(config);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    String? err;
    if (widget.existing == null) {
      err = await app.addTunnel(name: name, config: config);
    } else {
      err = await app.channel.validateConfig(config);
      if (err == null) {
        await app.updateTunnel(
          widget.existing!.copyWith(name: name, config: config),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = err;
    });
    if (err == null) {
      showSnack(context, widget.existing == null ? 'Tunnel added' : 'Saved');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New tunnel' : 'Edit config'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _config,
            minLines: 12,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              labelText: 'WireGuard config',
              alignLabelWithHint: true,
              hintText: '[Interface]\nPrivateKey = …\nAddress = …\n\n[Peer]\nPublicKey = …\nEndpoint = …\nAllowedIPs = 0.0.0.0/0',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cs.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: context.cs.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: context.cs.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (p != null) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Preview',
              child: Column(
                children: [
                  _Row('Endpoint', p.primaryPeer?.endpoint ?? '—'),
                  _Row(
                    'Address',
                    p.addresses.isEmpty ? '—' : p.addresses.join(', '),
                  ),
                  _Row(
                    'DNS',
                    p.dns.isEmpty ? 'System default' : p.dns.join(', '),
                  ),
                  _Row('Peers', '${p.peers.length}'),
                  _Row(
                    'Routing',
                    (p.primaryPeer?.isFullTunnel ?? false)
                        ? 'All traffic'
                        : 'Selected networks',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.existing == null ? 'Save tunnel' : 'Save changes',
                  ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: context.tt.bodyMedium?.copyWith(
              color: context.cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: context.tt.bodyMedium)),
      ],
    ),
  );
}
