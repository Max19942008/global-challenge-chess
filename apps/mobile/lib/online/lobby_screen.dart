import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/profile_screen.dart';
import '../ui/avatar.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'leaderboard_tab.dart';
import 'online_client.dart';
import 'players_tab.dart';
import 'quick_match_tab.dart';

/// Online play: who's here (and challenge them), a quick random match, the leaderboard.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key, this.initialTab = 0});

  /// 0 players, 1 quick match, 2 leaderboard.
  final int initialTab;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  OnlineClient? _client;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_client == null) {
      _client = OnlineScope.of(context)..start();
      _client!.subscribeLobby();
    }
  }

  @override
  void dispose() {
    _client?.unsubscribeLobby();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final client = OnlineScope.of(context);
    final online = client.state == OnlineState.online;
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l.playOnline,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                          ),
                          OnlineBadge(count: client.onlineCount, online: online),
                          const SizedBox(width: 8),
                          if (client.user != null)
                            InkWell(
                              key: const ValueKey('open-profile'),
                              customBorder: const CircleBorder(),
                              onTap: () =>
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                              child: Avatar(
                                name: client.user!.name,
                                url: client.avatarUrl(client.user!.avatar),
                                size: 36,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!online)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: ConnectionCard(client: client),
                      )
                    else ...[
                      TabBar(
                        indicatorColor: Palette.gold,
                        labelColor: Palette.gold,
                        unselectedLabelColor: Palette.muted,
                        dividerColor: Palette.border,
                        tabs: [
                          Tab(key: const ValueKey('tab-players'), text: l.tabPlayers),
                          Tab(key: const ValueKey('tab-quick'), text: l.tabQuickMatch),
                          Tab(key: const ValueKey('tab-leaderboard'), text: l.tabLeaderboard),
                        ],
                      ),
                      const Expanded(child: TabBarView(children: [PlayersTab(), QuickMatchTab(), LeaderboardTab()])),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Spinner while connecting; "server unavailable" with Retry after that.
class ConnectionCard extends StatelessWidget {
  const ConnectionCard({super.key, required this.client});
  final OnlineClient client;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final connecting = client.state == OnlineState.connecting || client.state == OnlineState.idle;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (connecting)
            const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: Palette.gold))
          else
            const Icon(Icons.cloud_off_rounded, color: Palette.muted, size: 40),
          const SizedBox(height: 14),
          Text(
            connecting ? l.connecting : l.serverUnavailable,
            key: const ValueKey('connection-text'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          if (!connecting) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: client.retryNow, child: Text(l.retry)),
          ],
        ],
      ),
    );
  }
}

/// Green dot + "N online now".
class OnlineBadge extends StatelessWidget {
  const OnlineBadge({super.key, required this.count, required this.online});
  final int count;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: online ? const Color(0xFF4ADE80) : Palette.muted),
          ),
          const SizedBox(width: 6),
          Text(l.onlineNow(count), key: const ValueKey('online-count'), style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
