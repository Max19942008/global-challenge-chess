import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Night-sky gradient with a faint globe grid and a gold glow: the backdrop of every screen.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Palette.bgTop, Palette.bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: CustomPaint(painter: _GlobePainter(), child: child),
    );
  }
}

class _GlobePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = max(size.width, size.height) * 0.62;
    final c = Offset(size.width * 0.92, size.height * 0.04);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [Palette.gold.withValues(alpha: 0.16), Palette.gold.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.05);
    final globe = r * 0.78;
    canvas.drawCircle(c, globe, line);
    for (var i = 1; i < 6; i++) {
      // meridians
      final w = globe * cos(i * pi / 12);
      canvas.drawOval(Rect.fromCenter(center: c, width: w * 2, height: globe * 2), line);
      // parallels
      final y = globe * sin(i * pi / 12);
      final half = sqrt(globe * globe - y * y);
      canvas.drawLine(Offset(c.dx - half, c.dy + y), Offset(c.dx + half, c.dy + y), line);
      canvas.drawLine(Offset(c.dx - half, c.dy - y), Offset(c.dx + half, c.dy - y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Frosted panel used for every card.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.highlight = false});
  final Widget child;
  final EdgeInsets padding;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlight ? Palette.gold.withValues(alpha: 0.7) : Palette.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
          if (highlight) BoxShadow(color: Palette.gold.withValues(alpha: 0.18), blurRadius: 24),
        ],
      ),
      child: child,
    );
  }
}

/// Gold knight-on-globe mark.
class Emblem extends StatelessWidget {
  const Emblem({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: Palette.goldGradient,
        boxShadow: [BoxShadow(color: Palette.gold.withValues(alpha: 0.35), blurRadius: size * 0.4)],
      ),
      child: Image(image: pieceSet.assets[PieceKind.blackKnight]!),
    );
  }
}

/// A player row above/below the board.
class PlayerTile extends StatelessWidget {
  const PlayerTile({
    super.key,
    required this.side,
    required this.name,
    required this.active,
    this.isBot = false,
    this.thinking = false,
    this.clock,
    this.lowTime = false,
    this.rating,
    this.avatar,
  });

  /// Profile photo (online games). The king of the player's colour then sits on its corner.
  final Widget? avatar;

  /// "4:59" — online games only.
  final String? clock;
  final bool lowTime;

  /// "1500" or "1500?" — online games only.
  final String? rating;

  final Side side;
  final String name;
  final bool active;
  final bool isBot;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    final king = pieceSet.assets[side == Side.white ? PieceKind.whiteKing : PieceKind.blackKing]!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Palette.surfaceHi : Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? Palette.gold.withValues(alpha: 0.8) : Palette.border),
      ),
      child: Row(
        children: [
          if (avatar == null)
            _kingBadge(king, 36)
          else
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(clipBehavior: Clip.none, children: [
                avatar!,
                Positioned(right: -4, bottom: -4, child: _kingBadge(king, 20)),
              ]),
            ),
          const SizedBox(width: 12),
          // Name + badge take the free space, so the turn marker sits at the far right.
          Expanded(
            child: Row(children: [
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              if (rating != null) ...[
                const SizedBox(width: 6),
                Text(rating!, style: const TextStyle(color: Palette.muted, fontWeight: FontWeight.w600)),
              ],
              if (isBot) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(gradient: Palette.goldGradient, borderRadius: BorderRadius.circular(6)),
                  child: const Text('BOT',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800, color: Palette.bgTop, letterSpacing: 0.6)),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          if (thinking)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Palette.gold),
            )
          else if (active)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.gold,
                boxShadow: [BoxShadow(color: Palette.gold.withValues(alpha: 0.6), blurRadius: 8)],
              ),
            ),
          if (clock != null) ...[
            const SizedBox(width: 10),
            Container(
              key: ValueKey('clock-${side.name}'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active ? (lowTime ? Palette.danger : Palette.gold) : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                clock!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: active ? Palette.bgTop : Palette.text,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kingBadge(ImageProvider king, double size) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size / 9),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: side == Side.white ? Palette.boardLight : Palette.boardDark,
          border: avatar == null ? null : Border.all(color: Palette.bgBottom, width: 1.5),
        ),
        child: Image(image: king),
      );
}
