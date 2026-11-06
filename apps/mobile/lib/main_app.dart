import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'locale_controller.dart';
import 'online/online_client.dart';
import 'screens/language_screen.dart';
import 'screens/menu_screen.dart';
import 'ui/theme.dart';

export 'ui/theme.dart' show appTheme;

const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class ShaxmatApp extends StatelessWidget {
  const ShaxmatApp({
    super.key,
    required this.localeController,
    required this.onlineClient,
  });

  final LocaleController localeController;
  final OnlineClient onlineClient;

  @override
  Widget build(BuildContext context) {
    return OnlineScope(
      client: onlineClient,
      child: LocaleScope(
        controller: localeController,
        child: ListenableBuilder(
          listenable: localeController,
          builder: (context, _) => MaterialApp(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: appTheme(),
            localizationsDelegates: localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale:
                localeController.locale ??
                LocaleController.deviceDefault(
                  PlatformDispatcher.instance.locales,
                ),
            home: localeController.chosen
                ? const MenuScreen()
                : const LanguageScreen(firstRun: true),
          ),
        ),
      ),
    );
  }
}
