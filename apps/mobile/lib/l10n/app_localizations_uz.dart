// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'Global Challenge Chess';

  @override
  String get languageName => 'O\'zbekcha';

  @override
  String get chooseLanguage => 'Tilni tanlang';

  @override
  String get language => 'Til';

  @override
  String get menuSubtitle =>
      'Bot bilan mashq qiling. Do\'stlaringiz bilan bellashing.';

  @override
  String get vsBot => 'Bot bilan';

  @override
  String get twoPlayers => 'Ikki kishi';

  @override
  String get level => 'Daraja';

  @override
  String get levelBeginner => 'Boshlovchi';

  @override
  String get levelIntermediate => 'O\'rta';

  @override
  String get levelStrong => 'Kuchli';

  @override
  String get yourColor => 'Rangingiz';

  @override
  String get colorWhite => 'Oq';

  @override
  String get colorRandom => 'Tasodifiy';

  @override
  String get colorBlack => 'Qora';

  @override
  String get start => 'Boshlash';

  @override
  String get botNote => 'Bot telefoningizda ishlaydi, internet kerak emas.';

  @override
  String get twoPlayersNote => 'Bitta telefonda navbatma-navbat o\'ynang.';

  @override
  String get flipBoard => 'Taxtani burish';

  @override
  String get you => 'Siz';

  @override
  String botName(String level) {
    return 'Bot · $level';
  }

  @override
  String get thinking => 'o\'ylamoqda…';

  @override
  String get sideWhite => 'Oqlar';

  @override
  String get sideBlack => 'Qoralar';

  @override
  String get whiteToMove => 'Oqlar navbati';

  @override
  String get blackToMove => 'Qoralar navbati';

  @override
  String get check => 'shah!';

  @override
  String turnWithCheck(String turn, String check) {
    return '$turn — $check';
  }

  @override
  String get whiteWins => 'oqlar yutdi';

  @override
  String get blackWins => 'qoralar yutdi';

  @override
  String get draw => 'durang';

  @override
  String get reasonCheckmate => 'Mat';

  @override
  String get reasonStalemate => 'Pat';

  @override
  String get reasonThreefold => 'Uch marta takrorlanish';

  @override
  String get reasonFiftyMove => '50 yurish qoidasi';

  @override
  String get reasonInsufficient => 'Material yetarli emas';

  @override
  String get whiteResigned => 'Oqlar taslim bo\'ldi';

  @override
  String get blackResigned => 'Qoralar taslim bo\'ldi';

  @override
  String gameOver(String reason, String result) {
    return '$reason — $result';
  }

  @override
  String get noMovesYet => 'Hali yurish yo\'q';

  @override
  String get undo => 'Ortga';

  @override
  String get resign => 'Taslim';

  @override
  String get newGame => 'Yangi o\'yin';

  @override
  String engineError(String error) {
    return 'Dvigatel xatosi: $error';
  }

  @override
  String get moves => 'Yurishlar';

  @override
  String get viewBoard => 'Taxtani ko\'rish';

  @override
  String get gameOverTitle => 'O\'yin tugadi';

  @override
  String get botLevelHint => 'Bot kuchi';

  @override
  String get playOnline => 'Onlayn o\'ynash';

  @override
  String get playOnlineNote => 'Haqiqiy raqiblar, reytingli o\'yinlar.';

  @override
  String onlineNow(int count) {
    return 'Hozir onlayn: $count';
  }

  @override
  String get timeControl => 'Vaqt nazorati';

  @override
  String minutes(String n) {
    return '$n daqiqa';
  }

  @override
  String get findOpponent => 'Raqib topish';

  @override
  String get searching => 'Raqib qidirilmoqda…';

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get botOfferTitle => 'Hozircha bo\'sh raqib yo\'q';

  @override
  String get botOfferBody =>
      'Bot bilan o\'ynaysizmi? Qaror qilguningizcha qidiruv davom etadi.';

  @override
  String get keepSearching => 'Qidirishda davom etish';

  @override
  String get connecting => 'Ulanmoqda…';

  @override
  String get serverUnavailable =>
      'O\'yin serveriga ulanib bo\'lmadi. Internetni tekshiring.';

  @override
  String get retry => 'Qayta urinish';

  @override
  String get offerDraw => 'Durang';

  @override
  String get drawOffered => 'Raqib durang taklif qilmoqda';

  @override
  String get drawOfferSent => 'Durang taklif qilindi';

  @override
  String get drawDeclined => 'Durang rad etildi';

  @override
  String get accept => 'Qabul qilish';

  @override
  String get decline => 'Rad etish';

  @override
  String opponentDisconnected(int seconds) {
    return 'Raqib uzildi — $seconds soniya kutamiz';
  }

  @override
  String get opponentLeft => 'Raqib o\'yinni tark etdi';

  @override
  String get claimVictory => 'G\'alabani olish';

  @override
  String get reconnecting => 'Qayta ulanmoqda…';

  @override
  String ratingChange(int before, int after, String delta) {
    return 'Reyting $before → $after ($delta)';
  }

  @override
  String get reasonTimeout => 'Vaqt tugadi';

  @override
  String get reasonAbandon => 'Raqib chiqib ketdi';

  @override
  String get reasonDrawAgreed => 'Durangga kelishildi';

  @override
  String get reasonAborted => 'O\'yin bekor qilindi';

  @override
  String get unratedAborted => 'Yurish qilinmadi — reyting o\'zgarmadi.';

  @override
  String get yourRating => 'Reytingingiz';
}
