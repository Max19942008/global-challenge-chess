import 'package:dartchess/dartchess.dart';

/// Why a game ended. Mirrors `EndReason` in packages/chess-core.
enum EndReason {
  checkmate,
  stalemate,
  threefold,
  fiftyMove,
  insufficient,
  resign,
}

class GameStatus {
  const GameStatus({required this.over, required this.turn, required this.check, this.winner, this.reason});

  final bool over;
  final Side turn;
  final bool check;

  /// null with [over] = draw.
  final Side? winner;
  final EndReason? reason;
}

class PlayedMove {
  const PlayedMove(this.move, this.san);
  final NormalMove move;
  final String san;
}

/// Local game state on top of dartchess. Rules come from the library;
/// only repetition and the fifty-move rule need history, so they live here.
///
/// On the device this is for instant feedback only. Once the app talks to the
/// server, the server's FEN wins whenever the two disagree.
class ChessGame {
  ChessGame() : _positions = [Chess.initial];

  final List<Position> _positions;
  final List<PlayedMove> _moves = [];
  Side? resigned;

  Position get position => _positions.last;
  List<PlayedMove> get moves => List.unmodifiable(_moves);
  NormalMove? get lastMove => _moves.isEmpty ? null : _moves.last.move;
  int get ply => _moves.length;

  /// Legal destinations, castling both as king-two-squares and king-to-rook.
  Map<Square, Set<Square>> get legalMoves => makeLegalMoves(position);

  bool isPromotion(NormalMove move) {
    final pos = position;
    return move.promotion == null &&
        pos.board.roleAt(move.from) == Role.pawn &&
        ((move.to.rank == Rank.eighth && pos.turn == Side.white) ||
            (move.to.rank == Rank.first && pos.turn == Side.black));
  }

  /// Plays [move] if legal. Returns false (and changes nothing) otherwise.
  bool play(NormalMove move) {
    if (status.over) return false;
    final pos = position;
    if (!pos.isLegal(move)) return false;
    final normalized = pos.normalizeMove(move);
    final (next, san) = pos.makeSan(normalized);
    _positions.add(next);
    // Keep the move as the board sent it, so the last-move highlight lands on
    // the square the king was dropped on.
    _moves.add(PlayedMove(move, san));
    return true;
  }

  bool playUci(String uci) {
    final m = Move.parse(uci);
    return m is NormalMove && play(m);
  }

  /// Replays a server's move list (standard UCI). Throws if a move is illegal.
  factory ChessGame.fromUciMoves(Iterable<String> moves) {
    final g = ChessGame();
    for (final uci in moves) {
      if (!g.playUci(uci)) throw ArgumentError('Illegal move in history: $uci');
    }
    return g;
  }

  /// [move] in standard UCI for the current position. The board may report
  /// castling as king-onto-rook (e1h1); servers and engines expect e1g1.
  String standardUci(NormalMove move) {
    final pos = position;
    final from = move.from.name;
    final to = move.to.name;
    if (pos.board.roleAt(move.from) == Role.king && from[1] == to[1]) {
      final df = to.codeUnitAt(0) - from.codeUnitAt(0);
      final ontoOwnRook = pos.board.roleAt(move.to) == Role.rook && pos.board.pieceAt(move.to)?.color == pos.turn;
      if (df.abs() >= 2 || ontoOwnRook) return '$from${df > 0 ? 'g' : 'c'}${from[1]}';
    }
    return move.uci;
  }

  List<String> get uciMoves => [for (var i = 0; i < _moves.length; i++) _uciAt(i)];

  String _uciAt(int i) {
    final before = ChessGame._at(_positions[i]);
    return before.standardUci(_moves[i].move);
  }

  ChessGame._at(Position p) : _positions = [p];

  void undo() {
    if (_moves.isEmpty) return;
    _moves.removeLast();
    _positions.removeLast();
    resigned = null;
  }

  /// Board, side to move, castling and en passant: what makes positions "the same".
  static String _repetitionKey(Position p) => p.fen.split(' ').take(4).join(' ');

  bool get isThreefold {
    final key = _repetitionKey(position);
    // Only positions since the last capture or pawn move can repeat.
    final window = position.halfmoves + 1;
    final start = (_positions.length - window).clamp(0, _positions.length);
    var count = 0;
    for (var i = start; i < _positions.length; i++) {
      if (_repetitionKey(_positions[i]) == key) count++;
    }
    return count >= 3;
  }

  GameStatus get status {
    final pos = position;
    final turn = pos.turn;
    final check = pos.isCheck;
    if (resigned != null) {
      return GameStatus(over: true, turn: turn, check: check, winner: resigned!.opposite, reason: EndReason.resign);
    }
    if (pos.isCheckmate) {
      return GameStatus(over: true, turn: turn, check: check, winner: turn.opposite, reason: EndReason.checkmate);
    }
    GameStatus draw(EndReason r) => GameStatus(over: true, turn: turn, check: check, reason: r);
    if (pos.isStalemate) return draw(EndReason.stalemate);
    if (pos.isInsufficientMaterial) return draw(EndReason.insufficient);
    if (isThreefold) return draw(EndReason.threefold);
    if (pos.halfmoves >= 100) return draw(EndReason.fiftyMove);
    return GameStatus(over: false, turn: turn, check: check);
  }
}
