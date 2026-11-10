// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Global Challenge Chess';

  @override
  String get languageName => 'Русский';

  @override
  String get chooseLanguage => 'Выберите язык';

  @override
  String get language => 'Язык';

  @override
  String get menuSubtitle => 'Тренируйтесь с ботом. Бросайте вызов друзьям.';

  @override
  String get vsBot => 'С ботом';

  @override
  String get twoPlayers => 'Вдвоём';

  @override
  String get level => 'Уровень';

  @override
  String get levelBeginner => 'Новичок';

  @override
  String get levelIntermediate => 'Средний';

  @override
  String get levelStrong => 'Сильный';

  @override
  String get yourColor => 'Ваш цвет';

  @override
  String get colorWhite => 'Белые';

  @override
  String get colorRandom => 'Случайно';

  @override
  String get colorBlack => 'Чёрные';

  @override
  String get start => 'Начать';

  @override
  String get botNote => 'Бот работает на вашем телефоне, интернет не нужен.';

  @override
  String get twoPlayersNote => 'Играйте по очереди на одном телефоне.';

  @override
  String get flipBoard => 'Перевернуть доску';

  @override
  String get you => 'Вы';

  @override
  String botName(String level) {
    return 'Бот · $level';
  }

  @override
  String get thinking => 'думает…';

  @override
  String get sideWhite => 'Белые';

  @override
  String get sideBlack => 'Чёрные';

  @override
  String get whiteToMove => 'Ход белых';

  @override
  String get blackToMove => 'Ход чёрных';

  @override
  String get check => 'шах!';

  @override
  String turnWithCheck(String turn, String check) {
    return '$turn — $check';
  }

  @override
  String get whiteWins => 'победа белых';

  @override
  String get blackWins => 'победа чёрных';

  @override
  String get draw => 'ничья';

  @override
  String get reasonCheckmate => 'Мат';

  @override
  String get reasonStalemate => 'Пат';

  @override
  String get reasonThreefold => 'Троекратное повторение';

  @override
  String get reasonFiftyMove => 'Правило 50 ходов';

  @override
  String get reasonInsufficient => 'Недостаточно материала';

  @override
  String get whiteResigned => 'Белые сдались';

  @override
  String get blackResigned => 'Чёрные сдались';

  @override
  String gameOver(String reason, String result) {
    return '$reason — $result';
  }

  @override
  String get noMovesYet => 'Ходов пока нет';

  @override
  String get undo => 'Отменить';

  @override
  String get resign => 'Сдаться';

  @override
  String get newGame => 'Новая игра';

  @override
  String engineError(String error) {
    return 'Ошибка движка: $error';
  }

  @override
  String get moves => 'Ходы';

  @override
  String get viewBoard => 'Посмотреть доску';

  @override
  String get gameOverTitle => 'Партия окончена';

  @override
  String get botLevelHint => 'Сила бота';

  @override
  String get playOnline => 'Играть онлайн';

  @override
  String get playOnlineNote => 'Живые соперники, рейтинговые партии.';

  @override
  String onlineNow(int count) {
    return 'Сейчас онлайн: $count';
  }

  @override
  String get timeControl => 'Контроль времени';

  @override
  String minutes(String n) {
    return '$n мин';
  }

  @override
  String get findOpponent => 'Найти соперника';

  @override
  String get searching => 'Ищем соперника…';

  @override
  String get cancel => 'Отмена';

  @override
  String get botOfferTitle => 'Пока нет свободных соперников';

  @override
  String get botOfferBody =>
      'Сыграть с ботом? Пока вы решаете, поиск продолжается.';

  @override
  String get keepSearching => 'Продолжить поиск';

  @override
  String get connecting => 'Подключение…';

  @override
  String get serverUnavailable =>
      'Не удаётся подключиться к серверу. Проверьте интернет.';

  @override
  String get retry => 'Повторить';

  @override
  String get offerDraw => 'Ничья';

  @override
  String get drawOffered => 'Соперник предлагает ничью';

  @override
  String get drawOfferSent => 'Ничья предложена';

  @override
  String get drawDeclined => 'Ничья отклонена';

  @override
  String get accept => 'Принять';

  @override
  String get decline => 'Отклонить';

  @override
  String opponentDisconnected(int seconds) {
    return 'Соперник отключился — ждём $seconds с';
  }

  @override
  String get opponentLeft => 'Соперник покинул игру';

  @override
  String get claimVictory => 'Забрать победу';

  @override
  String get reconnecting => 'Переподключение…';

  @override
  String ratingChange(int before, int after, String delta) {
    return 'Рейтинг $before → $after ($delta)';
  }

  @override
  String get reasonTimeout => 'Время вышло';

  @override
  String get reasonAbandon => 'Соперник ушёл';

  @override
  String get reasonDrawAgreed => 'Ничья по соглашению';

  @override
  String get reasonAborted => 'Партия отменена';

  @override
  String get unratedAborted => 'Никто не сделал ход — рейтинг не изменился.';

  @override
  String get yourRating => 'Ваш рейтинг';

  @override
  String get tabPlayers => 'Игроки';

  @override
  String get tabQuickMatch => 'Быстрая игра';

  @override
  String get tabLeaderboard => 'Рейтинг';

  @override
  String get statusWatching => 'Наблюдает';

  @override
  String get statusReady => 'Готов играть';

  @override
  String get statusPlaying => 'Играет';

  @override
  String get myStatus => 'Ваш статус';

  @override
  String get myStatusWatchingHint =>
      'Только смотрите. Вам не могут бросить вызов.';

  @override
  String get myStatusReadyHint => 'Игроки в лобби могут бросить вам вызов.';

  @override
  String get nobodyElseOnline =>
      'Сейчас больше никого нет онлайн. Попробуйте быструю игру или бота.';

  @override
  String get challenge => 'Вызвать';

  @override
  String challengeTitle(String name) {
    return 'Вызов: $name';
  }

  @override
  String get challengeSend => 'Отправить вызов';

  @override
  String challengeIncoming(String name) {
    return '$name бросает вам вызов';
  }

  @override
  String challengeWaiting(String name) {
    return 'Ждём ответа: $name…';
  }

  @override
  String challengeDeclined(String name) {
    return '$name отказался';
  }

  @override
  String get challengeExpired => 'Нет ответа — вызов истёк';

  @override
  String get challengeCancelled => 'Вызов отменён';

  @override
  String get challengeUnavailable => 'Этот игрок сейчас занят';

  @override
  String get rated => 'На рейтинг';

  @override
  String get casual => 'Товарищеская';

  @override
  String statsLine(int wins, int losses, int draws) {
    return '$wins В · $losses П · $draws Н';
  }

  @override
  String get wins => 'Победы';

  @override
  String get losses => 'Поражения';

  @override
  String get draws => 'Ничьи';

  @override
  String get sortByRating => 'По рейтингу';

  @override
  String get sortByWins => 'По победам';

  @override
  String yourPlace(int rank) {
    return 'Ваше место: $rank';
  }

  @override
  String get leaderboardEmpty =>
      'Здесь пока нет сыгранных партий. Будьте первым!';

  @override
  String get ratingExplained =>
      'Чем выше рейтинг, тем сильнее игрок. Побеждайте в рейтинговых партиях, чтобы подняться.';

  @override
  String get categoryBlitz => 'Блиц';

  @override
  String get categoryRapid => 'Рапид';

  @override
  String get categoryBullet => 'Пуля';

  @override
  String get profile => 'Профиль';

  @override
  String get profileName => 'Имя';

  @override
  String get profileNameHint => '2–24 символа, видно другим игрокам';

  @override
  String get addPhoto => 'Добавить фото';

  @override
  String get changePhoto => 'Сменить фото';

  @override
  String get removePhoto => 'Удалить фото';

  @override
  String get save => 'Сохранить';

  @override
  String get saved => 'Сохранено';

  @override
  String get profileBadName => 'Имя должно быть от 2 до 24 символов.';

  @override
  String get profileBadPhoto => 'Это фото не подошло. Попробуйте другое.';

  @override
  String get profileOffline =>
      'Подключитесь к серверу, чтобы изменить профиль.';

  @override
  String get onlineGamesTitle => 'Онлайн-партии';
}
