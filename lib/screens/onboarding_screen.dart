import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Three-page first-run intro.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _pages = [
    (
      Icons.verified_user_rounded,
      'Your own private tunnel',
      'Varnika connects to WireGuard servers you control or trust. No accounts, no tracking, no middleman.',
    ),
    (
      Icons.qr_code_scanner_rounded,
      'Bring any WireGuard config',
      'Import a .conf file, scan a QR code from your server, or paste the text. Keys are encrypted on this phone.',
    ),
    (
      Icons.call_split_rounded,
      'Choose what goes through it',
      'Let banking apps bypass the VPN, see live speeds, and turn on Android\'s kill switch in two taps.',
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
              child: Row(
                children: [
                  const Flexible(
                    child: FittedBox(fit: BoxFit.scaleDown, child: Wordmark()),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: AppScope.read(context).completeOnboarding,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final (icon, title, body) = _pages[i];
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  VColors.marigold.withValues(alpha: 0.35),
                                  VColors.marigold.withValues(alpha: 0.05),
                                ],
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: 72,
                              color: VColors.marigold,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            title,
                            style: context.tt.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: context.tt.bodyLarge?.copyWith(
                              color: context.cs.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? VColors.marigold
                          : context.cs.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: VColors.marigold,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: last
                      ? AppScope.read(context).completeOnboarding
                      : () => _pc.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        ),
                  child: Text(last ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
