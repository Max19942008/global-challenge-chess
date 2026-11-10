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
import 'time_control_picker.dart';

/// Random opponent by rating. Accepting the bot offer while searching starts a
/// local bot game; declining keeps searching. The game itself is opened by GameLauncher.
class QuickMatchTab extends StatefulWidget {
  const QuickMatchTab({super.key});

  @override
  State<QuickMatchTab> createState() => _QuickMatchTabState();
}

class _QuickMatchTabState extends State<QuickMatchTab> with AutomaticKeepAliveClientMixin {
  String _tc = '5+0';
  bool _searching = false;
  int _elapsedMs = 0;
  StreamSubscription<Map<String, dynamic>>? _sub;
  late OnlineClient _client;
  bool _offerOpen = false;
  Timer? _tick;
  DateTime? _searchStarted;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _client = OnlineScope.of(context);
    _sub ??= _client.events.listen(_onEvent);
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
      case 'queue:left' || 'game:start' || 'game:state':
        _stopSearching();
    }
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
          TextButton(
            key: const ValueKey('bot-decline'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.keepSearching),
          ),
          FilledButton(
            key: const ValueKey('bot-accept'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.vsBot),
          ),
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(botLevel: level, playerSide: side),
        ),
      );
    } else {
      _client.send('queue:botDecline');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    final client = OnlineScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [if (_searching) _searchingCard(l) else _pickCard(l, client)],
    );
  }

  Widget _pickCard(AppLocalizations l, OnlineClient client) {
    final rating = client.user?.ratings[ratingCategory(_tc)];
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rating != null)
            Text(
              '${l.yourRating}: ${rating.label}',
              key: const ValueKey('my-rating'),
              style: const TextStyle(color: Palette.muted, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 14),
          SectionLabel(l.timeControl),
          const SizedBox(height: 8),
          TimeControlPicker(value: _tc, onChanged: (tc) => setState(() => _tc = tc)),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('find-opponent'),
            onPressed: _find,
            icon: const Icon(Icons.travel_explore_rounded),
            label: Text(l.findOpponent),
          ),
        ],
      ),
    );
  }

  Widget _searchingCard(AppLocalizations l) {
    final s = _elapsedMs ~/ 1000;
    return GlassCard(
      highlight: true,
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const _Pulse(child: Emblem(size: 84)),
          const SizedBox(height: 22),
          Text(
            l.searching,
            key: const ValueKey('searching'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}  ·  $_tc',
            style: const TextStyle(color: Palette.muted, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 20),
          OutlinedButton(key: const ValueKey('cancel-search'), onPressed: _cancel, child: Text(l.cancel)),
        ],
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

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
