/// End-to-end: two app clients against the REAL server (apps/server) on
/// localhost:8080. Skipped when no server is running.
///   npm run server        (repo root)
///   flutter test test/online_integration_test.dart
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaxmat/online/online_client.dart';

Future<bool> serverUp() async {
  try {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    final r = await (await c.getUrl(Uri.parse('http://localhost:8080/health'))).close();
    c.close();
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<OnlineClient> connect(String key) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = OnlineClient(prefs: prefs, url: Uri.parse('ws://localhost:8080'));
  c.start();
  final done = Completer<void>();
  void l() {
    if (c.state == OnlineState.online && !done.isCompleted) done.complete();
  }

  c.addListener(l);
  await done.future.timeout(const Duration(seconds: 5));
  c.removeListener(l);
  return c;
}

Future<Map<String, dynamic>> next(OnlineClient c, String type, {int? ply}) => c.events
    .firstWhere((m) => m['type'] == type && (ply == null || m['ply'] == ply))
    .timeout(const Duration(seconds: 10));

void main() async {
  final up = await serverUp();

  test('two app clients get matched and play fool\'s mate on the real server', () async {
    final a = await connect('a');
    final b = await connect('b');
    expect(a.user!.ratings.keys, containsAll(['bullet', 'blitz', 'rapid']));

    final startA = next(a, 'game:start');
    final startB = next(b, 'game:start');
    a.send('queue:join', {'timeControl': '5+0', 'rated': true});
    b.send('queue:join', {'timeControl': '5+0', 'rated': true});
    final sa = await startA, sb = await startB;
    expect(sa['gameId'], sb['gameId']);
    expect({sa['color'], sb['color']}, {'white', 'black'});

    final white = sa['color'] == 'white' ? a : b;
    final black = sa['color'] == 'white' ? b : a;
    final id = sa['gameId'] as String;

    var ply = 0;
    for (final uci in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      final mover = ply.isEven ? white : black;
      final echo = next(mover == white ? black : white, 'game:move', ply: ply + 1);
      mover.send('game:move', {'gameId': id, 'uci': uci, 'ply': ply});
      final m = await echo;
      ply++;
      expect(m['uci'], uci);
      expect(m['ply'], ply);
    }
    final endW = await next(white, 'game:end');
    final endB = await next(black, 'game:end');
    expect(endW['reason'], 'checkmate');
    expect(endW['result'], '0-1');
    final rw = endW['ratingChange'] as Map, rb = endB['ratingChange'] as Map;
    expect(rw['after'] < rw['before'], isTrue);
    expect(rb['after'] > rb['before'], isTrue);

    a.dispose();
    b.dispose();
  }, skip: up ? false : 'server not running on localhost:8080');
}
