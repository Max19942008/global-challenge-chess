import 'dart:io';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' hide File;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaxmat/engine/bot.dart';
import 'package:shaxmat/engine/think_time.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaxmat/l10n/app_localizations.dart';
import 'package:shaxmat/locale_controller.dart';
import 'package:shaxmat/main_app.dart';
import 'package:shaxmat/online/online_client.dart';
import 'package:shaxmat/screens/game_screen.dart';

/// Stand-in for Stockfish (which only runs on Android/iOS): plays scripted
/// moves, then the first legal move it finds.
class FakeBot implements ChessBot {
  FakeBot([List<String> script = const []]) : _script = List.of(script);
  final List<String> _script;
  final List<BotLevel> levels = [];
  final List<String> askedFens = [];
  bool disposed = false;

  @override
  Future<void> newGame(BotLevel level) async => levels.add(level);

  @override
  Future<String?> bestMove(String fen, int movetimeMs) async {
    askedFens.add(fen);
    if (_script.isNotEmpty) return _script.removeAt(0);
    final pos = Chess.fromSetup(Setup.parseFen(fen));
    for (final e in pos.legalMoves.entries) {
      for (final to in e.value.squares) {
        return NormalMove(from: e.key, to: to).uci;
      }
    }
    return null;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

/// Taps the centre of [square] on the board.
Future<void> tapSquare(WidgetTester tester, String square, {Side orientation = Side.white}) async {
  final board = find.byType(Chessboard);
  final topLeft = tester.getTopLeft(board);
  final size = tester.getSize(board).width / 8;
  final sq = Square.fromName(square);
  final file = orientation == Side.white ? sq.file.value : 7 - sq.file.value;
  final rank = orientation == Side.white ? 7 - sq.rank.value : sq.rank.value;
  await tester.tapAt(topLeft + Offset((file + 0.5) * size, (rank + 0.5) * size));
  await tester.pumpAndSettle();
}

Future<void> move(WidgetTester tester, String from, String to, {Side orientation = Side.white}) async {
  await tapSquare(tester, from, orientation: orientation);
  await tapSquare(tester, to, orientation: orientation);
}

Future<void> loadFonts() async {
  // Real fonts so the screenshots are readable (tests default to block glyphs).
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    final file = File('${dir.path}/$f');
    if (file.existsSync()) roboto.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await roboto.load();
  final icons = File('${dir.path}/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
}

void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

/// A 1600x900 desktop browser window.
void desktopSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpScreen(WidgetTester tester, Widget screen, {String locale = 'uz', bool desktop = false}) async {
  desktop ? desktopSize(tester) : phoneSize(tester);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale(locale),
    home: screen,
  ));
  // Piece images are decoded asynchronously; let them land before screenshots.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pumpAndSettle();
}

/// The whole app, as launched, with [saved] as what SharedPreferences holds.
Future<LocaleController> pumpApp(WidgetTester tester, {Map<String, Object> saved = const {}, bool desktop = false}) async {
  desktop ? desktopSize(tester) : phoneSize(tester);
  SharedPreferences.setMockInitialValues(saved);
  final controller = LocaleController(await SharedPreferences.getInstance());
  await tester.pumpWidget(ShaxmatApp(
    localeController: controller,
    onlineClient: OnlineClient(prefs: await SharedPreferences.getInstance(), enabled: false),
  ));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> settleImages(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('first launch asks for a language, in all three languages', (tester) async {
    await pumpApp(tester);
    expect(find.text('Tilni tanlang'), findsOneWidget);
    expect(find.text('Выберите язык'), findsOneWidget);
    expect(find.text('Choose your language'), findsOneWidget);
    for (final name in ["O'zbekcha", 'Русский', 'English']) {
      expect(find.text(name), findsOneWidget);
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/0-language.png'));
  });

  testWidgets('choosing Russian opens the menu in Russian and is remembered', (tester) async {
    final controller = await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('lang-ru')));
    await tester.pumpAndSettle();
    expect(find.text('Global Challenge Chess'), findsOneWidget);
    expect(find.text('С ИИ'), findsOneWidget);
    expect(find.text('Вдвоём'), findsOneWidget);
    expect(controller.locale, const Locale('ru'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), 'ru');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/1-menu-ru.png'));
  });

  testWidgets('a saved language opens straight into the menu', (tester) async {
    await pumpApp(tester, saved: {'locale': 'en'});
    expect(find.text('Choose your language'), findsNothing);
    expect(find.text('Play the AI'), findsOneWidget);
    for (final l in ['Beginner', 'Intermediate', 'Strong']) {
      expect(find.text(l), findsOneWidget);
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/1-menu-en.png'));
  });

  testWidgets('language can be changed from the menu', (tester) async {
    await pumpApp(tester, saved: {'locale': 'uz'});
    expect(find.text('AI bilan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lang-en')));
    await tester.pumpAndSettle();
    expect(find.text('Play the AI'), findsOneWidget);
  });

  testWidgets('game status in Russian and English', (tester) async {
    for (final (locale, turn, mate) in [
      ('ru', 'Ход белых', 'Мат — победа чёрных'),
      ('en', 'White to move', 'Checkmate — Black wins'),
    ]) {
      await pumpScreen(tester, GameScreen(key: UniqueKey()), locale: locale);
      expect(find.text(turn), findsOneWidget);
      for (final m in [['f2', 'f3'], ['e7', 'e5'], ['g2', 'g4'], ['d8', 'h4']]) {
        await move(tester, m[0], m[1]);
      }
      expect(find.text(mate), findsWidgets); // status card + result card
      if (locale == 'ru') {
        await settleImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/2-mate-ru.png'));
      }
    }
  });

  testWidgets("two players: fool's mate ends the game, board locks", (tester) async {
    await pumpScreen(tester, const GameScreen());
    expect(find.text('Oqlar navbati'), findsOneWidget);
    await move(tester, 'f2', 'f3');
    expect(find.text('Qoralar navbati'), findsOneWidget);
    await move(tester, 'e7', 'e5');
    await move(tester, 'g2', 'g4');
    await move(tester, 'd8', 'h4');
    expect(find.text('Mat — qoralar yutdi'), findsWidgets);
    expect(find.text('2. g4'), findsOneWidget);
    expect(find.text('Qh4#'), findsOneWidget);
    await settleImages(tester);
    await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('screens/2-mate.png'));

    // No further moves after mate.
    await tester.tap(find.byKey(const ValueKey('result-view-board')));
    await tester.pumpAndSettle();
    await move(tester, 'a2', 'a3');
    expect(find.text('3. a3'), findsNothing);
    expect(find.text('Qh4#'), findsOneWidget);

    // Undo reopens the game.
    await tester.tap(find.text('Ortga'));
    await tester.pumpAndSettle();
    expect(find.text('Qoralar navbati'), findsOneWidget);
  });

  testWidgets('illegal tap-move is ignored', (tester) async {
    await pumpScreen(tester, const GameScreen());
    await move(tester, 'e2', 'e5');
    expect(find.text("Hali yurish yo'q"), findsOneWidget);
  });

  testWidgets('castling by moving the king two squares', (tester) async {
    await pumpScreen(tester, const GameScreen());
    for (final m in [['e2', 'e4'], ['e7', 'e5'], ['g1', 'f3'], ['b8', 'c6'], ['f1', 'c4'], ['g8', 'f6'], ['e1', 'g1']]) {
      await move(tester, m[0], m[1]);
    }
    expect(find.textContaining('4. O-O'), findsOneWidget);
  });

  testWidgets('promotion picker: choosing a knight', (tester) async {
    await pumpScreen(tester, const GameScreen());
    for (final m in [['a2', 'a4'], ['b7', 'b5'], ['a4', 'b5'], ['a7', 'a6'], ['b5', 'a6'], ['c8', 'b7'], ['a6', 'b7'], ['h7', 'h6']]) {
      await move(tester, m[0], m[1]);
    }
    await tapSquare(tester, 'b7');
    await tapSquare(tester, 'a8');
    await settleImages(tester);
    await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('screens/3-promotion.png'));
    // Picker column from a8 down: queen, knight, rook, bishop.
    await tapSquare(tester, 'a7');
    expect(find.textContaining('5. bxa8=N'), findsOneWidget);
  });

  testWidgets('bot plays first when the player is black, then answers', (tester) async {
    final bot = FakeBot(['e2e4', 'g1f3']);
    await pumpScreen(
      tester,
      GameScreen(botLevel: BotLevel.intermediate, playerSide: Side.black, botFactory: () async => bot, thinkTime: noThinkTime),
    );
    expect(bot.levels, [BotLevel.intermediate]);
    expect(find.text('1. e4'), findsOneWidget);
    expect(find.text('AI · O\'rta'), findsOneWidget);

    await move(tester, 'e7', 'e5', orientation: Side.black);
    expect(find.text('e5'), findsOneWidget);
    expect(find.text('2. Nf3'), findsOneWidget);
    expect(find.text('Qoralar navbati'), findsOneWidget);
    await settleImages(tester);
    await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('screens/4-bot.png'));

    // Undo in a bot game takes back to the player's own turn (2 plies).
    await tester.tap(find.text('Ortga'));
    await tester.pumpAndSettle();
    expect(find.text('1. e4'), findsOneWidget);
    expect(find.text('e5'), findsNothing);
  });

  testWidgets('the AI thinks before it moves, and says so', (tester) async {
    final bot = FakeBot(['e7e5']);
    await pumpScreen(
      tester,
      GameScreen(
        botLevel: BotLevel.beginner,
        botFactory: () async => bot,
        thinkTime: (_, _, _) => const Duration(seconds: 3),
      ),
    );
    await tapSquare(tester, 'e2');
    // The spinner never settles, so pump by hand from here.
    final board = find.byType(Chessboard);
    final square = tester.getSize(board).width / 8;
    await tester.tapAt(tester.getTopLeft(board) + Offset(4.5 * square, 4.5 * square)); // e4
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1. e4'), findsOneWidget);
    expect(find.text("o'ylayapti…"), findsOneWidget);
    expect(find.text('e5'), findsNothing, reason: 'the engine has answered, but the AI is still thinking');
    await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('screens/4b-ai-thinking.png'));

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('e5'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('e5'), findsOneWidget);
    expect(find.text("o'ylayapti…"), findsNothing);
  });

  testWidgets("player can't move the bot's pieces", (tester) async {
    final bot = FakeBot(['e7e5']);
    await pumpScreen(tester, GameScreen(botLevel: BotLevel.beginner, botFactory: () async => bot, thinkTime: noThinkTime));
    await move(tester, 'e7', 'e6'); // black piece, player is white
    expect(find.text("Hali yurish yo'q"), findsOneWidget);
    await move(tester, 'e2', 'e4');
    expect(find.text('1. e4'), findsOneWidget);
    expect(find.text('e5'), findsOneWidget);
  });

  testWidgets('resign and new game', (tester) async {
    final bot = FakeBot();
    await pumpScreen(tester, GameScreen(botLevel: BotLevel.strong, botFactory: () async => bot, thinkTime: noThinkTime));
    await move(tester, 'd2', 'd4');
    await tester.tap(find.text('Taslim'));
    await tester.pumpAndSettle();
    expect(find.text("Oqlar taslim bo'ldi — qoralar yutdi"), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('result-new-game')));
    await tester.pumpAndSettle();
    expect(find.text("Hali yurish yo'q"), findsOneWidget);
    expect(bot.levels, [BotLevel.strong, BotLevel.strong]);
  });

  testWidgets('engine is disposed when leaving the screen', (tester) async {
    final bot = FakeBot();
    await pumpScreen(tester, GameScreen(botLevel: BotLevel.beginner, botFactory: () async => bot, thinkTime: noThinkTime));
    await tester.pumpWidget(const SizedBox());
    expect(bot.disposed, isTrue);
  });

  testWidgets('desktop: menu uses the two-column layout', (tester) async {
    await pumpApp(tester, saved: {'locale': 'en'}, desktop: true);
    await settleImages(tester);
    expect(find.text('Play the AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/5-desktop-menu.png'));
  });

  testWidgets('desktop: board fills the height, panel on the right', (tester) async {
    final bot = FakeBot(['e2e4', 'g1f3', 'f1c4']);
    await pumpScreen(
      tester,
      GameScreen(botLevel: BotLevel.strong, playerSide: Side.black, botFactory: () async => bot, thinkTime: noThinkTime),
      locale: 'en',
      desktop: true,
    );
    await move(tester, 'e7', 'e5', orientation: Side.black);
    await move(tester, 'b8', 'c6', orientation: Side.black);
    final boardSize = tester.getSize(find.byType(Chessboard));
    // 900 high window: board should use most of it, not a phone-sized square.
    expect(boardSize.height, greaterThan(650));
    expect(find.text('MOVES'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await settleImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/6-desktop-game.png'));
  });
}
