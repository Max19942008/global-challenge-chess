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
  String get menuSubtitle => 'Train with the AI. Challenge your friends.';

  @override
  String get vsBot => 'Play the AI';

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
  String get botNote => 'The AI runs on your phone. No internet needed.';

  @override
  String get twoPlayersNote => 'Take turns on one phone.';

  @override
  String get flipBoard => 'Flip board';

  @override
  String get you => 'You';

  @override
  String botName(String level) {
    return 'AI · $level';
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
  String get botLevelHint => 'AI strength';

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
      'Play the AI instead? We keep searching until you decide.';

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

  @override
  String get tabPlayers => 'Players';

  @override
  String get tabQuickMatch => 'Quick match';

  @override
  String get tabLeaderboard => 'Leaderboard';

  @override
  String get statusWatching => 'Watching';

  @override
  String get statusReady => 'Ready to play';

  @override
  String get statusPlaying => 'Playing';

  @override
  String get myStatus => 'Your status';

  @override
  String get myStatusWatchingHint => 'Just looking. Nobody can challenge you.';

  @override
  String get myStatusReadyHint => 'Players in the lobby can challenge you.';

  @override
  String get nobodyElseOnline =>
      'Nobody else is online right now. Try a quick match or play the AI.';

  @override
  String get challenge => 'Challenge';

  @override
  String challengeTitle(String name) {
    return 'Challenge $name';
  }

  @override
  String get challengeSend => 'Send challenge';

  @override
  String challengeIncoming(String name) {
    return '$name challenges you';
  }

  @override
  String challengeWaiting(String name) {
    return 'Waiting for $name…';
  }

  @override
  String challengeDeclined(String name) {
    return '$name declined';
  }

  @override
  String get challengeExpired => 'No answer — the challenge expired';

  @override
  String get challengeCancelled => 'The challenge was cancelled';

  @override
  String get challengeUnavailable => 'That player is busy right now';

  @override
  String get rated => 'Rated';

  @override
  String get casual => 'Friendly';

  @override
  String statsLine(int wins, int losses, int draws) {
    return '$wins W · $losses L · $draws D';
  }

  @override
  String get wins => 'Wins';

  @override
  String get losses => 'Losses';

  @override
  String get draws => 'Draws';

  @override
  String get sortByRating => 'By rating';

  @override
  String get sortByWins => 'By wins';

  @override
  String yourPlace(int rank) {
    return 'Your place: #$rank';
  }

  @override
  String get leaderboardEmpty => 'No finished games here yet. Be the first!';

  @override
  String get ratingExplained =>
      'Higher rating = stronger player. Win rated games to climb.';

  @override
  String get categoryBlitz => 'Blitz';

  @override
  String get categoryRapid => 'Rapid';

  @override
  String get categoryBullet => 'Bullet';

  @override
  String get profile => 'Profile';

  @override
  String get profileName => 'Name';

  @override
  String get profileNameHint => '2–24 characters, shown to other players';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get profileBadName => 'The name must be 2–24 characters.';

  @override
  String get profileBadPhoto =>
      'This photo could not be used. Try another one.';

  @override
  String get profileOffline => 'Connect to the server to change your profile.';

  @override
  String get onlineGamesTitle => 'Online games';
}
