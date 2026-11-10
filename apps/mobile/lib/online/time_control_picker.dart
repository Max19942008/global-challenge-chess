import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../ui/theme.dart';

/// Time controls the server accepts (apps/server/src/config.ts).
const timeControls = ['3+0', '5+0', '10+0'];

/// Three tiles: 3 / 5 / 10 minutes.
class TimeControlPicker extends StatelessWidget {
  const TimeControlPicker({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        for (var i = 0; i < timeControls.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _TcTile(
              key: ValueKey('tc-${timeControls[i]}'),
              label: l.minutes(timeControls[i].split('+').first),
              sub: timeControls[i],
              selected: value == timeControls[i],
              onTap: () => onChanged(timeControls[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _TcTile extends StatelessWidget {
  const _TcTile({super.key, required this.label, required this.sub, required this.selected, required this.onTap});
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Palette.gold.withValues(alpha: 0.14) : Palette.surfaceHi,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? Palette.gold : Palette.border, width: selected ? 1.6 : 1),
          ),
          child: Column(
            children: [
              Icon(Icons.timer_outlined, color: selected ? Palette.gold : Palette.muted),
              const SizedBox(height: 6),
              FittedBox(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Palette.gold : Palette.text),
                ),
              ),
              Text(sub, style: const TextStyle(color: Palette.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small caps section label used on the online screens.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(color: Palette.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}
