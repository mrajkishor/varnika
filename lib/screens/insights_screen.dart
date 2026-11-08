import 'dart:math';

import 'package:flutter/material.dart';

import '../models/vpn_status.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';

/// Usage over the last 7 days, totals, favourite tunnel and session log.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final history = app.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear session history?'),
                    content: const Text('Usage charts will start from zero.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await app.clearHistory();
              },
            ),
        ],
      ),
      body: history.isEmpty
          ? const EmptyState(
              icon: Icons.insights_rounded,
              title: 'No sessions yet',
              message:
                  'Once you connect and disconnect, your usage, longest sessions and '
                  'favourite servers show up here.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                _Summary(history: history),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Last 7 days',
                  child: _WeekBars(history: history),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Recent sessions',
                  padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
                  child: Column(
                    children: [
                      for (final s in history.take(30)) _SessionTile(s),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.history});
  final List<SessionRecord> history;

  @override
  Widget build(BuildContext context) {
    final total = history.fold<int>(0, (a, s) => a + s.totalBytes);
    final time = history.fold<Duration>(
      Duration.zero,
      (a, s) => a + s.duration,
    );
    final longest = history
        .map((s) => s.duration)
        .reduce((a, b) => a > b ? a : b);
    final counts = <String, int>{};
    for (final s in history) {
      counts[s.tunnelName] = (counts[s.tunnelName] ?? 0) + 1;
    }
    final fav = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    Widget tile(String label, String value, IconData icon, Color color) =>
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 10),
                  Text(
                    value,
                    style: context.tt.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: context.tt.bodySmall?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    return Column(
      children: [
        Row(
          children: [
            tile(
              'Data protected',
              formatBytes(total),
              Icons.lock_rounded,
              context.vc.protected,
            ),
            const SizedBox(width: 10),
            tile(
              'Time connected',
              formatDurationShort(time),
              Icons.timer_outlined,
              VColors.marigold,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            tile(
              'Longest session',
              formatDurationShort(longest),
              Icons.emoji_events_outlined,
              context.vc.upload,
            ),
            const SizedBox(width: 10),
            tile('Most used', fav, Icons.favorite_border_rounded, VColors.rose),
          ],
        ),
      ],
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.history});
  final List<SessionRecord> history;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final rx = List<int>.filled(7, 0), tx = List<int>.filled(7, 0);
    for (final s in history) {
      final d = DateTime(s.start.year, s.start.month, s.start.day);
      final i = days.indexOf(d);
      if (i >= 0) {
        rx[i] += s.rxBytes;
        tx[i] += s.txBytes;
      }
    }
    final peak = max(1, List.generate(7, (i) => rx[i] + tx[i]).reduce(max));
    final weekTotal =
        rx.fold<int>(0, (a, b) => a + b) + tx.fold<int>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatBytes(weekTotal), style: context.tt.headlineSmall),
        const SizedBox(height: 16),
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Tooltip(
                    message:
                        '${formatDate(days[i])}: ↓ ${formatBytes(rx[i])}  ↑ ${formatBytes(tx[i])}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _bar(
                            context,
                            tx[i] / peak,
                            context.vc.upload,
                            top: true,
                          ),
                          _bar(
                            context,
                            rx[i] / peak,
                            context.vc.download,
                            top: tx[i] == 0,
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              i == 6 ? 'Today' : weekdayShort(days[i]),
                              maxLines: 1,
                              style: context.tt.labelSmall?.copyWith(
                                fontWeight: i == 6 ? FontWeight.w800 : null,
                                color: i == 6
                                    ? context.cs.onSurface
                                    : context.cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Dot(color: context.vc.download),
            const SizedBox(width: 4),
            Text('Download', style: context.tt.labelSmall),
            const SizedBox(width: 12),
            Dot(color: context.vc.upload),
            const SizedBox(width: 4),
            Text('Upload', style: context.tt.labelSmall),
          ],
        ),
      ],
    );
  }

  Widget _bar(
    BuildContext context,
    double frac,
    Color color, {
    required bool top,
  }) => Container(
    height: max(frac > 0 ? 3.0 : 0.0, frac * 96),
    decoration: BoxDecoration(
      color: color,
      borderRadius: top
          ? const BorderRadius.vertical(top: Radius.circular(6))
          : null,
    ),
  );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile(this.s);
  final SessionRecord s;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: CircleAvatar(
      backgroundColor: context.cs.surfaceContainerHigh,
      child: Icon(
        Icons.history_rounded,
        size: 20,
        color: context.cs.onSurfaceVariant,
      ),
    ),
    title: Text(s.tunnelName, style: context.tt.titleSmall),
    subtitle: Text(
      '${formatDate(s.start)}, ${formatTime(s.start)} · ${formatDurationShort(s.duration)}',
    ),
    trailing: Text(formatBytes(s.totalBytes), style: context.tt.labelLarge),
  );
}
