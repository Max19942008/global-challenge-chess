import 'dart:async';
import 'dart:convert';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' hide File;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaxmat/l10n/app_localizations.dart';
import 'package:shaxmat/main_app.dart';
import 'package:shaxmat/online/lobby_screen.dart';
import 'package:shaxmat/online/online_client.dart';

/// In-memory stand-in for the WebSocket: the test plays the server.
class FakeServer implements OnlineTransport {
  final _in = StreamController<String>.broadcast();
  final sent = <Map<String, dynamic>>[];

  @override
  Stream<String> get incoming => _in.stream;

  @override
  void send(String data) {
    final m = jsonDecode(data) as Map<String, dynamic>;
    sent.add(m);
    switch (m['type']) {
      case 'auth:guest' || 'auth':
        push({
          'type': 'auth:ok',
          'token': 'tok-1',
          'user': {
            'id': 'u1',
            'name': 'Guest-1',
            'ratings': {
              'bullet': {'rating': 1500, 'provisional': true},
              'blitz': {'rating': 1500, 'provisional': true},
              'rapid': {'rating': 1500, 'provisional': true},
            },
          },
        });
        push({'type': 'lobby:stats', 'onlineCount': 42});
      case 'ping':
        push({'type': 'pong', 't': m['t'], 'serverTime': DateTime.now().millisecondsSinceEpoch});
    }
  }

  void push(Map<String, dynamic> m) => _in.add(jsonEncode({'v': 1, ...m}));

  List<String> sentTypes() => [for (final m in sent) m['type'] as String];

  @override
  Future<void> close() async => _in.close();
}

Future<FakeServer> pumpLobby(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final server = FakeServer();
  final client = OnlineClient(prefs: prefs, connector: (_) async => server);
  await tester.pumpWidget(OnlineScope(
    client: client,
    child: MaterialApp(
      theme: appTheme(),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const LobbyScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return server;
}

Future<void> tapSquare(WidgetTester tester, String square, Side orientation) async {
  final board = find.byType(Chessboard);
  final topLeft = tester.getTopLeft(board);
  final size = tester.getSize(board).width / 8;
  final sq = Square.fromName(square);
  final file = orientation == Side.white ? sq.file.value : 7 - sq.file.value;
  final rank = orientation == Side.white ? 7 - sq.rank.value : sq.rank.value;
  await tester.tapAt(topLeft + Offset((file + 0.5) * size, (rank + 0.5) * size));
  await settle(tester);
}

Map<String, dynamic> gameStart({String color = 'white'}) => {
      'type': 'game:start',
      'gameId': 'g1',
      'color': color,
      'opponent': {'id': 'u2', 'name': 'Rival', 'rating': 1530, 'provisional': false},
      'timeControl': '5+0',
      'rated': true,
      'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      'clocks': {'white': 300000, 'black': 300000},
      'serverTime': DateTime.now().millisecondsSinceEpoch,
    };

/// Lets stream events land and route transitions finish (the search animation never settles).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> disposeAll(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  testWidgets('lobby: guest login, online count, find opponent sends queue:join', (tester) async {
    final server = await pumpLobby(tester);
    expect(server.sentTypes().first, 'auth:guest');
    expect(find.text('42 online now'), findsOneWidget);
    expect(find.text('Your rating: 1500?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tc-3+0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('find-opponent')));
    await tester.pump();
    final join = server.sent.lastWhere((m) => m['type'] == 'queue:join');
    expect(join['timeControl'], '3+0');
    expect(join['rated'], true);
    expect(find.byKey(const ValueKey('searching')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cancel-search')));
    await tester.pump();
    expect(server.sentTypes(), contains('queue:leave'));
    await disposeAll(tester);
  });

  testWidgets('lobby: declining the bot offer keeps searching', (tester) async {
    final server = await pumpLobby(tester);
    await tester.tap(find.byKey(const ValueKey('find-opponent')));
    await tester.pump();
    server.push({'type': 'queue:botOffer', 'suggestedElo': 1500});
    await settle(tester);
    expect(find.byKey(const ValueKey('bot-decline')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bot-decline')));
    await settle(tester);
    expect(server.sentTypes(), contains('queue:botDecline'));
    expect(find.byKey(const ValueKey('searching')), findsOneWidget);
    await disposeAll(tester);
  });

  testWidgets('online game: optimistic move, server confirms, opponent replies, result with rating', (tester) async {
    final server = await pumpLobby(tester);
    await tester.tap(find.byKey(const ValueKey('find-opponent')));
    await tester.pump();
    server.push(gameStart());
    await settle(tester);
    final err = tester.takeException();
    expect(err, isNull, reason: '$err');
    expect(find.text('Rival'), findsOneWidget);
    expect(find.text('5:00'), findsNWidgets(2));

    await tapSquare(tester, 'f2', Side.white);
    await tapSquare(tester, 'f3', Side.white);
    final mv = server.sent.lastWhere((m) => m['type'] == 'game:move');
    expect(mv['uci'], 'f2f3');
    expect(mv['ply'], 0);
    expect(find.text('1. f3'), findsOneWidget); // shown before the server answers

    final now = DateTime.now().millisecondsSinceEpoch;
    server.push({
      'type': 'game:move', 'gameId': 'g1', 'uci': 'f2f3', 'ply': 1,
      'fen': 'rnbqkbnr/pppppppp/8/8/8/5P2/PPPPP1PP/RNBQKBNR b KQkq - 0 1',
      'clocks': {'white': 300000, 'black': 300000}, 'serverTime': now,
    });
    server.push({
      'type': 'game:move', 'gameId': 'g1', 'uci': 'e7e5', 'ply': 2,
      'fen': 'rnbqkbnr/pppp1ppp/8/4p3/8/5P2/PPPPP1PP/RNBQKBNR w KQkq - 0 2',
      'clocks': {'white': 300000, 'black': 297000}, 'serverTime': now,
    });
    await settle(tester);
    expect(find.text('e5'), findsOneWidget);
    expect(find.text('4:57'), findsOneWidget);

    server.push({
      'type': 'game:end', 'gameId': 'g1', 'result': '1-0', 'reason': 'resign',
      'ratingChange': {'before': 1500, 'after': 1512},
    });
    await settle(tester);
    expect(find.byKey(const ValueKey('result-text')), findsOneWidget);
    expect(find.text('Black resigned — White wins'), findsWidgets);
    expect(find.text('Rating 1500 → 1512 (+12)'), findsWidgets);
    await disposeAll(tester);
  });

  testWidgets('online game: a rejected move snaps back to the server position', (tester) async {
    final server = await pumpLobby(tester);
    await tester.tap(find.byKey(const ValueKey('find-opponent')));
    await tester.pump();
    server.push(gameStart());
    await settle(tester);

    await tapSquare(tester, 'e2', Side.white);
    await tapSquare(tester, 'e4', Side.white);
    expect(find.text('1. e4'), findsOneWidget);
    server.push({'type': 'error', 'code': 'bad_ply', 'message': 'stale'});
    await settle(tester);
    expect(find.text('1. e4'), findsNothing);
    await disposeAll(tester);
  });

  testWidgets('online game: draw offer from opponent can be accepted', (tester) async {
    final server = await pumpLobby(tester);
    await tester.tap(find.byKey(const ValueKey('find-opponent')));
    await tester.pump();
    server.push(gameStart(color: 'black'));
    await settle(tester);
    server.push({'type': 'game:drawOffer', 'gameId': 'g1', 'from': 'white'});
    await settle(tester);
    expect(find.text('Opponent offers a draw'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('draw-accept')));
    await tester.pump();
    final r = server.sent.lastWhere((m) => m['type'] == 'game:drawRespond');
    expect(r['accept'], true);
    await disposeAll(tester);
  });

  testWidgets('online game: opponent abandons, claim victory', (tester) async {
    final server = await pumpLobby(tester);
    await tester.tap(find.byKey(const ValueKey('find-opponent')));
    await tester.pump();
    server.push(gameStart());
    await settle(tester);
    server.push({'type': 'opponent:disconnected', 'gameId': 'g1', 'graceMs': 20000});
    await settle(tester);
    expect(find.textContaining('Opponent disconnected'), findsOneWidget);
    server.push({'type': 'opponent:abandoned', 'gameId': 'g1'});
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('claim-victory')));
    await tester.pump();
    expect(server.sentTypes(), contains('game:claimVictory'));
    await disposeAll(tester);
  });
}
