import 'package:flutter/material.dart';

import '../online/models.dart';
import 'theme.dart';

/// Round profile photo; initials on a colour picked from the name when there is none.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 44, this.status});

  final String name;

  /// Full http(s) URL (OnlineClient.avatarUrl), or null.
  final String? url;
  final double size;

  /// Adds a small coloured dot at the bottom right.
  final PresenceStatus? status;

  static const _colors = [
    Color(0xFF3E5F80),
    Color(0xFF6B4E9B),
    Color(0xFF2E7D6B),
    Color(0xFF9B4E5F),
    Color(0xFF8A6D2B),
    Color(0xFF3B6EA8),
  ];

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'[\s_-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts[1].characters.first : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _colors[name.codeUnits.fold<int>(0, (a, b) => a + b) % _colors.length];
    final fallback = Center(
      child: Text(
        initials(name),
        style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
    final circle = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: Palette.border),
      ),
      child: url == null
          ? fallback
          : Image.network(
              url!,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, _, _) => fallback,
            ),
    );
    if (status == null) return circle;
    final dot = size * 0.28;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          circle,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor(status!),
                border: Border.all(color: Palette.bgBottom, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color statusColor(PresenceStatus s) => switch (s) {
  PresenceStatus.ready => const Color(0xFF4ADE80),
  PresenceStatus.playing => Palette.gold,
  PresenceStatus.watching => Palette.muted,
};
