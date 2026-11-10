import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('uz'),
  ];

  /// App name: English in every language.
  ///
  /// In en, this message translates to:
  /// **'Global Challenge Chess'**
  String get appTitle;

  /// This language's own name, shown in the language picker.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @menuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Train with the bot. Challenge your friends.'**
  String get menuSubtitle;

  /// No description provided for @vsBot.
  ///
  /// In en, this message translates to:
  /// **'Play the bot'**
  String get vsBot;

  /// No description provided for @twoPlayers.
  ///
  /// In en, this message translates to:
  /// **'Two players'**
  String get twoPlayers;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @levelBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get levelBeginner;

  /// No description provided for @levelIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get levelIntermediate;

  /// No description provided for @levelStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get levelStrong;

  /// No description provided for @yourColor.
  ///
  /// In en, this message translates to:
  /// **'Your colour'**
  String get yourColor;

  /// No description provided for @colorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colorWhite;

  /// No description provided for @colorRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get colorRandom;

  /// No description provided for @colorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colorBlack;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @botNote.
  ///
  /// In en, this message translates to:
  /// **'The bot runs on your phone. No internet needed.'**
  String get botNote;

  /// No description provided for @twoPlayersNote.
  ///
  /// In en, this message translates to:
  /// **'Take turns on one phone.'**
  String get twoPlayersNote;

  /// No description provided for @flipBoard.
  ///
  /// In en, this message translates to:
  /// **'Flip board'**
  String get flipBoard;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @botName.
  ///
  /// In en, this message translates to:
  /// **'Bot · {level}'**
  String botName(String level);

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'thinking…'**
  String get thinking;

  /// No description provided for @sideWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get sideWhite;

  /// No description provided for @sideBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get sideBlack;

  /// No description provided for @whiteToMove.
  ///
  /// In en, this message translates to:
  /// **'White to move'**
  String get whiteToMove;

  /// No description provided for @blackToMove.
  ///
  /// In en, this message translates to:
  /// **'Black to move'**
  String get blackToMove;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'check!'**
  String get check;

  /// No description provided for @turnWithCheck.
  ///
  /// In en, this message translates to:
  /// **'{turn} — {check}'**
  String turnWithCheck(String turn, String check);

  /// No description provided for @whiteWins.
  ///
  /// In en, this message translates to:
  /// **'White wins'**
  String get whiteWins;

  /// No description provided for @blackWins.
  ///
  /// In en, this message translates to:
  /// **'Black wins'**
  String get blackWins;

  /// No description provided for @draw.
  ///
  /// In en, this message translates to:
  /// **'draw'**
  String get draw;

  /// No description provided for @reasonCheckmate.
  ///
  /// In en, this message translates to:
  /// **'Checkmate'**
  String get reasonCheckmate;

  /// No description provided for @reasonStalemate.
  ///
  /// In en, this message translates to:
  /// **'Stalemate'**
  String get reasonStalemate;

  /// No description provided for @reasonThreefold.
  ///
  /// In en, this message translates to:
  /// **'Threefold repetition'**
  String get reasonThreefold;

  /// No description provided for @reasonFiftyMove.
  ///
  /// In en, this message translates to:
  /// **'Fifty-move rule'**
  String get reasonFiftyMove;

  /// No description provided for @reasonInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient material'**
  String get reasonInsufficient;

  /// No description provided for @whiteResigned.
  ///
  /// In en, this message translates to:
  /// **'White resigned'**
  String get whiteResigned;

  /// No description provided for @blackResigned.
  ///
  /// In en, this message translates to:
  /// **'Black resigned'**
  String get blackResigned;

  /// No description provided for @gameOver.
  ///
  /// In en, this message translates to:
  /// **'{reason} — {result}'**
  String gameOver(String reason, String result);

  /// No description provided for @noMovesYet.
  ///
  /// In en, this message translates to:
  /// **'No moves yet'**
  String get noMovesYet;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @resign.
  ///
  /// In en, this message translates to:
  /// **'Resign'**
  String get resign;

  /// No description provided for @newGame.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get newGame;

  /// No description provided for @engineError.
  ///
  /// In en, this message translates to:
  /// **'Engine error: {error}'**
  String engineError(String error);

  /// No description provided for @moves.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get moves;

  /// No description provided for @viewBoard.
  ///
  /// In en, this message translates to:
  /// **'View board'**
  String get viewBoard;

  /// No description provided for @gameOverTitle.
  ///
  /// In en, this message translates to:
  /// **'Game over'**
  String get gameOverTitle;

  /// No description provided for @botLevelHint.
  ///
  /// In en, this message translates to:
  /// **'Bot strength'**
  String get botLevelHint;

  /// No description provided for @playOnline.
  ///
  /// In en, this message translates to:
  /// **'Play online'**
  String get playOnline;

  /// No description provided for @playOnlineNote.
  ///
  /// In en, this message translates to:
  /// **'Real opponents, rated games.'**
  String get playOnlineNote;

  /// No description provided for @onlineNow.
  ///
  /// In en, this message translates to:
  /// **'{count} online now'**
  String onlineNow(int count);

  /// No description provided for @timeControl.
  ///
  /// In en, this message translates to:
  /// **'Time control'**
  String get timeControl;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String minutes(String n);

  /// No description provided for @findOpponent.
  ///
  /// In en, this message translates to:
  /// **'Find opponent'**
  String get findOpponent;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching for an opponent…'**
  String get searching;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @botOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'No one is free right now'**
  String get botOfferTitle;

  /// No description provided for @botOfferBody.
  ///
  /// In en, this message translates to:
  /// **'Play the bot instead? We keep searching until you decide.'**
  String get botOfferBody;

  /// No description provided for @keepSearching.
  ///
  /// In en, this message translates to:
  /// **'Keep searching'**
  String get keepSearching;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @serverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the game server. Check your internet.'**
  String get serverUnavailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @offerDraw.
  ///
  /// In en, this message translates to:
  /// **'Offer draw'**
  String get offerDraw;

  /// No description provided for @drawOffered.
  ///
  /// In en, this message translates to:
  /// **'Opponent offers a draw'**
  String get drawOffered;

  /// No description provided for @drawOfferSent.
  ///
  /// In en, this message translates to:
  /// **'Draw offered'**
  String get drawOfferSent;

  /// No description provided for @drawDeclined.
  ///
  /// In en, this message translates to:
  /// **'Draw declined'**
  String get drawDeclined;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @opponentDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Opponent disconnected — waiting {seconds} s'**
  String opponentDisconnected(int seconds);

  /// No description provided for @opponentLeft.
  ///
  /// In en, this message translates to:
  /// **'Opponent left the game'**
  String get opponentLeft;

  /// No description provided for @claimVictory.
  ///
  /// In en, this message translates to:
  /// **'Claim victory'**
  String get claimVictory;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get reconnecting;

  /// No description provided for @ratingChange.
  ///
  /// In en, this message translates to:
  /// **'Rating {before} → {after} ({delta})'**
  String ratingChange(int before, int after, String delta);

  /// No description provided for @reasonTimeout.
  ///
  /// In en, this message translates to:
  /// **'Time out'**
  String get reasonTimeout;

  /// No description provided for @reasonAbandon.
  ///
  /// In en, this message translates to:
  /// **'Opponent left'**
  String get reasonAbandon;

  /// No description provided for @reasonDrawAgreed.
  ///
  /// In en, this message translates to:
  /// **'Draw agreed'**
  String get reasonDrawAgreed;

  /// No description provided for @reasonAborted.
  ///
  /// In en, this message translates to:
  /// **'Game aborted'**
  String get reasonAborted;

  /// No description provided for @unratedAborted.
  ///
  /// In en, this message translates to:
  /// **'No one moved in time — no rating change.'**
  String get unratedAborted;

  /// No description provided for @yourRating.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get yourRating;

  /// No description provided for @tabPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get tabPlayers;

  /// No description provided for @tabQuickMatch.
  ///
  /// In en, this message translates to:
  /// **'Quick match'**
  String get tabQuickMatch;

  /// No description provided for @tabLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get tabLeaderboard;

  /// No description provided for @statusWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get statusWatching;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to play'**
  String get statusReady;

  /// No description provided for @statusPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get statusPlaying;

  /// No description provided for @myStatus.
  ///
  /// In en, this message translates to:
  /// **'Your status'**
  String get myStatus;

  /// No description provided for @myStatusWatchingHint.
  ///
  /// In en, this message translates to:
  /// **'Just looking. Nobody can challenge you.'**
  String get myStatusWatchingHint;

  /// No description provided for @myStatusReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Players in the lobby can challenge you.'**
  String get myStatusReadyHint;

  /// No description provided for @nobodyElseOnline.
  ///
  /// In en, this message translates to:
  /// **'Nobody else is online right now. Try a quick match or play the bot.'**
  String get nobodyElseOnline;

  /// No description provided for @challenge.
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get challenge;

  /// No description provided for @challengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Challenge {name}'**
  String challengeTitle(String name);

  /// No description provided for @challengeSend.
  ///
  /// In en, this message translates to:
  /// **'Send challenge'**
  String get challengeSend;

  /// No description provided for @challengeIncoming.
  ///
  /// In en, this message translates to:
  /// **'{name} challenges you'**
  String challengeIncoming(String name);

  /// No description provided for @challengeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name}…'**
  String challengeWaiting(String name);

  /// No description provided for @challengeDeclined.
  ///
  /// In en, this message translates to:
  /// **'{name} declined'**
  String challengeDeclined(String name);

  /// No description provided for @challengeExpired.
  ///
  /// In en, this message translates to:
  /// **'No answer — the challenge expired'**
  String get challengeExpired;

  /// No description provided for @challengeCancelled.
  ///
  /// In en, this message translates to:
  /// **'The challenge was cancelled'**
  String get challengeCancelled;

  /// No description provided for @challengeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That player is busy right now'**
  String get challengeUnavailable;

  /// No description provided for @rated.
  ///
  /// In en, this message translates to:
  /// **'Rated'**
  String get rated;

  /// No description provided for @casual.
  ///
  /// In en, this message translates to:
  /// **'Friendly'**
  String get casual;

  /// No description provided for @statsLine.
  ///
  /// In en, this message translates to:
  /// **'{wins} W · {losses} L · {draws} D'**
  String statsLine(int wins, int losses, int draws);

  /// No description provided for @wins.
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get wins;

  /// No description provided for @losses.
  ///
  /// In en, this message translates to:
  /// **'Losses'**
  String get losses;

  /// No description provided for @draws.
  ///
  /// In en, this message translates to:
  /// **'Draws'**
  String get draws;

  /// No description provided for @sortByRating.
  ///
  /// In en, this message translates to:
  /// **'By rating'**
  String get sortByRating;

  /// No description provided for @sortByWins.
  ///
  /// In en, this message translates to:
  /// **'By wins'**
  String get sortByWins;

  /// No description provided for @yourPlace.
  ///
  /// In en, this message translates to:
  /// **'Your place: #{rank}'**
  String yourPlace(int rank);

  /// No description provided for @leaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No finished games here yet. Be the first!'**
  String get leaderboardEmpty;

  /// No description provided for @ratingExplained.
  ///
  /// In en, this message translates to:
  /// **'Higher rating = stronger player. Win rated games to climb.'**
  String get ratingExplained;

  /// No description provided for @categoryBlitz.
  ///
  /// In en, this message translates to:
  /// **'Blitz'**
  String get categoryBlitz;

  /// No description provided for @categoryRapid.
  ///
  /// In en, this message translates to:
  /// **'Rapid'**
  String get categoryRapid;

  /// No description provided for @categoryBullet.
  ///
  /// In en, this message translates to:
  /// **'Bullet'**
  String get categoryBullet;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// No description provided for @profileNameHint.
  ///
  /// In en, this message translates to:
  /// **'2–24 characters, shown to other players'**
  String get profileNameHint;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @profileBadName.
  ///
  /// In en, this message translates to:
  /// **'The name must be 2–24 characters.'**
  String get profileBadName;

  /// No description provided for @profileBadPhoto.
  ///
  /// In en, this message translates to:
  /// **'This photo could not be used. Try another one.'**
  String get profileBadPhoto;

  /// No description provided for @profileOffline.
  ///
  /// In en, this message translates to:
  /// **'Connect to the server to change your profile.'**
  String get profileOffline;

  /// No description provided for @onlineGamesTitle.
  ///
  /// In en, this message translates to:
  /// **'Online games'**
  String get onlineGamesTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
