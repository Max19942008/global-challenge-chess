import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../engine/bot.dart';
import '../l10n/app_localizations.dart';
import '../screens/game_screen.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'online_client.dart';
import 'online_game_screen.dart';

const timeControls = ['3+0', '5+0', '10+0'];

/// Pick a time control, find an opponent. Accepting the bot offer while
/// searching starts a local bot game; declining keeps searching.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String _tc = '5+0';
  bool _searching = false;
  int _elapsedMs = 0;
  StreamSubscription<Map<String, dynamic>>? _sub;
  late OnlineClient _client;
  bool _offerOpen = false;
  Timer? _tick;
  DateTime? _searchStarted;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = OnlineScope.of(context);
    if (_sub == null) {
      _client.start();
      _sub = _client.events.listen(_onEvent);
      final active = _client.activeGame;
      if (active != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openGame(active));
    }
  }

  @override
  void dispose() {
    if (_searching) _client.send('queue:leave');
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _onEvent(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['type']) {
      case 'queue:waiting':
        setState(() => _elapsedMs = (m['elapsedMs'] as num).toInt());
      case 'queue:botOffer':
        _showBotOffer((m['suggestedElo'] as num?)?.toInt() ?? 1500);
      case 'queue:left':
        _stopSearching();
      case 'game:start' || 'game:state':
        _stopSearching();
        if (_offerOpen) Navigator.of(context).pop(); // close the bot offer
        _openGame(m);
    }
  }

  void _openGame(Map<String, dynamic> start) {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnlineGameScreen(start: start)));
  }

  void _find() {
    if (!_client.send('queue:join', {'timeControl': _tc, 'rated': true})) return;
    setState(() {
      _searching = true;
      _elapsedMs = 0;
      _searchStarted = DateTime.now();
    });
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _searchStarted != null) {
        setState(() => _elapsedMs = DateTime.now().difference(_searchStarted!).inMilliseconds);
      }
    });
  }

  void _stopSearching() {
    _tick?.cancel();
    if (mounted) setState(() => _searching = false);
  }

  void _cancel() {
    _client.send('queue:leave');
    _stopSearching();
  }

  Future<void> _showBotOffer(int suggestedElo) async {
    if (_offerOpen || !mounted) return;
    _offerOpen = true;
    final l = AppLocalizations.of(context);
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.bgBottom,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Palette.border),
        ),
        icon: const Icon(Icons.smart_toy_rounded, color: Palette.gold, size: 36),
        title: Text(l.botOfferTitle),
        content: Text(l.botOfferBody, textAlign: TextAlign.center),
        actions: [
          TextButton(key: const ValueKey('bot-decline'), onPressed: () => Navigator.pop(ctx, false), child: Text(l.keepSearching)),
          FilledButton(key: const ValueKey('bot-accept'), onPressed: () => Navigator.pop(ctx, true), child: Text(l.vsBot)),
        ],
      ),
    );
    _offerOpen = false;
    if (!mounted || accept == null) return; // closed because a game started
    if (accept) {
      _client.send('queue:botAccept');
      _stopSearching();
      final level = suggestedElo < 1200
          ? BotLevel.beginner
          : suggestedElo < 1800
              ? BotLevel.intermediate
              : BotLevel.strong;
      final side = Random().nextBool() ? Side.white : Side.black;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(botLevel: level, playerSide: side)));
    } else {
      _client.send('queue:botDecline');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final client = OnlineScope.of(context);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(l.playOnline, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                    _OnlineBadge(count: client.onlineCount, online: client.state == OnlineState.online),
                  ]),
                  const SizedBox(height: 16),
                  if (client.state != OnlineState.online)
                    _connectionCard(l, client)
                  else if (_searching)
                    _searchingCard(l, client)
                  else
                    _pickCard(l, client),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _connectionCard(AppLocalizations l, OnlineClient client) {
    final connecting = client.state == OnlineState.connecting || client.state == OnlineState.idle;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        if (connecting)
          const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: Palette.gold))
        else
          const Icon(Icons.cloud_off_rounded, color: Palette.muted, size: 40),
        const SizedBox(height: 14),
        Text(connecting ? l.connecting : l.serverUnavailable,
            key: const ValueKey('connection-text'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        if (!connecting) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: client.retryNow, child: Text(l.retry)),
        ],
      ]),
    );
  }

  Widget _pickCard(AppLocalizations l, OnlineClient client) {
    final rating = client.user?.ratings[ratingCategory(_tc)];
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.person_rounded, color: Palette.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(client.user?.name ?? '',
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          if (rating != null)
            Text('${l.yourRating}: ${rating.label}',
                key: const ValueKey('my-rating'), style: const TextStyle(color: Palette.muted, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 18),
        Text(l.timeControl.toUpperCase(),
            style: const TextStyle(color: Palette.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < timeControls.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _TcTile(
                key: ValueKey('tc-${timeControls[i]}'),
                label: l.minutes(timeControls[i].split('+').first),
                sub: timeControls[i],
                selected: _tc == timeControls[i],
                onTap: () => setState(() => _tc = timeControls[i]),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('find-opponent'),
          onPressed: _find,
          icon: const Icon(Icons.travel_explore_rounded),
          label: Text(l.findOpponent),
        ),
      ]),
    );
  }

  Widget _searchingCard(AppLocalizations l, OnlineClient client) {
    final s = _elapsedMs ~/ 1000;
    return GlassCard(
      highlight: true,
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        const _Pulse(child: Emblem(size: 84)),
        const SizedBox(height: 22),
        Text(l.searching, key: const ValueKey('searching'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}  ·  $_tc',
            style: const TextStyle(color: Palette.muted, fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 20),
        OutlinedButton(key: const ValueKey('cancel-search'), onPressed: _cancel, child: Text(l.cancel)),
      ]),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.count, required this.online});
  final int count;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Palette.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Palette.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: online ? const Color(0xFF4ADE80) : Palette.muted),
        ),
        const SizedBox(width: 6),
        Text(l.onlineNow(count), key: const ValueKey('online-count'), style: const TextStyle(fontSize: 13)),
      ]),
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
          child: Column(children: [
            Icon(Icons.timer_outlined, color: selected ? Palette.gold : Palette.muted),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(label,
                  style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Palette.gold : Palette.text)),
            ),
            Text(sub, style: const TextStyle(color: Palette.muted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

/// Gentle breathing animation while searching.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.92, end: 1.06).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}
