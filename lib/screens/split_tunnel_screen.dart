import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tunnel_profile.dart';
import '../models/vpn_status.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Choose which apps use (or bypass) a tunnel.
class SplitTunnelScreen extends StatefulWidget {
  const SplitTunnelScreen({super.key, required this.tunnelId});
  final String tunnelId;

  @override
  State<SplitTunnelScreen> createState() => _SplitTunnelScreenState();
}

class _SplitTunnelScreenState extends State<SplitTunnelScreen> {
  late SplitMode _mode;
  late Set<String> _selected;
  List<InstalledApp>? _apps;
  String? _error;
  String _query = '';
  bool _showSystem = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final t = AppScope.read(context).tunnelById(widget.tunnelId)!;
    _mode = t.splitMode;
    _selected = {...t.apps};
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _apps = null;
      _error = null;
    });
    try {
      final apps = await AppScope.read(context).channel
          .listApps(includeSystem: _showSystem);
      if (mounted) setState(() => _apps = apps);
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Couldn\'t list apps');
    }
  }

  Future<void> _save() async {
    final app = AppScope.read(context);
    final t = app.tunnelById(widget.tunnelId);
    if (t == null) return;
    if (_mode == SplitMode.include && _selected.isEmpty) {
      showSnack(context, 'Pick at least one app, or choose "All apps"');
      return;
    }
    await app.updateTunnel(
      t.copyWith(splitMode: _mode, apps: _selected.toList()..sort()),
    );
    if (!mounted) return;
    final live = app.status.tunnelId == t.id && app.status.isUp;
    showSnack(context, live ? 'Saved. Reconnected to apply' : 'Saved');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    final q = _query.toLowerCase();
    final filtered = apps
        ?.where(
          (a) =>
              q.isEmpty ||
              a.label.toLowerCase().contains(q) ||
              a.packageName.contains(q),
        )
        .toList();
    // Show selected apps first so it's easy to review the choice.
    filtered?.sort((a, b) {
      final sa = _selected.contains(a.packageName),
          sb = _selected.contains(b.packageName);
      if (sa != sb) return sa ? -1 : 1;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard changes?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Split tunneling')),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              sliver: SliverList.list(
                children: [
                  SegmentedButton<SplitMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: SplitMode.all,
                        label: Text('All apps'),
                      ),
                      ButtonSegment(
                        value: SplitMode.exclude,
                        label: Text('Bypass'),
                      ),
                      ButtonSegment(
                        value: SplitMode.include,
                        label: Text('Only'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() {
                      _mode = s.first;
                      _dirty = true;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    switch (_mode) {
                      SplitMode.all =>
                        'Every app on this phone goes through the VPN.',
                      SplitMode.exclude => 'Selected apps skip the VPN and use your normal connection. Great for banking or UPI apps that block VPNs.',
                      SplitMode.include => 'Only the selected apps use the VPN; everything else uses your normal connection.',
                    },
                    style: context.tt.bodyMedium?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                  if (_mode != SplitMode.all) ...[
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search apps',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    Row(
                      children: [
                        Text(
                          '${_selected.length} selected',
                          style: context.tt.labelLarge,
                        ),
                        const Spacer(),
                        Text('System apps', style: context.tt.bodySmall),
                        Switch(
                          value: _showSystem,
                          onChanged: (v) {
                            setState(() => _showSystem = v);
                            _load();
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (_mode != SplitMode.all)
              if (_error != null)
                SliverFillRemaining(child: Center(child: Text(_error!)))
              else if (filtered == null)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final a = filtered[i];
                    final on = _selected.contains(a.packageName);
                    return CheckboxListTile(
                      value: on,
                      activeColor: VColors.marigold,
                      secondary: a.icon == null
                          ? const Icon(Icons.android_rounded, size: 36)
                          : Image.memory(
                              Uint8List.fromList(a.icon!),
                              width: 36,
                              height: 36,
                              gaplessPlayback: true,
                            ),
                      title: Text(a.label, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        a.packageName,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                      onChanged: (v) => setState(() {
                        _dirty = true;
                        v == true
                            ? _selected.add(a.packageName)
                            : _selected.remove(a.packageName);
                      }),
                    );
                  },
                ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ),
      ),
    );
  }
}
