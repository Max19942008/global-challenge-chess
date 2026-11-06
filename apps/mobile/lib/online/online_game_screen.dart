import 'dart:async';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../game/chess_game.dart';
import '../l10n/app_localizations.dart';
import '../screens/game_screen.dart' show oneLine, winnerText;
import '../ui/game_layout.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'online_client.dart';

String formatClock(int ms) {
  final total = (ms / 1000).ceil();
  if (ms < 10000) {
    // Tenths under ten seconds, like every chess site.
    return '0:${(ms / 1000).toStringAsFixed(1).padLeft(4, '0')}';
  }
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// An online game. The server owns the truth: the board shows confirmed moves
/// plus at most one optimistic move of ours, and snaps back to the server's
/// state whenever they disagree.
class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({super.key, required this.start});

  /// The game:start or game:state message that opened the game.
  final Map<String, dynamic> start;

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  late OnlineClient _client;
  StreamSubscription<Map<String, dynamic>>? _sub;
  late final ChessboardController _board;
  Timer? _ticker;

  // Filled from widget.start in didChangeDependencies; defaults only cover the first frame.
  String _gameId = '';
  Side _me = Side.white;
  Side _orientation = Side.white;
  String _timeControl = '5+0';
  Map<String, dynamic> _white = const {};
  Map<String, dynamic> _black = const {};

  List<String> _confirmed = [];
  String? _pending;
  ChessGame _view = ChessGame();

  Map<String, int> _clocks = {'white': 0, 'black': 0};
  int _clocksAt = 0; // server time the clocks refer to

  Map<String, dynamic>? _end;
  bool _resultDismissed = false;
  String? _drawOfferFrom;
  bool _drawSent = false;
  String? _toast;
  int? _opponentGoneUntil; // local ms
  bool _opponentAbandoned = false;

  @override
  void initState() {
    super.initState();
    _board = ChessboardController(game: _gameData());
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _end == null) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub == null) {
      _client = OnlineScope.of(context);
      _applyStart(widget.start);
      _sub = _client.events.listen(_onEvent);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    _board.dispose();
    super.dispose();
  }

  Side get _turn => _confirmed.length.isEven ? Side.white : Side.black;

  void _applyStart(Map<String, dynamic> m) {
    _gameId = m['gameId'] as String;
    _me = m['color'] == 'black' ? Side.black : Side.white;
    _orientation = _me;
    _timeControl = m['timeControl'] as String? ?? '5+0';
    if (m['type'] == 'game:start') {
      final me = _client.user;
      final mine = <String, dynamic>{
        'id': me?.id ?? '',
        'name': me?.name ?? '',
        if (me != null) 'rating': me.ratings[ratingCategory(_timeControl)]?.rating,
        if (me != null) 'provisional': me.ratings[ratingCategory(_timeControl)]?.provisional,
      };
      final opp = Map<String, dynamic>.from(m['opponent'] as Map);
      _white = _me == Side.white ? mine : opp;
      _black = _me == Side.white ? opp : mine;
      _confirmed = [];
    } else {
      _white = Map<String, dynamic>.from(m['white'] as Map);
      _black = Map<String, dynamic>.from(m['black'] as Map);
      _confirmed = List<String>.from(m['moves'] as List);
    }
    _pending = null;
    _setClocks(m);
    _rebuild(animate: false);
  }

  void _setClocks(Map<String, dynamic> m) {
    final c = m['clocks'] as Map<String, dynamic>;
    _clocks = {'white': (c['white'] as num).toInt(), 'black': (c['black'] as num).toInt()};
    _clocksAt = (m['serverTime'] as num?)?.toInt() ?? _client.serverNow();
  }

  int _remaining(Side side) {
    final base = _clocks[side.name] ?? 0;
    if (_end != null || side != _turn) return base;
    // Each side's first move is free (the server aborts the game after 30 s instead).
    if (_confirmed.length < 2) return base;
    // Display only: the server decides when time is up.
    return (base - (_client.serverNow() - _clocksAt)).clamp(0, base);
  }

  void _onEvent(Map<String, dynamic> m) {
    if (!mounted || (m['gameId'] != null && m['gameId'] != _gameId)) return;
    setState(() {
      switch (m['type']) {
        case 'game:move':
          final ply = (m['ply'] as num).toInt();
          if (ply == _confirmed.length + 1) {
            final uci = m['uci'] as String;
            _confirmed = [..._confirmed, uci];
            _pending = null;
            _setClocks(m);
            _drawSent = false;
            _rebuild();
            if (!_samePosition(_view.position.fen, m['fen'] as String)) _client.send('game:sync', {'gameId': _gameId});
          } else if (ply > _confirmed.length + 1) {
            _client.send('game:sync', {'gameId': _gameId});
          }
        case 'game:state':
          _applyStart(m);
          _end = null;
        case 'game:end':
          _end = m;
          _pending = null;
          _drawOfferFrom = null;
          _opponentGoneUntil = null;
          _opponentAbandoned = false;
          _rebuild();
        case 'game:drawOffer':
          if (m['from'] != _me.name) _drawOfferFrom = m['from'] as String;
        case 'game:drawDeclined':
          _drawSent = false;
          _toast = AppLocalizations.of(context).drawDeclined;
        case 'opponent:disconnected':
          _opponentGoneUntil = DateTime.now().millisecondsSinceEpoch + (m['graceMs'] as num).toInt();
        case 'opponent:reconnected':
          _opponentGoneUntil = null;
          _opponentAbandoned = false;
        case 'opponent:abandoned':
          _opponentAbandoned = true;
        case 'error':
          // Rejected move: drop the optimistic move; the server follows with game:state.
          if (_pending != null) {
            _pending = null;
            _rebuild(animate: false);
          }
      }
    });
  }

  static bool _samePosition(String a, String b) => a.split(' ').take(4).join(' ') == b.split(' ').take(4).join(' ');

  void _rebuild({bool animate = true}) {
    try {
      _view = ChessGame.fromUciMoves([..._confirmed, ?_pending]);
    } catch (_) {
      _pending = null;
      _view = ChessGame.fromUciMoves(_confirmed);
    }
    _board.updatePosition(_gameData(), animate: animate, resetPremove: true);
  }

  GameData _gameData() {
    final pos = _view.position;
    final canMove = _end == null && _pending == null && pos.turn == _me;
    return GameData(
      fen: pos.fen,
      lastMove: _view.lastMove,
      playerSide: canMove ? (_me == Side.white ? PlayerSide.white : PlayerSide.black) : PlayerSide.none,
      sideToMove: pos.turn,
      validMoves: _view.legalMoves,
      kingSquareInCheck: pos.isCheck ? pos.board.kingOf(pos.turn) : null,
    );
  }

  void _onMove(Move move, {bool? viaDragAndDrop}) {
    if (move is! NormalMove || _end != null || _pending != null || _turn != _me) {
      setState(() => _rebuild(animate: false));
      return;
    }
    final local = ChessGame.fromUciMoves(_confirmed);
    final uci = local.standardUci(move);
    if (!local.playUci(uci)) {
      setState(() => _rebuild(animate: false));
      return;
    }
    final sent = _client.send('game:move', {'gameId': _gameId, 'uci': uci, 'ply': _confirmed.length});
    setState(() {
      _pending = sent ? uci : null;
      _drawOfferFrom = null;
      _rebuild();
    });
  }

  Future<void> _resign() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.bgBottom,
        title: Text('${l.resign}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(key: const ValueKey('confirm-resign'), onPressed: () => Navigator.pop(ctx, true), child: Text(l.resign)),
        ],
      ),
    );
    if (ok == true) _client.send('game:resign', {'gameId': _gameId});
  }

  void _offerDraw() {
    if (_client.send('game:drawOffer', {'gameId': _gameId})) {
      setState(() {
        _drawSent = true;
        _toast = AppLocalizations.of(context).drawOfferSent;
      });
    }
  }

  void _respondDraw(bool accept) {
    _client.send('game:drawRespond', {'gameId': _gameId, 'accept': accept});
    setState(() => _drawOfferFrom = null);
  }

  String _endText(AppLocalizations l) {
    final e = _end!;
    final winner = switch (e['result']) {
      '1-0' => Side.white,
      '0-1' => Side.black,
      _ => null,
    };
    final reason = switch (e['reason']) {
      'checkmate' => l.reasonCheckmate,
      'stalemate' => l.reasonStalemate,
      'threefold' => l.reasonThreefold,
      'fifty-move' => l.reasonFiftyMove,
      'insufficient' => l.reasonInsufficient,
      'resign' => winner == Side.white ? l.blackResigned : l.whiteResigned,
      'timeout' => l.reasonTimeout,
      'abandon' => l.reasonAbandon,
      'draw-agreed' => l.reasonDrawAgreed,
      'aborted' => l.reasonAborted,
      _ => '${e['reason']}',
    };
    if (e['reason'] == 'aborted') return reason;
    return l.gameOver(reason, winnerText(l, winner));
  }

  String? _endDetail(AppLocalizations l) {
    final e = _end!;
    if (e['reason'] == 'aborted') return l.unratedAborted;
    final rc = e['ratingChange'] as Map<String, dynamic>?;
    if (rc == null) return null;
    final before = (rc['before'] as num).round();
    final after = (rc['after'] as num).round();
    final d = after - before;
    return l.ratingChange(before, after, d >= 0 ? '+$d' : '$d');
  }

  Widget _player(AppLocalizations l, Side side) {
    final info = side == Side.white ? _white : _black;
    final rating = info['rating'] as num?;
    final ms = _remaining(side);
    final mine = side == _me;
    return PlayerTile(
      side: side,
      name: mine ? '${info['name'] ?? ''} (${l.you})' : '${info['name'] ?? ''}',
      rating: rating == null ? null : '${rating.round()}${info['provisional'] == true ? '?' : ''}',
      active: _end == null && _turn == side,
      clock: formatClock(ms),
      lowTime: ms < 20000,
    );
  }

  Widget? _banner(AppLocalizations l) {
    if (_client.state != OnlineState.online && _end == null) {
      return _Banner(icon: Icons.wifi_off_rounded, text: l.reconnecting);
    }
    if (_drawOfferFrom != null && _end == null) {
      return _Banner(
        icon: Icons.handshake_outlined,
        text: l.drawOffered,
        actions: [
          TextButton(key: const ValueKey('draw-decline'), onPressed: () => _respondDraw(false), child: Text(l.decline)),
          FilledButton(
            key: const ValueKey('draw-accept'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => _respondDraw(true),
            child: Text(l.accept),
          ),
        ],
      );
    }
    if (_opponentAbandoned && _end == null) {
      return _Banner(
        icon: Icons.person_off_outlined,
        text: l.opponentLeft,
        actions: [
          FilledButton(
            key: const ValueKey('claim-victory'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => _client.send('game:claimVictory', {'gameId': _gameId}),
            child: Text(l.claimVictory),
          ),
        ],
      );
    }
    final until = _opponentGoneUntil;
    if (until != null && _end == null) {
      final s = ((until - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 999);
      return _Banner(icon: Icons.signal_wifi_bad_rounded, text: l.opponentDisconnected(s));
    }
    final toast = _toast;
    if (toast != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _toast == toast) setState(() => _toast = null);
      });
      return _Banner(icon: Icons.info_outline_rounded, text: toast);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = _view.status;
    final over = _end != null;
    final turnText = status.turn == Side.white ? l.whiteToMove : l.blackToMove;
    final statusLine = over ? _endText(l) : (status.check ? l.turnWithCheck(turnText, l.check) : turnText);

    return GameLayout(
      title: '${l.playOnline} · $_timeControl',
      onFlip: () => setState(() => _orientation = _orientation.opposite),
      topPlayer: _player(l, _orientation.opposite),
      bottomPlayer: _player(l, _orientation),
      sanMoves: [for (final m in _view.moves) m.san],
      banner: _banner(l),
      board: (size) => Stack(children: [
        Chessboard(size: size, controller: _board, orientation: _orientation, onMove: _onMove, settings: appBoardSettings()),
        if (over && !_resultDismissed)
          Positioned.fill(
            child: ResultOverlay(
              text: _endText(l),
              detail: _endDetail(l),
              newGameLabel: l.findOpponent,
              onNewGame: () => Navigator.of(context).maybePop(),
              onClose: () => setState(() => _resultDismissed = true),
            ),
          ),
      ]),
      status: StatusCard(text: statusLine, hot: over || status.check, detail: over ? _endDetail(l) : null),
      actions: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('offer-draw'),
            onPressed: over || _drawSent || _confirmed.length < 2 ? null : _offerDraw,
            icon: const Icon(Icons.handshake_outlined, size: 18),
            label: oneLine(l.offerDraw),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: over
              ? FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: oneLine(l.findOpponent))
              : OutlinedButton.icon(
                  key: const ValueKey('resign'),
                  onPressed: _resign,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: oneLine(l.resign),
                ),
        ),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.actions = const []});
  final IconData icon;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.gold.withValues(alpha: 0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: Palette.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, key: const ValueKey('banner-text'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
        // Buttons on their own line so long translations never squeeze them.
        if (actions.isNotEmpty)
          Wrap(alignment: WrapAlignment.end, spacing: 6, children: actions),
      ]),
    );
  }
}
