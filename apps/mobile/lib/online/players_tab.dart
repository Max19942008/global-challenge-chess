import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../ui/avatar.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'challenge_dialogs.dart';
import 'online_client.dart';
import 'time_control_picker.dart';

String statusLabel(AppLocalizations l, PresenceStatus s) => switch (s) {
  PresenceStatus.watching => l.statusWatching,
  PresenceStatus.ready => l.statusReady,
  PresenceStatus.playing => l.statusPlaying,
};

/// Ready players first: they're the ones you can challenge.
const _groupOrder = [PresenceStatus.ready, PresenceStatus.playing, PresenceStatus.watching];

/// Everyone online: ready players first (with a Challenge button), then who's
/// playing, then who's just watching. On top: my own status switch.
class PlayersTab extends StatelessWidget {
  const PlayersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final client = OnlineScope.of(context);
    final me = client.user?.id;
    final others = client.players.where((p) => p.id != me).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _MyStatusCard(client: client),
        const SizedBox(height: 18),
        if (others.isEmpty)
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.people_outline_rounded, color: Palette.muted),
                const SizedBox(width: 12),
                Expanded(child: Text(l.nobodyElseOnline, key: const ValueKey('nobody-online'))),
              ],
            ),
          )
        else
          for (final group in _groupOrder)
            if (others.any((p) => p.status == group)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                child: SectionLabel('${statusLabel(l, group)} · ${others.where((p) => p.status == group).length}'),
              ),
              for (final p in others.where((p) => p.status == group))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PlayerRow(player: p),
                ),
              const SizedBox(height: 8),
            ],
      ],
    );
  }
}

class _MyStatusCard extends StatelessWidget {
  const _MyStatusCard({required this.client});
  final OnlineClient client;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ready = client.myStatus == PresenceStatus.ready;
    return GlassCard(
      highlight: ready,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(l.myStatus),
          const SizedBox(height: 10),
          SegmentedButton<PresenceStatus>(
            key: const ValueKey('my-status'),
            segments: [
              ButtonSegment(
                value: PresenceStatus.watching,
                icon: const Icon(Icons.visibility_outlined),
                label: Text(l.statusWatching, key: const ValueKey('status-watching')),
              ),
              ButtonSegment(
                value: PresenceStatus.ready,
                icon: const Icon(Icons.bolt_rounded),
                label: Text(l.statusReady, key: const ValueKey('status-ready')),
              ),
            ],
            selected: {ready ? PresenceStatus.ready : PresenceStatus.watching},
            onSelectionChanged: (s) => client.setStatus(s.first),
          ),
          const SizedBox(height: 10),
          Text(
            ready ? l.myStatusReadyHint : l.myStatusWatchingHint,
            style: const TextStyle(color: Palette.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player});
  final LobbyPlayer player;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final client = OnlineScope.of(context);
    final p = player;
    final blitz = p.ratings['blitz'];
    return Container(
      key: ValueKey('player-${p.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.border),
      ),
      child: Row(
        children: [
          Avatar(name: p.name, url: client.avatarUrl(p.avatar), size: 46, status: p.status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    if (blitz != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded, color: Palette.gold, size: 16),
                      Text(
                        blitz.label,
                        style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  l.statsLine(p.stats.wins, p.stats.losses, p.stats.draws),
                  style: const TextStyle(color: Palette.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (p.status == PresenceStatus.ready)
            FilledButton(
              key: ValueKey('challenge-${p.id}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => sendChallenge(context, p),
              child: Text(l.challenge),
            )
          else
            Text(
              statusLabel(l, p.status),
              style: TextStyle(color: statusColor(p.status), fontWeight: FontWeight.w600, fontSize: 13),
            ),
        ],
      ),
    );
  }
}
