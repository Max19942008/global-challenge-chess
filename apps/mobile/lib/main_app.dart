import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'locale_controller.dart';
import 'online/game_launcher.dart';
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

class ShaxmatApp extends StatefulWidget {
  const ShaxmatApp({
    super.key,
    required this.localeController,
    required this.onlineClient,
  });

  final LocaleController localeController;
  final OnlineClient onlineClient;

  @override
  State<ShaxmatApp> createState() => _ShaxmatAppState();
}

class _ShaxmatAppState extends State<ShaxmatApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final localeController = widget.localeController;
    return OnlineScope(
      client: widget.onlineClient,
      child: LocaleScope(
        controller: localeController,
        child: ListenableBuilder(
          listenable: localeController,
          builder: (context, _) => MaterialApp(
            navigatorKey: _navigatorKey,
            builder: (context, child) => GameLauncher(navigatorKey: _navigatorKey, child: child!),
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
