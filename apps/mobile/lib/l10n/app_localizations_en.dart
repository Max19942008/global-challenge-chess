// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Global Challenge Chess';

  @override
  String get languageName => 'English';

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get language => 'Language';

  @override
  String get menuSubtitle => 'Train with the bot. Challenge your friends.';

  @override
  String get vsBot => 'Play the bot';

  @override
  String get twoPlayers => 'Two players';

  @override
  String get level => 'Level';

  @override
  String get levelBeginner => 'Beginner';

  @override
  String get levelIntermediate => 'Intermediate';

  @override
  String get levelStrong => 'Strong';

  @override
  String get yourColor => 'Your colour';

  @override
  String get colorWhite => 'White';

  @override
  String get colorRandom => 'Random';

  @override
  String get colorBlack => 'Black';

  @override
  String get start => 'Start';

  @override
  String get botNote => 'The bot runs on your phone. No internet needed.';

  @override
  String get twoPlayersNote => 'Take turns on one phone.';

  @override
  String get flipBoard => 'Flip board';

  @override
  String get you => 'You';

  @override
  String botName(String level) {
    return 'Bot · $level';
  }

  @override
  String get thinking => 'thinking…';

  @override
  String get sideWhite => 'White';

  @override
  String get sideBlack => 'Black';

  @override
  String get whiteToMove => 'White to move';

  @override
  String get blackToMove => 'Black to move';

  @override
  String get check => 'check!';

  @override
  String turnWithCheck(String turn, String check) {
    return '$turn — $check';
  }

  @override
  String get whiteWins => 'White wins';

  @override
  String get blackWins => 'Black wins';

  @override
  String get draw => 'draw';

  @override
  String get reasonCheckmate => 'Checkmate';

  @override
  String get reasonStalemate => 'Stalemate';

  @override
  String get reasonThreefold => 'Threefold repetition';

  @override
  String get reasonFiftyMove => 'Fifty-move rule';

  @override
  String get reasonInsufficient => 'Insufficient material';

  @override
  String get whiteResigned => 'White resigned';

  @override
  String get blackResigned => 'Black resigned';

  @override
  String gameOver(String reason, String result) {
    return '$reason — $result';
  }

  @override
  String get noMovesYet => 'No moves yet';

  @override
  String get undo => 'Undo';

  @override
  String get resign => 'Resign';

  @override
  String get newGame => 'New game';

  @override
  String engineError(String error) {
    return 'Engine error: $error';
  }

  @override
  String get moves => 'Moves';

  @override
  String get viewBoard => 'View board';

  @override
  String get gameOverTitle => 'Game over';

  @override
  String get botLevelHint => 'Bot strength';

  @override
  String get playOnline => 'Play online';

  @override
  String get playOnlineNote => 'Real opponents, rated games.';

  @override
  String onlineNow(int count) {
    return '$count online now';
  }

  @override
  String get timeControl => 'Time control';

  @override
  String minutes(String n) {
    return '$n min';
  }

  @override
  String get findOpponent => 'Find opponent';

  @override
  String get searching => 'Searching for an opponent…';

  @override
  String get cancel => 'Cancel';

  @override
  String get botOfferTitle => 'No one is free right now';

  @override
  String get botOfferBody =>
      'Play the bot instead? We keep searching until you decide.';

  @override
  String get keepSearching => 'Keep searching';

  @override
  String get connecting => 'Connecting…';

  @override
  String get serverUnavailable =>
      'Can\'t reach the game server. Check your internet.';

  @override
  String get retry => 'Retry';

  @override
  String get offerDraw => 'Offer draw';

  @override
  String get drawOffered => 'Opponent offers a draw';

  @override
  String get drawOfferSent => 'Draw offered';

  @override
  String get drawDeclined => 'Draw declined';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String opponentDisconnected(int seconds) {
    return 'Opponent disconnected — waiting $seconds s';
  }

  @override
  String get opponentLeft => 'Opponent left the game';

  @override
  String get claimVictory => 'Claim victory';

  @override
  String get reconnecting => 'Reconnecting…';

  @override
  String ratingChange(int before, int after, String delta) {
    return 'Rating $before → $after ($delta)';
  }

  @override
  String get reasonTimeout => 'Time out';

  @override
  String get reasonAbandon => 'Opponent left';

  @override
  String get reasonDrawAgreed => 'Draw agreed';

  @override
  String get reasonAborted => 'Game aborted';

  @override
  String get unratedAborted => 'No one moved in time — no rating change.';

  @override
  String get yourRating => 'Your rating';
}
