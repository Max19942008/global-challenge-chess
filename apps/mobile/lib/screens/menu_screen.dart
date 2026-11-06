import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../engine/bot.dart';
import '../l10n/app_localizations.dart';
import '../online/lobby_screen.dart';
import '../online/online_client.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'game_screen.dart';
import 'language_screen.dart';

enum ColorChoice { white, random, black }

String levelLabel(AppLocalizations l, BotLevel level) => switch (level) {
      BotLevel.beginner => l.levelBeginner,
      BotLevel.intermediate => l.levelIntermediate,
      BotLevel.strong => l.levelStrong,
    };

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  BotLevel _level = BotLevel.beginner;
  ColorChoice _color = ColorChoice.white;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Connect early so the menu can show how many people are online.
    OnlineScope.of(context).start();
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _startBot() {
    final side = switch (_color) {
      ColorChoice.white => Side.white,
      ColorChoice.black => Side.black,
      ColorChoice.random => Random().nextBool() ? Side.white : Side.black,
    };
    _open(GameScreen(botLevel: _level, playerSide: side));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final langButton = Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('open-language'),
                onPressed: () => _open(const LanguageScreen()),
                icon: const Icon(Icons.language_rounded),
                label: Text(l.languageName),
              ),
            );
            final options = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _onlineCard(l),
              const SizedBox(height: 14),
              _botCard(l),
              const SizedBox(height: 14),
              _friendCard(l),
            ]);

            if (wide) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                child: Column(children: [
                  langButton,
                  Expanded(
                    child: Row(children: [
                      Expanded(child: _hero(l, big: true)),
                      const SizedBox(width: 48),
                      SizedBox(width: 460, child: Center(child: SingleChildScrollView(child: options))),
                    ]),
                  ),
                ]),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                langButton,
                _hero(l, big: false),
                const SizedBox(height: 22),
                options,
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _hero(AppLocalizations l, {required bool big}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Emblem(size: big ? 96 : 64),
        SizedBox(height: big ? 28 : 16),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Palette.text, Palette.gold],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(r),
          child: Text(
            l.appTitle,
            style: TextStyle(
              fontSize: big ? 64 : 36,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(l.menuSubtitle, style: TextStyle(fontSize: big ? 20 : 16, color: Palette.muted, height: 1.35)),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(color: Palette.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      );

  Widget _botCard(AppLocalizations l) {
    final colors = [
      (ColorChoice.white, l.colorWhite),
      (ColorChoice.random, l.colorRandom),
      (ColorChoice.black, l.colorBlack),
    ];
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.smart_toy_rounded, color: Palette.gold),
          const SizedBox(width: 10),
          Text(l.vsBot, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 18),
        _sectionLabel(l.level),
        Row(children: [
          for (var i = 0; i < BotLevel.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _ChoiceTile(
                selected: _level == BotLevel.values[i],
                onTap: () => setState(() => _level = BotLevel.values[i]),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _StrengthBars(level: i + 1, selected: _level == BotLevel.values[i]),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(levelLabel(l, BotLevel.values[i]),
                        maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 16),
        _sectionLabel(l.yourColor),
        Row(children: [
          for (var i = 0; i < colors.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _ChoiceTile(
                selected: _color == colors[i].$1,
                onTap: () => setState(() => _color = colors[i].$1),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(height: 34, child: _colorIcon(colors[i].$1)),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(colors[i].$2, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _startBot,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(l.start),
        ),
        const SizedBox(height: 10),
        Text(l.botNote, style: const TextStyle(color: Palette.muted, fontSize: 13)),
      ]),
    );
  }

  Widget _colorIcon(ColorChoice c) {
    Widget king(PieceKind k, double h) => Image(image: pieceSet.assets[k]!, height: h);
    return switch (c) {
      ColorChoice.white => king(PieceKind.whiteKing, 34),
      ColorChoice.black => king(PieceKind.blackKing, 34),
      ColorChoice.random => Row(
          mainAxisSize: MainAxisSize.min,
          children: [king(PieceKind.whiteKing, 26), king(PieceKind.blackKing, 26)],
        ),
    };
  }

  Widget _onlineCard(AppLocalizations l) {
    final client = OnlineScope.of(context);
    final online = client.state == OnlineState.online;
    return GlassCard(
      highlight: true,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(gradient: Palette.goldGradient, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.public_rounded, color: Palette.bgTop, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.playOnline, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(l.playOnlineNote, style: const TextStyle(color: Palette.muted, fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? const Color(0xFF4ADE80) : Palette.muted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              online ? l.onlineNow(client.onlineCount) : l.connecting,
              key: const ValueKey('menu-online-count'),
              style: const TextStyle(color: Palette.muted, fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('open-online'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 18)),
            onPressed: () => _open(const LobbyScreen()),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l.start),
          ),
        ]),
      ]),
    );
  }

  Widget _friendCard(AppLocalizations l) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: Palette.surfaceHi, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.people_alt_rounded, color: Palette.gold, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.twoPlayers, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(l.twoPlayersNote, style: const TextStyle(color: Palette.muted, fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 10),
        FilledButton(
          key: const ValueKey('start-local'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          onPressed: () => _open(const GameScreen()),
          child: Text(l.start),
        ),
      ]),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Palette.gold.withValues(alpha: 0.14) : Palette.surfaceHi,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? Palette.gold : Palette.border, width: selected ? 1.6 : 1),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: selected ? Palette.gold : Palette.text),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 1–3 rising bars, like a signal meter.
class _StrengthBars extends StatelessWidget {
  const _StrengthBars({required this.level, required this.selected});
  final int level;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 1; i <= 3; i++) ...[
            if (i > 1) const SizedBox(width: 3),
            Container(
              width: 6,
              height: 8.0 + i * 4.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i <= level ? (selected ? Palette.gold : Palette.text) : Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
