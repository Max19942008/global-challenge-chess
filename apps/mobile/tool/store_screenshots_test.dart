// Play Store phone screenshots (1080x2160, 2:1 is the tallest Play allows) in en/uz/ru, written to store/screenshots/.
//
// Regenerate after UI changes (from apps/mobile):
//   flutter test tool/store_screenshots_test.dart --update-goldens
//
// Kept out of test/ so a normal `flutter test` doesn't compare against them.
import 'dart:convert';

import 'package:dartchess/dartchess.dart' hide File;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaxmat/engine/bot.dart';
import 'package:shaxmat/engine/think_time.dart';
import 'package:shaxmat/l10n/app_localizations.dart';
import 'package:shaxmat/locale_controller.dart';
import 'package:shaxmat/main_app.dart';
import 'package:shaxmat/online/game_launcher.dart';
import 'package:shaxmat/online/lobby_screen.dart';
import 'package:shaxmat/online/online_client.dart';
import 'package:shaxmat/screens/game_screen.dart';

import '../test/game_screen_test.dart' show FakeBot, loadFonts, move;
import '../test/online_screens_test.dart' show FakeServer, lobbyPlayer, ratings, settle, disposeAll;

const locales = ['en', 'uz', 'ru'];

Future<void> shot(String locale, String name) =>
    expectLater(find.byType(MaterialApp).first, matchesGoldenFile('../../../store/screenshots/$locale/$name.png'));

void storeSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2160);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

Future<void> images(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await settle(tester);
}

/// FakeServer whose signed-in player has a real-looking name and rating.
class StoreServer extends FakeServer {
  @override
  void send(String data) {
    final m = jsonDecode(data) as Map<String, dynamic>;
    if (m['type'] == 'auth:guest' || m['type'] == 'auth') {
      sent.add(m);
      push({
        'type': 'auth:ok',
        'token': 'tok-1',
        'user': {
          'id': 'u1', 'name': 'Aziz', 'avatar': null,
          'ratings': ratings(1540),
          'stats': {'wins': 12, 'losses': 7, 'draws': 2},
        },
      });
      push({'type': 'lobby:stats', 'onlineCount': onlineCount});
      onSent?.call(m);
      return;
    }
    super.send(data);
  }
}

FakeServer lobbyServer() => StoreServer()
  ..onlineCount = 128
  ..lobby = [
    lobbyPlayer('u2', 'Dilnoza', 'ready', rating: 1655, wins: 14),
    lobbyPlayer('u3', 'Sardor Karimov', 'playing', rating: 1932, wins: 51),
    lobbyPlayer('u4', 'Alex', 'ready', rating: 1580, wins: 7),
    lobbyPlayer('u5', 'Malika', 'playing', rating: 1744, wins: 22),
    lobbyPlayer('u6', 'Ivan', 'watching', rating: 1490, wins: 3),
    lobbyPlayer('u7', 'Jasur', 'watching', rating: 1612, wins: 9),
    lobbyPlayer('u1', 'Aziz', 'watching', rating: 1540, wins: 12), // me: never listed
  ];

Future<FakeServer> pumpLobbyApp(WidgetTester tester, String locale, int tab, FakeServer server) async {
  storeSize(tester);
  SharedPreferences.setMockInitialValues({});
  final client = OnlineClient(prefs: await SharedPreferences.getInstance(), connector: (_) async => server);
  final nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(OnlineScope(
    client: client,
    child: MaterialApp(
      navigatorKey: nav,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => GameLauncher(navigatorKey: nav, child: child!),
      theme: appTheme(),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(locale),
      home: LobbyScreen(initialTab: tab),
    ),
  ));
  await settle(tester);
  return server;
}

void main() {
  setUpAll(loadFonts);

  for (final locale in locales) {
    group(locale, () {
      testWidgets('1 menu', (tester) async {
        storeSize(tester);
        SharedPreferences.setMockInitialValues({'locale': locale});
        final prefs = await SharedPreferences.getInstance();
        final server = StoreServer()..onlineCount = 128;
        await tester.pumpWidget(ShaxmatApp(
          localeController: LocaleController(prefs),
          onlineClient: OnlineClient(prefs: prefs, connector: (_) async => server),
        ));
        await images(tester);
        await shot(locale, '1-menu');
        await disposeAll(tester);
      });

      testWidgets('2 lobby', (tester) async {
        await pumpLobbyApp(tester, locale, 0, lobbyServer());
        await images(tester);
        await shot(locale, '2-lobby');
        await disposeAll(tester);
      });

      testWidgets('3 leaderboard', (tester) async {
        final server = StoreServer()..onlineCount = 128;
        final names = ['Sardor Karimov', 'Malika', 'Dilnoza', 'Alex', 'Jasur', 'Ivan', 'Aziz', 'Elena'];
        server.onSent = (m) {
          if (m['type'] == 'leaderboard:get') {
            server.push({
              'type': 'leaderboard', 'category': m['category'], 'sort': m['sort'],
              'players': [
                for (var i = 0; i < names.length; i++)
                  {
                    'rank': i + 1, 'id': 'p$i', 'name': names[i], 'avatar': null, 'rating': 2010 - i * 61,
                    'provisional': false, 'games': 70 - i * 6, 'wins': 51 - i * 5, 'losses': 12 + i, 'draws': 4,
                  },
              ],
              'me': {
                'rank': 17, 'id': 'u1', 'name': 'Aziz', 'avatar': null, 'rating': 1540, 'provisional': false,
                'games': 21, 'wins': 12, 'losses': 7, 'draws': 2,
              },
            });
          }
        };
        await pumpLobbyApp(tester, locale, 2, server);
        await images(tester);
        await shot(locale, '3-leaderboard');
        await disposeAll(tester);
      });

      testWidgets('4 ai game', (tester) async {
        storeSize(tester);
        final bot = FakeBot(['e7e5', 'b8c6', 'g8f6', 'f8c5']);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(locale),
          home: GameScreen(botLevel: BotLevel.intermediate, botFactory: () async => bot, thinkTime: noThinkTime),
        ));
        await images(tester);
        for (final (from, to) in [('e2', 'e4'), ('g1', 'f3'), ('f1', 'c4'), ('d2', 'd3')]) {
          await move(tester, from, to);
        }
        await images(tester);
        await shot(locale, '4-ai');
        await disposeAll(tester);
      });

      testWidgets('5 online game', (tester) async {
        final server = await pumpLobbyApp(tester, locale, 1, lobbyServer());
        final now = DateTime.now().millisecondsSinceEpoch;
        server.push({
          'type': 'game:start', 'gameId': 'g1', 'color': 'white',
          'opponent': {'id': 'u2', 'name': 'Dilnoza', 'rating': 1655, 'provisional': false},
          'timeControl': '5+0', 'rated': true,
          'fen': Chess.initial.fen, 'clocks': {'white': 300000, 'black': 300000}, 'serverTime': now,
        });
        await settle(tester);
        Position pos = Chess.initial;
        const ucis = ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4', 'c5d4', 'f3d4', 'g8f6', 'b1c3', 'a7a6'];
        for (var i = 0; i < ucis.length; i++) {
          pos = pos.play(Move.parse(ucis[i])!);
          server.push({
            'type': 'game:move', 'gameId': 'g1', 'uci': ucis[i], 'ply': i + 1, 'fen': pos.fen,
            'clocks': {'white': 300000 - i * 4100, 'black': 300000 - i * 5300}, 'serverTime': now,
          });
        }
        await images(tester);
        await shot(locale, '5-online');
        await disposeAll(tester);
      });
    });
  }
}
