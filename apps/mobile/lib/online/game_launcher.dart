import 'dart:async';

import 'package:flutter/material.dart';

import 'challenge_dialogs.dart';
import 'online_client.dart';
import 'online_game_screen.dart';

/// Sits above the navigator (MaterialApp.builder) and reacts to the server
/// wherever the player is in the app:
/// - game:start / unasked game:state → open the online game (queue, challenge or resume);
/// - challenge:incoming → the accept/decline dialog.
class GameLauncher extends StatefulWidget {
  const GameLauncher({super.key, required this.navigatorKey, required this.child});
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<GameLauncher> createState() => _GameLauncherState();
}

class _GameLauncherState extends State<GameLauncher> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  String? _openGameId;
  final _openChallenges = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= OnlineScope.of(context).events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  NavigatorState? get _nav => widget.navigatorKey.currentState;

  void _onEvent(Map<String, dynamic> m) {
    switch (m['type']) {
      case 'game:start' || 'game:state':
        _openGame(m);
      case 'challenge:incoming':
        _showIncoming(Challenge.fromJson(m));
    }
  }

  void _openGame(Map<String, dynamic> m) {
    final id = m['gameId'] as String?;
    final nav = _nav;
    if (id == null || nav == null || id == _openGameId) return; // that screen handles it itself
    // Close the bot offer, challenge dialogs, sheets.
    nav.popUntil((r) => r is! PopupRoute);
    _openGameId = id;
    nav.push(MaterialPageRoute(builder: (_) => OnlineGameScreen(start: m))).whenComplete(() {
      if (_openGameId == id) _openGameId = null;
    });
  }

  Future<void> _showIncoming(Challenge c) async {
    final nav = _nav;
    if (nav == null || _openGameId != null || !_openChallenges.add(c.id)) return;
    await showDialog<void>(
      context: nav.context,
      barrierDismissible: false,
      builder: (_) => IncomingChallengeDialog(challenge: c),
    );
    _openChallenges.remove(c.id);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
