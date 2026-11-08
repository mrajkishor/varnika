import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vpn_status.dart';
import '../theme.dart';

/// The big round connect button. Ripples outward while protected and
/// spins an arc while connecting.
class ConnectOrb extends StatefulWidget {
  const ConnectOrb({
    super.key,
    required this.state,
    required this.onTap,
    this.size = 228,
  });

  final VpnState state;
  final VoidCallback onTap;
  final double size;

  @override
  State<ConnectOrb> createState() => _ConnectOrbState();
}

class _ConnectOrbState extends State<ConnectOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final up = s == VpnState.up;
    final busy = s == VpnState.connecting || s == VpnState.disconnecting;
    final color = up ? context.vc.protected : context.vc.unprotected;
    final label = switch (s) {
      VpnState.up => 'Protected',
      VpnState.connecting => 'Connecting',
      VpnState.disconnecting => 'Stopping',
      _ => 'Connect',
    };

    return Semantics(
      button: true,
      label: up ? 'Disconnect VPN' : 'Connect VPN',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: SizedBox.square(
          dimension: widget.size + 72,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _OrbPainter(
                t: _c.value,
                color: color,
                up: up,
                busy: busy,
                track: context.cs.outlineVariant,
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: up
                        ? RadialGradient(
                            colors: [
                              color.withValues(alpha: 0.95),
                              color.withValues(alpha: 0.7),
                            ],
                          )
                        : null,
                    color: up ? null : context.cs.surfaceContainerLowest,
                    border: Border.all(
                      color: color.withValues(alpha: up ? 0 : 0.9),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: up ? 0.45 : 0.18),
                        blurRadius: up ? 48 : 24,
                        spreadRadius: up ? 4 : 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          up
                              ? Icons.verified_user_rounded
                              : Icons.power_settings_new_rounded,
                          key: ValueKey(up),
                          size: 64,
                          color: up ? Colors.white : color,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        label,
                        style: context.tt.titleMedium?.copyWith(
                          color: up ? Colors.white : context.cs.onSurface,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.t,
    required this.color,
    required this.up,
    required this.busy,
    required this.track,
  });

  final double t;
  final Color color;
  final bool up;
  final bool busy;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.shortestSide / 2 - 36;

    if (up) {
      // Three staggered ripples.
      for (var i = 0; i < 3; i++) {
        final p = (t + i / 3) % 1.0;
        final r = base + p * 34;
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: (1 - p) * 0.5),
        );
      }
    } else {
      canvas.drawCircle(
        c,
        base + 18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = track.withValues(alpha: 0.7),
      );
    }

    if (busy) {
      final rect = Rect.fromCircle(center: c, radius: base + 18);
      canvas.drawArc(
        rect,
        t * 2 * pi * 2,
        pi * 0.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 4
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.t != t || old.color != color || old.up != up || old.busy != busy;
}
