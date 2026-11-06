import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'theme.dart';
import 'widgets.dart';

/// Desktop/tablet landscape gets the side-panel layout.
bool isWideLayout(BoxConstraints c) => c.maxWidth >= 820 && c.maxWidth > c.maxHeight * 1.05;

/// Screen frame shared by bot, local and online games:
/// desktop = board at full height with a panel on the right,
/// phone = everything on one screen, board as wide as it can be.
class GameLayout extends StatefulWidget {
  const GameLayout({
    super.key,
    required this.title,
    required this.onFlip,
    required this.topPlayer,
    required this.bottomPlayer,
    required this.board,
    required this.status,
    required this.sanMoves,
    required this.actions,
    this.banner,
  });

  final String title;
  final VoidCallback onFlip;
  final Widget topPlayer;
  final Widget bottomPlayer;
  final Widget Function(double size) board;
  final Widget status;
  final List<String> sanMoves;
  final Widget actions;

  /// Optional strip above the status (draw offer, opponent disconnected…).
  final Widget? banner;

  @override
  State<GameLayout> createState() => _GameLayoutState();
}

class _GameLayoutState extends State<GameLayout> {
  final _strip = ScrollController();

  @override
  void didUpdateWidget(GameLayout old) {
    super.didUpdateWidget(old);
    if (old.sanMoves.length != widget.sanMoves.length) {
      // Keep the newest move in view on the phone's move strip.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_strip.hasClients) _strip.jumpTo(_strip.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  Widget _topBar(BuildContext context, AppLocalizations l) {
    return Row(children: [
      IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Text(widget.title,
            overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ),
      IconButton(tooltip: l.flipBoard, icon: const Icon(Icons.swap_vert_rounded), onPressed: widget.onFlip),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => isWideLayout(c) ? _wide(context, l, c) : _narrow(context, l, c),
          ),
        ),
      ),
    );
  }

  Widget _wide(BuildContext context, AppLocalizations l, BoxConstraints c) {
    const pad = 24.0, panel = 360.0, tile = 56.0, gap = 12.0;
    final size = min(c.maxHeight - 2 * pad - 2 * tile - 2 * gap, c.maxWidth - 3 * pad - panel).clamp(240.0, 1400.0);
    return Padding(
      padding: const EdgeInsets.all(pad),
      child: Row(children: [
        Expanded(
          child: Center(
            child: SizedBox(
              width: size,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                widget.topPlayer,
                const SizedBox(height: gap),
                widget.board(size),
                const SizedBox(height: gap),
                widget.bottomPlayer,
              ]),
            ),
          ),
        ),
        const SizedBox(width: pad),
        SizedBox(
          width: panel,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _topBar(context, l),
            const SizedBox(height: 12),
            if (widget.banner != null) ...[widget.banner!, const SizedBox(height: 12)],
            widget.status,
            const SizedBox(height: 12),
            Expanded(child: GlassCard(padding: const EdgeInsets.fromLTRB(18, 14, 18, 8), child: _moveTable(l))),
            const SizedBox(height: 12),
            widget.actions,
          ]),
        ),
      ]),
    );
  }

  Widget _narrow(BuildContext context, AppLocalizations l, BoxConstraints c) {
    const side = 10.0, tile = 58.0, gap = 8.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(side, 4, side, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _topBar(context, l),
        // The board takes whatever height is left after the fixed parts below,
        // so banners and long translations can never push the screen into overflow.
        Expanded(
          child: LayoutBuilder(builder: (context, area) {
            final size = min(area.maxWidth, area.maxHeight - 2 * tile - 2 * gap).clamp(160.0, 900.0);
            return Center(
              child: SizedBox(
                width: size,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  widget.topPlayer,
                  const SizedBox(height: gap),
                  widget.board(size),
                  const SizedBox(height: gap),
                  widget.bottomPlayer,
                ]),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        if (widget.banner != null) ...[widget.banner!, const SizedBox(height: 8)],
        widget.status,
        const SizedBox(height: 8),
        SizedBox(height: 44, child: _moveStrip(l)),
        const SizedBox(height: 10),
        widget.actions,
      ]),
    );
  }

  Widget _moveTable(AppLocalizations l) {
    final moves = widget.sanMoves;
    final rows = (moves.length + 1) ~/ 2;

    Widget cell(int idx) {
      if (idx >= moves.length) return const Expanded(child: SizedBox());
      final last = idx == moves.length - 1;
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: last ? Palette.gold.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(moves[idx],
              style: TextStyle(
                  fontWeight: last ? FontWeight.w800 : FontWeight.w500, color: last ? Palette.gold : Palette.text)),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.moves.toUpperCase(),
          style: const TextStyle(color: Palette.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      Expanded(
        child: moves.isEmpty
            ? Text(l.noMovesYet, style: const TextStyle(color: Palette.muted))
            : ListView.builder(
                itemCount: rows,
                itemBuilder: (context, i) => Row(children: [
                  SizedBox(width: 34, child: Text('${i + 1}.', style: const TextStyle(color: Palette.muted))),
                  cell(i * 2),
                  cell(i * 2 + 1),
                ]),
              ),
      ),
    ]);
  }

  Widget _moveStrip(AppLocalizations l) {
    final moves = widget.sanMoves;
    if (moves.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(l.noMovesYet, style: const TextStyle(color: Palette.muted)),
        ),
      );
    }
    return ListView.separated(
      controller: _strip,
      scrollDirection: Axis.horizontal,
      itemCount: moves.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (context, i) {
        final last = i == moves.length - 1;
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: last ? Palette.gold.withValues(alpha: 0.2) : Palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: last ? Palette.gold.withValues(alpha: 0.7) : Palette.border),
          ),
          child: Text(
            i.isEven ? '${i ~/ 2 + 1}. ${moves[i]}' : moves[i],
            style: TextStyle(fontWeight: FontWeight.w700, color: last ? Palette.gold : Palette.text),
          ),
        );
      },
    );
  }
}

/// Status line card under the board.
class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.text, this.hot = false, this.detail, this.error});
  final String text;
  final bool hot;
  final String? detail;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      highlight: hot,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(text,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: hot ? Palette.gold : Palette.text)),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(detail!, style: const TextStyle(color: Palette.muted)),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(error!, style: const TextStyle(color: Palette.danger)),
          ),
      ]),
    );
  }
}

/// Result card shown over the board when a game ends.
class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    super.key,
    required this.text,
    required this.onNewGame,
    required this.onClose,
    this.detail,
    this.newGameLabel,
  });

  final String text;
  final String? detail;
  final VoidCallback onNewGame;
  final VoidCallback onClose;
  final String? newGameLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: GlassCard(
                highlight: true,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Emblem(size: 52),
                  const SizedBox(height: 12),
                  Text(l.gameOverTitle.toUpperCase(),
                      style: const TextStyle(
                          color: Palette.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                  const SizedBox(height: 6),
                  Text(text,
                      key: const ValueKey('result-text'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Palette.gold)),
                  if (detail != null) ...[
                    const SizedBox(height: 8),
                    Text(detail!,
                        key: const ValueKey('result-detail'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('result-new-game'),
                      onPressed: onNewGame,
                      child: Text(newGameLabel ?? l.newGame),
                    ),
                  ),
                  TextButton(key: const ValueKey('result-view-board'), onPressed: onClose, child: Text(l.viewBoard)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chessground settings with the app's look, shared by every game screen.
ChessboardSettings appBoardSettings() => ChessboardSettings(
      colorScheme: boardColors,
      pieceAssets: pieceSet.assets,
      enablePremoves: false,
      animationDuration: const Duration(milliseconds: 200),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(color: Palette.gold.withValues(alpha: 0.22), blurRadius: 36, spreadRadius: 1),
        BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 12)),
      ],
    );
