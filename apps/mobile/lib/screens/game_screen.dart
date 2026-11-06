import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../engine/bot.dart';
import '../game/chess_game.dart';
import '../l10n/app_localizations.dart';
import '../ui/game_layout.dart';
import '../ui/widgets.dart';
import 'menu_screen.dart' show levelLabel;

/// null [botLevel] = two players on one device.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.botLevel, this.playerSide = Side.white, this.botFactory = StockfishBot.start});

  final BotLevel? botLevel;
  final Side playerSide;
  final BotFactory botFactory;

  bool get vsBot => botLevel != null;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// Button labels stay on one line and shrink if a translation is long.
Widget oneLine(String text) => FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));

String sideName(AppLocalizations l, Side side) => side == Side.white ? l.sideWhite : l.sideBlack;

String winnerText(AppLocalizations l, Side? winner) => switch (winner) {
      Side.white => l.whiteWins,
      Side.black => l.blackWins,
      null => l.draw,
    };

String statusText(AppLocalizations l, GameStatus s) {
  if (s.over) {
    final reason = switch (s.reason!) {
      EndReason.checkmate => l.reasonCheckmate,
      EndReason.stalemate => l.reasonStalemate,
      EndReason.threefold => l.reasonThreefold,
      EndReason.fiftyMove => l.reasonFiftyMove,
      EndReason.insufficient => l.reasonInsufficient,
      EndReason.resign => s.winner == Side.white ? l.blackResigned : l.whiteResigned,
    };
    return l.gameOver(reason, winnerText(l, s.winner));
  }
  final turn = s.turn == Side.white ? l.whiteToMove : l.blackToMove;
  return s.check ? l.turnWithCheck(turn, l.check) : turn;
}

class _GameScreenState extends State<GameScreen> {
  ChessGame _game = ChessGame();
  late final ChessboardController _board;
  late Side _orientation;
  ChessBot? _bot;
  bool _thinking = false;
  String? _engineError;

  /// Bumped on new game / undo / resign so a stale engine reply is ignored.
  int _epoch = 0;

  /// The result card over the board was closed to look at the final position.
  bool _resultDismissed = false;

  Side get _botSide => widget.playerSide.opposite;

  @override
  void initState() {
    super.initState();
    _orientation = widget.playerSide;
    _board = ChessboardController(game: _gameData());
    if (widget.vsBot) _startEngine();
  }

  Future<void> _startEngine() async {
    try {
      final bot = await widget.botFactory();
      if (!mounted) {
        await bot.dispose();
        return;
      }
      await bot.newGame(widget.botLevel!);
      _bot = bot;
      _maybeBotMove();
    } catch (e) {
      if (mounted) setState(() => _engineError = '$e');
    }
  }

  @override
  void dispose() {
    _board.dispose();
    _bot?.dispose();
    super.dispose();
  }

  PlayerSide _movable() {
    final s = _game.status;
    if (s.over) return PlayerSide.none;
    if (!widget.vsBot) return PlayerSide.both;
    if (_thinking || s.turn != widget.playerSide) return PlayerSide.none;
    return widget.playerSide == Side.white ? PlayerSide.white : PlayerSide.black;
  }

  GameData _gameData() {
    final pos = _game.position;
    return GameData(
      fen: pos.fen,
      lastMove: _game.lastMove,
      playerSide: _movable(),
      sideToMove: pos.turn,
      validMoves: _game.legalMoves,
      kingSquareInCheck: pos.isCheck ? pos.board.kingOf(pos.turn) : null,
    );
  }

  void _refresh({bool animate = true}) {
    _board.updatePosition(_gameData(), animate: animate, resetPremove: true);
    if (!_game.status.over) _resultDismissed = false;
    setState(() {});
  }

  void _onMove(Move move, {bool? viaDragAndDrop}) {
    if (move is NormalMove && _game.play(move)) {
      _refresh();
      _maybeBotMove();
    } else {
      _refresh(animate: false); // snap back
    }
  }

  Future<void> _maybeBotMove() async {
    final bot = _bot;
    if (bot == null || _thinking || _game.status.over || _game.position.turn != _botSide) return;
    final epoch = _epoch;
    setState(() => _thinking = true);
    _refresh();
    try {
      final uci = await bot.bestMove(_game.position.fen, botLevels[widget.botLevel]!.movetimeMs);
      if (!mounted || epoch != _epoch) return;
      if (uci != null) _game.playUci(uci);
    } catch (e) {
      if (mounted) setState(() => _engineError = '$e');
    } finally {
      if (mounted && epoch == _epoch) {
        _thinking = false;
        _refresh();
      }
    }
  }

  void _undo() {
    if (widget.vsBot && _thinking) return;
    _epoch++;
    _game.undo();
    if (widget.vsBot && _game.position.turn != widget.playerSide) _game.undo();
    _thinking = false;
    _refresh(animate: false);
  }

  void _restart() {
    _epoch++;
    _game = ChessGame();
    _thinking = false;
    _refresh(animate: false);
    final bot = _bot;
    if (bot != null) bot.newGame(widget.botLevel!).then((_) => _maybeBotMove());
  }

  void _resign() {
    if (_game.status.over) return;
    _epoch++;
    _thinking = false;
    _game.resigned = widget.vsBot ? widget.playerSide : _game.position.turn;
    _refresh();
  }

  Widget _player(AppLocalizations l, Side side) {
    final status = _game.status;
    final isBot = widget.vsBot && side == _botSide;
    final name = isBot
        ? l.botName(levelLabel(l, widget.botLevel!))
        : widget.vsBot
            ? l.you
            : sideName(l, side);
    return PlayerTile(
      side: side,
      name: name,
      active: !status.over && status.turn == side,
      isBot: isBot,
      thinking: _thinking && isBot,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = _game.status;
    return GameLayout(
      title: widget.vsBot ? l.vsBot : l.twoPlayers,
      onFlip: () => setState(() => _orientation = _orientation.opposite),
      topPlayer: _player(l, _orientation.opposite),
      bottomPlayer: _player(l, _orientation),
      sanMoves: [for (final m in _game.moves) m.san],
      board: (size) => Stack(children: [
        Chessboard(
          size: size,
          controller: _board,
          orientation: _orientation,
          onMove: _onMove,
          settings: appBoardSettings(),
        ),
        if (status.over && !_resultDismissed)
          Positioned.fill(
            child: ResultOverlay(
              text: statusText(l, status),
              onNewGame: _restart,
              onClose: () => setState(() => _resultDismissed = true),
            ),
          ),
      ]),
      status: StatusCard(
        text: statusText(l, status),
        hot: status.over || status.check,
        error: _engineError == null ? null : l.engineError(_engineError!),
      ),
      actions: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _game.moves.isEmpty || (widget.vsBot && _thinking) ? null : _undo,
            icon: const Icon(Icons.undo_rounded, size: 18),
            label: oneLine(l.undo),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: status.over ? null : _resign,
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: oneLine(l.resign),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: FilledButton(onPressed: _restart, child: oneLine(l.newGame))),
      ]),
    );
  }
}
