import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../ui/avatar.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'online_client.dart';

String categoryLabel(AppLocalizations l, String cat) => switch (cat) {
  'rapid' => l.categoryRapid,
  'bullet' => l.categoryBullet,
  _ => l.categoryBlitz,
};

/// Top 50 by rating (strongest first) or by wins, per category, plus my own place.
class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key});

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> with AutomaticKeepAliveClientMixin {
  late OnlineClient _client;
  StreamSubscription<Map<String, dynamic>>? _sub;
  String _category = 'blitz';
  LeaderboardSort _sort = LeaderboardSort.rating;
  Leaderboard? _board;
  Completer<void>? _refreshing;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = OnlineScope.of(context);
    if (_sub == null) {
      _sub = _client.events.listen(_onEvent);
      _request();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(Map<String, dynamic> m) {
    if (m['type'] != 'leaderboard' || !mounted) return;
    final board = Leaderboard.fromJson(m);
    if (board.category != _category || board.sort != _sort) return; // an older request
    setState(() => _board = board);
    _refreshing?.complete();
    _refreshing = null;
  }

  void _request() => _client.requestLeaderboard(category: _category, sort: _sort);

  Future<void> _refresh() {
    _refreshing ??= Completer<void>();
    _request();
    return _refreshing!.future.timeout(const Duration(seconds: 8), onTimeout: () => _refreshing = null);
  }

  void _change({String? category, LeaderboardSort? sort}) {
    setState(() {
      _category = category ?? _category;
      _sort = sort ?? _sort;
      _board = null;
    });
    _request();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    final board = _board;
    return RefreshIndicator(
      onRefresh: _refresh,
      color: Palette.gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in const ['blitz', 'rapid'])
                ChoiceChip(
                  key: ValueKey('lb-$cat'),
                  label: Text(categoryLabel(l, cat)),
                  selected: _category == cat,
                  onSelected: (_) => _change(category: cat),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<LeaderboardSort>(
            segments: [
              ButtonSegment(
                value: LeaderboardSort.rating,
                icon: const Icon(Icons.star_rounded),
                label: Text(l.sortByRating),
              ),
              ButtonSegment(
                value: LeaderboardSort.wins,
                icon: const Icon(Icons.emoji_events_rounded),
                label: Text(l.sortByWins),
              ),
            ],
            selected: {_sort},
            onSelectionChanged: (s) => _change(sort: s.first),
          ),
          const SizedBox(height: 10),
          Text(l.ratingExplained, style: const TextStyle(color: Palette.muted, fontSize: 13)),
          const SizedBox(height: 14),
          if (board == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: Palette.gold)),
            )
          else ...[
            if (board.me != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Text(
                  l.yourPlace(board.me!.rank),
                  style: const TextStyle(color: Palette.muted, fontWeight: FontWeight.w700),
                ),
              ),
              _Row(entry: board.me!, sort: _sort, mine: true),
              const SizedBox(height: 14),
            ],
            if (board.players.isEmpty)
              GlassCard(child: Text(l.leaderboardEmpty, key: const ValueKey('leaderboard-empty')))
            else
              for (final e in board.players)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Row(entry: e, sort: _sort, mine: e.id == _client.user?.id),
                ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.sort, required this.mine});
  final LeaderboardEntry entry;
  final LeaderboardSort sort;
  final bool mine;

  static const _medals = [Color(0xFFF2C14E), Color(0xFFC9D1E0), Color(0xFFCD8B4E)];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final client = OnlineScope.of(context);
    final e = entry;
    final medal = e.rank <= 3 ? _medals[e.rank - 1] : null;
    final main = sort == LeaderboardSort.rating ? e.rating.label : '${e.stats.wins}';
    return Container(
      key: ValueKey('lb-row-${e.id}${mine ? '-me' : ''}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? Palette.gold.withValues(alpha: 0.10) : Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine ? Palette.gold.withValues(alpha: 0.7) : Palette.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: medal != null
                ? Icon(Icons.emoji_events_rounded, color: medal, size: 26)
                : Text(
                    '${e.rank}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Palette.muted, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
          ),
          const SizedBox(width: 6),
          Avatar(name: e.name, url: client.avatarUrl(e.avatar), size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mine ? '${e.name} (${l.you})' : e.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  l.statsLine(e.stats.wins, e.stats.losses, e.stats.draws),
                  style: const TextStyle(color: Palette.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                main,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Palette.gold),
              ),
              Text(
                sort == LeaderboardSort.rating ? l.tabLeaderboard : l.wins,
                style: const TextStyle(color: Palette.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
