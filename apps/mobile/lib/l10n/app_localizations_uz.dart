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

  @override
  String get tabPlayers => 'O\'yinchilar';

  @override
  String get tabQuickMatch => 'Tez o\'yin';

  @override
  String get tabLeaderboard => 'Reyting';

  @override
  String get statusWatching => 'Kuzatuvchi';

  @override
  String get statusReady => 'O\'ynashga tayyor';

  @override
  String get statusPlaying => 'O\'ynayapti';

  @override
  String get myStatus => 'Holatingiz';

  @override
  String get myStatusWatchingHint =>
      'Faqat kuzatyapsiz. Sizni hech kim o\'yinga chaqira olmaydi.';

  @override
  String get myStatusReadyHint =>
      'Lobbidagi o\'yinchilar sizni o\'yinga chaqira oladi.';

  @override
  String get nobodyElseOnline =>
      'Hozir boshqa hech kim onlayn emas. Tez o\'yin yoki bot bilan o\'ynab ko\'ring.';

  @override
  String get challenge => 'Chaqirish';

  @override
  String challengeTitle(String name) {
    return '${name}ni o\'yinga chaqirish';
  }

  @override
  String get challengeSend => 'Chaqiruv yuborish';

  @override
  String challengeIncoming(String name) {
    return '$name sizni o\'yinga chaqirmoqda';
  }

  @override
  String challengeWaiting(String name) {
    return '$name javobini kutyapmiz…';
  }

  @override
  String challengeDeclined(String name) {
    return '$name rad etdi';
  }

  @override
  String get challengeExpired => 'Javob bo\'lmadi — chaqiruv muddati tugadi';

  @override
  String get challengeCancelled => 'Chaqiruv bekor qilindi';

  @override
  String get challengeUnavailable => 'Bu o\'yinchi hozir band';

  @override
  String get rated => 'Reytingli';

  @override
  String get casual => 'O\'rtoqlik';

  @override
  String statsLine(int wins, int losses, int draws) {
    return '$wins G · $losses M · $draws D';
  }

  @override
  String get wins => 'G\'alaba';

  @override
  String get losses => 'Mag\'lubiyat';

  @override
  String get draws => 'Durang';

  @override
  String get sortByRating => 'Reyting bo\'yicha';

  @override
  String get sortByWins => 'G\'alabalar bo\'yicha';

  @override
  String yourPlace(int rank) {
    return 'Sizning o\'rningiz: $rank';
  }

  @override
  String get leaderboardEmpty =>
      'Bu yerda hali tugagan o\'yinlar yo\'q. Birinchi bo\'ling!';

  @override
  String get ratingExplained =>
      'Reyting qancha baland bo\'lsa, o\'yinchi shuncha kuchli. Ko\'tarilish uchun reytingli o\'yinlarda yuting.';

  @override
  String get categoryBlitz => 'Blits';

  @override
  String get categoryRapid => 'Rapid';

  @override
  String get categoryBullet => 'Bullet';

  @override
  String get profile => 'Profil';

  @override
  String get profileName => 'Ism';

  @override
  String get profileNameHint => '2–24 belgi, boshqa o\'yinchilarga ko\'rinadi';

  @override
  String get addPhoto => 'Rasm qo\'shish';

  @override
  String get changePhoto => 'Rasmni o\'zgartirish';

  @override
  String get removePhoto => 'Rasmni o\'chirish';

  @override
  String get save => 'Saqlash';

  @override
  String get saved => 'Saqlandi';

  @override
  String get profileBadName => 'Ism 2–24 belgidan iborat bo\'lishi kerak.';

  @override
  String get profileBadPhoto =>
      'Bu rasmni ishlatib bo\'lmadi. Boshqasini tanlang.';

  @override
  String get profileOffline => 'Profilni o\'zgartirish uchun serverga ulaning.';

  @override
  String get onlineGamesTitle => 'Onlayn o\'yinlar';
}
