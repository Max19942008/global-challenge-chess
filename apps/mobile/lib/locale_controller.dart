import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language the user picked, remembered across launches.
class LocaleController extends ChangeNotifier {
  LocaleController(this._prefs) : _locale = _read(_prefs);

  static const supported = ['uz', 'ru', 'en'];
  static const _key = 'locale';

  final SharedPreferences _prefs;
  Locale? _locale;

  /// null until the user has picked a language (first launch).
  Locale? get locale => _locale;
  bool get chosen => _locale != null;

  Future<void> choose(Locale locale) async {
    _locale = Locale(locale.languageCode);
    notifyListeners();
    await _prefs.setString(_key, locale.languageCode);
  }

  static Locale? _read(SharedPreferences prefs) {
    final code = prefs.getString(_key);
    return supported.contains(code) ? Locale(code!) : null;
  }

  /// Before the user chooses: the phone's language if we have it, else English.
  static Locale deviceDefault(List<Locale> deviceLocales) {
    for (final l in deviceLocales) {
      if (supported.contains(l.languageCode)) return Locale(l.languageCode);
    }
    return const Locale('en');
  }
}

/// Makes the [LocaleController] reachable from any screen.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({super.key, required LocaleController controller, required super.child})
      : super(notifier: controller);

  static LocaleController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!;
}
