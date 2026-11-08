import 'package:flutter_test/flutter_test.dart';
import 'package:varnika/models/tunnel_profile.dart';
import 'package:varnika/models/wg_config.dart';
import 'package:varnika/util/format.dart';

const _priv = 'yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk=';
const _pub = 'xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=';

const _sample =
    '''
# Mumbai server
[Interface]
PrivateKey = $_priv
Address = 10.8.0.2/32, fd00::2/128
DNS = 1.1.1.1
DNS = 9.9.9.9
MTU = 1420

[Peer]
PublicKey = $_pub
Endpoint = in.example.com:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
''';

void main() {
  group('WgConfig.parse', () {
    test('parses a full config', () {
      final c = WgConfig.parse(_sample);
      expect(c.privateKey, _priv);
      expect(c.addresses, ['10.8.0.2/32', 'fd00::2/128']);
      expect(c.dns, [
        '1.1.1.1',
        '9.9.9.9',
      ], reason: 'repeated DNS keys are additive');
      expect(c.mtu, 1420);
      expect(c.peers, hasLength(1));
      final p = c.primaryPeer!;
      expect(p.publicKey, _pub);
      expect(p.endpoint, 'in.example.com:51820');
      expect(p.endpointHost, 'in.example.com');
      expect(p.isFullTunnel, isTrue);
      expect(p.persistentKeepalive, 25);
    });

    test('keys and sections are case-insensitive, comments are stripped', () {
      final c = WgConfig.parse(
        '[interface]\nprivatekey = $_priv # mine\n[PEER]\npublickey=$_pub',
      );
      expect(c.privateKey, _priv);
      expect(c.peers.single.publicKey, _pub);
    });

    test('handles IPv6 endpoints', () {
      final c = WgConfig.parse(
        '[Interface]\nPrivateKey = $_priv\n[Peer]\nPublicKey = $_pub\nEndpoint = [2001:db8::1]:51820',
      );
      expect(c.primaryPeer!.endpointHost, '2001:db8::1');
    });

    test('rejects missing interface', () {
      expect(
        () => WgConfig.parse('[Peer]\nPublicKey = $_pub'),
        throwsFormatException,
      );
    });

    test('rejects bad private key', () {
      expect(
        () => WgConfig.parse('[Interface]\nPrivateKey = nope'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('PrivateKey'),
          ),
        ),
      );
    });

    test('rejects invalid peer key with peer index', () {
      expect(
        () => WgConfig.parse(
          '[Interface]\nPrivateKey = $_priv\n[Peer]\nPublicKey = <server public key>',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Peer 1'),
          ),
        ),
      );
    });

    test('reports line numbers for junk lines', () {
      expect(
        () => WgConfig.parse(
          '[Interface]\nPrivateKey = $_priv\nthis is not valid',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Line 3'),
          ),
        ),
      );
    });

    test('key validation', () {
      expect(WgConfig.isValidKey(_priv), isTrue);
      expect(WgConfig.isValidKey('abc='), isFalse);
    });

    test('suggests names from file names', () {
      expect(
        WgConfig.suggestName('/sdcard/Download/in_mumbai_01.conf'),
        'in mumbai 01',
      );
      expect(WgConfig.suggestName(null), 'My tunnel');
      expect(WgConfig.suggestName('.conf'), 'My tunnel');
    });
  });

  group('TunnelProfile', () {
    test('round-trips through JSON', () {
      final t = TunnelProfile(
        id: 'a1',
        name: 'Home',
        config: _sample,
        splitMode: SplitMode.exclude,
        apps: ['com.bank.app'],
        emoji: '🏠',
        favorite: true,
      );
      final back = TunnelProfile.fromJson(t.toJson());
      expect(back.name, 'Home');
      expect(back.splitMode, SplitMode.exclude);
      expect(back.apps, ['com.bank.app']);
      expect(back.favorite, isTrue);
      expect(back.endpointLabel, 'in.example.com:51820');
    });

    test('unknown split mode falls back to all', () {
      expect(SplitMode.fromName('weird'), SplitMode.all);
    });
  });

  group('format', () {
    test('bytes', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(50 * 1024 * 1024), '50 MB');
    });

    test('rates', () {
      expect(formatRate(0), '0 bps');
      expect(formatRate(125000), '1.0 Mbps');
    });

    test('durations', () {
      expect(
        formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
      expect(formatDurationShort(const Duration(minutes: 135)), '2h 15m');
      expect(formatDurationShort(const Duration(seconds: 42)), '42s');
    });
  });
}
