import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaxmat/l10n/app_localizations.dart';
import 'package:shaxmat/main_app.dart';
import 'package:shaxmat/online/online_client.dart';
import 'package:shaxmat/screens/profile_screen.dart';

import 'game_screen_test.dart' show loadFonts;
import 'online_screens_test.dart' show FakeServer, gameStart, lobbyPlayer, pumpLobby, settle, disposeAll;

/// Smallest valid PNG (1×1).
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
  0x89, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0xda, 0x63, 0xf8, 0xcf, 0xc0, 0xf0,
  0x1f, 0x00, 0x05, 0x00, 0x01, 0xff, 0x89, 0x99, 0x3d, 0x1d, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]);

FakeServer _withLobby() => FakeServer()
  ..lobby = [
    lobbyPlayer('u1', 'Guest-1', 'watching'), // me: never listed
    lobbyPlayer('u2', 'Rival', 'ready', rating: 1720, wins: 9),
    lobbyPlayer('u3', 'Busy Bee', 'playing'),
    lobbyPlayer('u4', 'Looker', 'watching'),
  ];

void main() {
  group('screenshots (uz)', () {
    setUpAll(loadFonts);

    testWidgets('players tab', (tester) async {
      final server = _withLobby()
        ..lobby.addAll([
          lobbyPlayer('u8', 'Dilnoza', 'ready', rating: 1655, wins: 14),
          lobbyPlayer('u9', 'Sardor Karimov', 'playing', rating: 1932, wins: 51),
        ]);
      await pumpLobby(tester, tab: 0, fake: server, locale: 'uz');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/7-lobby-players-uz.png'));
      await disposeAll(tester);
    });

    testWidgets('leaderboard', (tester) async {
      final server = FakeServer();
      final names = ['Sardor Karimov', 'Dilnoza', 'Rival', 'Aziz', 'Malika', 'Jasur'];
      server.onSent = (m) {
        if (m['type'] == 'leaderboard:get') {
          server.push({
            'type': 'leaderboard', 'category': m['category'], 'sort': m['sort'],
            'players': [
              for (var i = 0; i < names.length; i++)
                {
                  'rank': i + 1, 'id': 'p$i', 'name': names[i], 'avatar': null, 'rating': 2010 - i * 73,
                  'provisional': false, 'games': 60 - i * 7, 'wins': 51 - i * 6, 'losses': 6 + i, 'draws': 3,
                },
            ],
            'me': {
              'rank': 17, 'id': 'u1', 'name': 'Guest-1', 'avatar': null, 'rating': 1520, 'provisional': false,
              'games': 4, 'wins': 3, 'losses': 1, 'draws': 0,
            },
          });
        }
      };
      await pumpLobby(tester, tab: 2, fake: server, locale: 'uz');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/8-leaderboard-uz.png'));
      await disposeAll(tester);
    });

    testWidgets('incoming challenge', (tester) async {
      final server = await pumpLobby(tester, tab: 0, fake: _withLobby(), locale: 'uz');
      server.push({
        'type': 'challenge:incoming', 'challengeId': 'c9', 'timeControl': '5+0', 'rated': true, 'expiresInMs': 60000,
        'from': {'id': 'u2', 'name': 'Rival', 'rating': 1720, 'provisional': false},
      });
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/9-challenge-uz.png'));
      await disposeAll(tester);
    });
  });

  testWidgets('players tab: groups by status; only ready players get a Challenge button', (tester) async {
    await pumpLobby(tester, tab: 0, fake: _withLobby());
    expect(find.text('Rival'), findsOneWidget);
    expect(find.text('Busy Bee'), findsOneWidget);
    expect(find.text('Looker'), findsOneWidget);
    expect(find.byKey(const ValueKey('player-u1')), findsNothing, reason: 'I am not in my own list');
    expect(find.byKey(const ValueKey('challenge-u2')), findsOneWidget);
    expect(find.byKey(const ValueKey('challenge-u3')), findsNothing);
    expect(find.byKey(const ValueKey('challenge-u4')), findsNothing);
    expect(find.text('9 W · 1 L · 0 D'), findsOneWidget);
    expect(find.text('1720'), findsOneWidget);
    await disposeAll(tester);
  });

  testWidgets('my status: switching to ready tells the server', (tester) async {
    final server = await pumpLobby(tester, tab: 0, fake: _withLobby());
    await tester.tap(find.byKey(const ValueKey('status-ready')));
    await tester.pump();
    final st = server.sent.lastWhere((m) => m['type'] == 'lobby:status');
    expect(st['status'], 'ready');
    expect(find.text('Players in the lobby can challenge you.'), findsOneWidget);
    await disposeAll(tester);
  });

  testWidgets('challenge: pick 10 min, send, opponent accepts, the game opens', (tester) async {
    final server = _withLobby();
    server.onSent = (m) {
      if (m['type'] == 'challenge:send') {
        server.push({
          'type': 'challenge:sent', 'challengeId': 'c1', 'timeControl': m['timeControl'], 'rated': m['rated'],
          'expiresInMs': 60000, 'to': {'id': 'u2', 'name': 'Rival', 'rating': 1720},
        });
      }
    };
    await pumpLobby(tester, tab: 0, fake: server);
    await tester.tap(find.byKey(const ValueKey('challenge-u2')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('tc-10+0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-challenge')));
    await settle(tester);

    final sent = server.sent.lastWhere((m) => m['type'] == 'challenge:send');
    expect(sent['to'], 'u2');
    expect(sent['timeControl'], '10+0');
    expect(sent['rated'], true);
    expect(find.text('Waiting for Rival…'), findsOneWidget);

    server.push({'type': 'challenge:closed', 'challengeId': 'c1', 'reason': 'accepted'});
    server.push(gameStart());
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Waiting for Rival…'), findsNothing);
    expect(find.text('5:00'), findsNWidgets(2), reason: 'online game screen is open');
    await disposeAll(tester);
  });

  testWidgets('challenge: a decline closes the wait and says so', (tester) async {
    final server = _withLobby();
    server.onSent = (m) {
      if (m['type'] == 'challenge:send') {
        server.push({
          'type': 'challenge:sent', 'challengeId': 'c1', 'timeControl': '5+0', 'rated': true,
          'expiresInMs': 60000, 'to': {'id': 'u2', 'name': 'Rival'},
        });
        server.push({'type': 'challenge:closed', 'challengeId': 'c1', 'reason': 'declined'});
      }
    };
    await pumpLobby(tester, tab: 0, fake: server);
    await tester.tap(find.byKey(const ValueKey('challenge-u2')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('send-challenge')));
    await settle(tester);
    expect(find.text('Waiting for Rival…'), findsNothing);
    expect(find.text('Rival declined'), findsOneWidget);
    await disposeAll(tester);
  });

  testWidgets('incoming challenge pops up anywhere; accept answers the server', (tester) async {
    final server = await pumpLobby(tester, tab: 0);
    server.push({
      'type': 'challenge:incoming', 'challengeId': 'c9', 'timeControl': '3+0', 'rated': false, 'expiresInMs': 60000,
      'from': {'id': 'u7', 'name': 'Asal', 'rating': 1810, 'provisional': false},
    });
    await settle(tester);
    expect(find.text('Asal challenges you'), findsOneWidget);
    expect(find.text('Friendly'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('accept-challenge')));
    await settle(tester);
    final r = server.sent.lastWhere((m) => m['type'] == 'challenge:respond');
    expect(r['challengeId'], 'c9');
    expect(r['accept'], true);
    expect(find.text('Asal challenges you'), findsNothing);
    await disposeAll(tester);
  });

  testWidgets('incoming challenge closes itself when the challenger cancels', (tester) async {
    final server = await pumpLobby(tester, tab: 1);
    server.push({
      'type': 'challenge:incoming', 'challengeId': 'c9', 'timeControl': '5+0', 'rated': true, 'expiresInMs': 60000,
      'from': {'id': 'u7', 'name': 'Asal'},
    });
    await settle(tester);
    expect(find.text('Asal challenges you'), findsOneWidget);
    server.push({'type': 'challenge:closed', 'challengeId': 'c9', 'reason': 'cancelled'});
    await settle(tester);
    expect(find.text('Asal challenges you'), findsNothing);
    await disposeAll(tester);
  });

  testWidgets('leaderboard: asks for blitz by rating, shows rows and my place; can sort by wins', (tester) async {
    final server = FakeServer();
    Map<String, dynamic> row(int rank, String id, String name, int rating, int wins) => {
          'rank': rank, 'id': id, 'name': name, 'avatar': null, 'rating': rating, 'provisional': false,
          'games': wins + 2, 'wins': wins, 'losses': 2, 'draws': 0,
        };
    server.onSent = (m) {
      if (m['type'] == 'leaderboard:get') {
        server.push({
          'type': 'leaderboard', 'category': m['category'], 'sort': m['sort'],
          'players': [row(1, 'u5', 'Champion', 2010, 40), row(2, 'u6', 'Second', 1890, 25)],
          'me': row(17, 'u1', 'Guest-1', 1520, 3),
        });
      }
    };
    await pumpLobby(tester, tab: 2, fake: server);
    final get = server.sent.lastWhere((m) => m['type'] == 'leaderboard:get');
    expect(get['category'], 'blitz');
    expect(get['sort'], 'rating');
    expect(find.text('Champion'), findsOneWidget);
    expect(find.text('2010'), findsOneWidget);
    expect(find.textContaining('Your place: #17'), findsOneWidget);

    await tester.tap(find.text('By wins'));
    await settle(tester);
    expect(server.sent.lastWhere((m) => m['type'] == 'leaderboard:get')['sort'], 'wins');
    expect(find.text('40'), findsOneWidget);
    await disposeAll(tester);
  });

  testWidgets('profile: rename and add a photo in one save', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final server = FakeServer();
    server.onSent = (m) {
      if (m['type'] == 'profile:update') {
        server.push({
          'type': 'profile:ok',
          'user': {
            'id': 'u1', 'name': m['name'] ?? 'Guest-1', 'avatar': '/avatar/u1?v=1',
            'ratings': {}, 'stats': {'wins': 3, 'losses': 1, 'draws': 0},
          },
        });
      }
    };
    final client = OnlineClient(prefs: prefs, connector: (_) async => server);
    client.start();
    await tester.pumpWidget(OnlineScope(
      client: client,
      child: MaterialApp(
        theme: appTheme(),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ProfileScreen(pickPhoto: () async => _png),
      ),
    ));
    await settle(tester);
    expect(find.text('3'), findsOneWidget, reason: 'wins');

    await tester.enterText(find.byKey(const ValueKey('profile-name')), 'Bobur');
    await tester.tap(find.byKey(const ValueKey('pick-photo')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('save-profile')));
    await settle(tester);

    final up = server.sent.lastWhere((m) => m['type'] == 'profile:update');
    expect(up['name'], 'Bobur');
    expect(up['avatar'], isA<String>());
    expect(find.text('Saved'), findsOneWidget);
    expect(client.user?.name, 'Bobur');
    expect(client.avatarUrl(client.user?.avatar), 'http://localhost:8080/avatar/u1?v=1');
    await disposeAll(tester);
  });
}
