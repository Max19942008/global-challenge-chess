import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

/// "Midnight & gold": the Global Challenge look. One dark theme everywhere.
abstract final class Palette {
  static const bgTop = Color(0xFF060A17);
  static const bgBottom = Color(0xFF111A38);
  static const surface = Color(0xCC141D3B);
  static const surfaceHi = Color(0xE61B2650);
  static const border = Color(0x1FFFFFFF);
  static const gold = Color(0xFFF2C14E);
  static const goldDeep = Color(0xFFC98E22);
  static const text = Color(0xFFEEF1FF);
  static const muted = Color(0xFF98A2C8);
  static const danger = Color(0xFFFF8A80);

  static const boardLight = Color(0xFFE9E2D0);
  static const boardDark = Color(0xFF3E5F80);

  static const goldGradient = LinearGradient(
    colors: [gold, goldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

const pieceSet = PieceSet.staunty;

const boardColors = ChessboardColorScheme(
  lightSquare: Palette.boardLight,
  darkSquare: Palette.boardDark,
  background: SolidColorChessboardBackground(lightSquare: Palette.boardLight, darkSquare: Palette.boardDark),
  whiteCoordBackground: SolidColorChessboardBackground(
    lightSquare: Palette.boardLight,
    darkSquare: Palette.boardDark,
    coordinates: true,
  ),
  blackCoordBackground: SolidColorChessboardBackground(
    lightSquare: Palette.boardLight,
    darkSquare: Palette.boardDark,
    coordinates: true,
    orientation: Side.black,
  ),
  lastMove: HighlightDetails(solidColor: Color(0x80F2C14E)),
  selected: HighlightDetails(solidColor: Color(0xA0F2C14E)),
  validMoves: Color(0x99B07A1A),
  validPremoves: Color(0x40203085),
);

ThemeData appTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.gold,
    onPrimary: Palette.bgTop,
    secondary: Palette.gold,
    onSecondary: Palette.bgTop,
    surface: Palette.surface,
    onSurface: Palette.text,
    onSurfaceVariant: Palette.muted,
    outline: Palette.border,
    error: Palette.danger,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: base.textTheme.apply(bodyColor: Palette.text, displayColor: Palette.text),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Palette.text),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.gold,
        foregroundColor: Palette.bgTop,
        textStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.2),
        minimumSize: const Size(0, 52),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.text,
        side: const BorderSide(color: Color(0x40FFFFFF)),
        textStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
        minimumSize: const Size(0, 48),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Palette.gold)),
    iconTheme: const IconThemeData(color: Palette.text),
  );
}
