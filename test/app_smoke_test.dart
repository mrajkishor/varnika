import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:varnika/app.dart';
import 'package:varnika/models/tunnel_profile.dart';
import 'package:varnika/screens/config_editor_screen.dart';
import 'package:varnika/services/ip_lookup.dart';
import 'package:varnika/services/tunnel_store.dart';
import 'package:varnika/state/app_state.dart';

const _cfg = '''
[Interface]
PrivateKey = yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk=
Address = 10.8.0.2/32
DNS = 1.1.1.1
[Peer]
PublicKey = xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=
Endpoint = in.example.com:51820
AllowedIPs = 0.0.0.0/0
''';

class _MemStore extends TunnelStore {
  _MemStore(this.items);
  List<TunnelProfile> items;
  @override
  Future<List<TunnelProfile>> load() async => [...items];
  @override
  Future<void> save(List<TunnelProfile> t) async => items = [...t];
}

class _FakeIp extends IpLookup {
  @override
  Future<IpInfo> lookup() async => const IpInfo(
    ip: '203.0.113.7',
    city: 'Mumbai',
    country: 'IN',
    org: 'AS0 Example',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now().millisecondsSinceEpoch;
  var rx = 1000;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'lastTunnel': 't1',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('varnika/vpn'), (
          call,
        ) async {
          switch (call.method) {
            case 'getStatus':
              return {
                'state': 'up',
                'tunnelId': 't1',
                'tunnelName': 'Mumbai',
                'since': now - 65000,
              };
            case 'getStats':
              rx += 250000;
              return {'rx': rx, 'tx': rx ~/ 4, 'handshake': now - 20000};
            case 'getHistory':
              return [
                {
                  'name': 'Mumbai',
                  'start': now - 7200000,
                  'end': now - 3600000,
                  'rx': 52428800,
                  'tx': 4194304,
                },
                {
                  'name': 'Frankfurt',
                  'start': now - 90000000,
                  'end': now - 89000000,
                  'rx': 1048576,
                  'tx': 1024,
                },
              ];
            case 'backendVersion':
              return '1.0.20260102';
            case 'killSwitchStatus':
              return {'alwaysOn': true, 'lockdown': false};
            default:
              return null;
          }
        });
  });

  Future<AppState> pumpApp(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = AppState(
      tunnelStore: _MemStore([
        TunnelProfile(
          id: 't1',
          name: 'Mumbai',
          config: _cfg,
          emoji: '🇮🇳',
          favorite: true,
        ),
        TunnelProfile(
          id: 't2',
          name: 'Frankfurt home server with a long name',
          config: _cfg,
          splitMode: SplitMode.exclude,
          apps: ['com.bank'],
        ),
      ]),
      ipLookup: _FakeIp(),
    );
    await state.init();
    await tester.pumpWidget(VarnikaApp(state: state));
    await tester.pump(const Duration(seconds: 3));
    return state;
  }

  testWidgets('home shows protected state with live stats', (tester) async {
    final state = await pumpApp(tester);
    expect(state.status.isUp, isTrue);
    expect(find.text('You\'re protected'), findsOneWidget);
    expect(find.text('Healthy'), findsOneWidget);
    expect(state.ipInfo?.ip, '203.0.113.7');
    await tester.scrollUntilVisible(find.text('203.0.113.7'), 300);
    expect(find.text('203.0.113.7'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('every tab renders without layout errors', (tester) async {
    final state = await pumpApp(tester, size: const Size(360, 640));
    for (final tab in ['Tunnels', 'Insights', 'Settings', 'Connect']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'tab $tab');
    }
    await tester.tap(find.text('Insights').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Most used'), findsOneWidget);
    state.dispose();
  });

  testWidgets('kill switch screen reports status', (tester) async {
    final state = await pumpApp(tester);
    await tester.tap(find.byTooltip('Kill switch'));
    await tester
        .pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 2),
        )
        .catchError((_) => 0);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Always-on VPN'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('tunnel detail opens', (tester) async {
    final state = await pumpApp(tester);
    await tester.tap(find.text('Tunnels').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Frankfurt home server with a long name'));
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(find.text('Split tunneling'), 200);
    expect(find.text('Split tunneling'), findsOneWidget);
    expect(find.text('1 apps bypass the VPN'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('config editor previews and flags bad keys', (tester) async {
    final state = await pumpApp(tester, size: const Size(360, 640));
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: ConfigEditorScreen(initialName: 'X', initialConfig: _cfg),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('in.example.com:51820'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).last,
      '[Interface]\nPrivateKey = bad',
    );
    await tester.pump();
    await tester.tap(find.text('Save tunnel'));
    await tester.pump();
    expect(find.textContaining('PrivateKey'), findsWidgets);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('onboarding renders and completes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = AppState(tunnelStore: _MemStore([]), ipLookup: _FakeIp());
    await state.init();
    await tester.pumpWidget(VarnikaApp(state: state));
    await tester.pump();
    expect(find.text('Your own private tunnel'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Add your first tunnel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.dispose();
  });
}
