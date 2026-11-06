import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../locale_controller.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// First-launch language picker, also opened from the menu.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, this.firstRun = false});

  /// On first run there is no back button, and the title is shown in all languages
  /// because we don't know yet which one the user reads.
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    final controller = LocaleScope.of(context);
    final current = Localizations.localeOf(context).languageCode;
    final l = AppLocalizations.of(context);

    final titles = firstRun
        ? [for (final c in LocaleController.supported) lookupAppLocalizations(Locale(c)).chooseLanguage]
        : [l.chooseLanguage];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                children: [
                  if (!firstRun)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  const Center(child: Emblem(size: 72)),
                  const SizedBox(height: 18),
                  Text(l.appTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const SizedBox(height: 14),
                  for (final t in titles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(t,
                          textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted, fontSize: 16)),
                    ),
                  const SizedBox(height: 22),
                  for (final code in LocaleController.supported)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LanguageTile(
                        code: code,
                        name: lookupAppLocalizations(Locale(code)).languageName,
                        selected: code == current,
                        onTap: () async {
                          await controller.choose(Locale(code));
                          if (!firstRun && context.mounted) Navigator.of(context).pop();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.code, required this.name, required this.selected, required this.onTap});
  final String code;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('lang-$code'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Palette.gold.withValues(alpha: 0.12) : Palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? Palette.gold : Palette.border, width: selected ? 1.6 : 1),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? Palette.goldGradient : null,
                color: selected ? null : Palette.surfaceHi,
              ),
              child: Text(code.toUpperCase(),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: selected ? Palette.bgTop : Palette.text)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            Icon(selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: selected ? Palette.gold : Palette.muted),
          ]),
        ),
      ),
    );
  }
}
