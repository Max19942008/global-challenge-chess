import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../ui/avatar.dart';
import '../ui/theme.dart';
import 'online_client.dart';
import 'time_control_picker.dart';

RoundedRectangleBorder _dialogShape() => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(20),
  side: const BorderSide(color: Palette.border),
);

/// Pick a time control, send the challenge, wait for the answer.
/// If it's accepted, GameLauncher closes the dialog and opens the game.
Future<void> sendChallenge(BuildContext context, LobbyPlayer to) async {
  final client = OnlineScope.of(context);
  final setup = await showModalBottomSheet<({String tc, bool rated})>(
    context: context,
    backgroundColor: Palette.bgBottom,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ChallengeSetup(to: to),
  );
  if (setup == null || !context.mounted) return;
  // Listen before sending: the answer may arrive before the dialog's first frame.
  final outgoing = _Outgoing(client);
  if (!client.send('challenge:send', {'to': to.id, 'timeControl': setup.tc, 'rated': setup.rated})) {
    outgoing.dispose();
    return;
  }
  final ChallengeClosedReason? reason;
  try {
    reason = await showDialog<ChallengeClosedReason>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OutgoingDialog(to: to, outgoing: outgoing),
    );
  } finally {
    outgoing.dispose();
  }
  if (!context.mounted || reason == null || reason == ChallengeClosedReason.accepted) return;
  final l = AppLocalizations.of(context);
  final text = switch (reason) {
    ChallengeClosedReason.declined => l.challengeDeclined(to.name),
    ChallengeClosedReason.expired => l.challengeExpired,
    ChallengeClosedReason.unavailable => l.challengeUnavailable,
    _ => null, // cancelled by me: nothing to say
  };
  if (text != null) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
}

class _ChallengeSetup extends StatefulWidget {
  const _ChallengeSetup({required this.to});
  final LobbyPlayer to;

  @override
  State<_ChallengeSetup> createState() => _ChallengeSetupState();
}

class _ChallengeSetupState extends State<_ChallengeSetup> {
  String _tc = '5+0';
  bool _rated = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final client = OnlineScope.of(context);
    final p = widget.to;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Avatar(name: p.name, url: client.avatarUrl(p.avatar), size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.challengeTitle(p.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${ratingLabel(p.ratings, _tc)}  ·  ${l.statsLine(p.stats.wins, p.stats.losses, p.stats.draws)}',
                        style: const TextStyle(color: Palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SectionLabel(l.timeControl),
            const SizedBox(height: 8),
            TimeControlPicker(value: _tc, onChanged: (tc) => setState(() => _tc = tc)),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(l.rated), icon: const Icon(Icons.emoji_events_outlined)),
                ButtonSegment(value: false, label: Text(l.casual), icon: const Icon(Icons.handshake_outlined)),
              ],
              selected: {_rated},
              onSelectionChanged: (s) => setState(() => _rated = s.first),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('send-challenge'),
              onPressed: () => Navigator.pop(context, (tc: _tc, rated: _rated)),
              icon: const Icon(Icons.sports_esports_rounded),
              label: Text(l.challengeSend),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tracks one sent challenge from the moment it is sent: its id, and why it closed.
class _Outgoing {
  _Outgoing(this.client) {
    _sub = client.events.listen((m) {
      switch (m['type']) {
        case 'challenge:sent' when id == null:
          id = m['challengeId'] as String;
        case 'challenge:closed' when m['challengeId'] == id:
          closed.value ??= parseClosedReason(m['reason']);
        case 'error' when id == null:
          closed.value ??= ChallengeClosedReason.unavailable;
      }
    });
  }

  final OnlineClient client;
  late final StreamSubscription<Map<String, dynamic>> _sub;
  String? id;
  final closed = ValueNotifier<ChallengeClosedReason?>(null);

  void cancel() {
    final id = this.id;
    if (id != null) client.send('challenge:cancel', {'challengeId': id});
    closed.value ??= ChallengeClosedReason.cancelled;
  }

  void dispose() {
    _sub.cancel();
    closed.dispose();
  }
}

/// "Waiting for X…" with a cancel button; pops with the reason the challenge closed.
class _OutgoingDialog extends StatefulWidget {
  const _OutgoingDialog({required this.to, required this.outgoing});
  final LobbyPlayer to;
  final _Outgoing outgoing;

  @override
  State<_OutgoingDialog> createState() => _OutgoingDialogState();
}

class _OutgoingDialogState extends State<_OutgoingDialog> {
  @override
  void initState() {
    super.initState();
    widget.outgoing.closed.addListener(_onClosed);
    // Already answered before the dialog was built.
    if (widget.outgoing.closed.value != null) WidgetsBinding.instance.addPostFrameCallback((_) => _onClosed());
  }

  void _onClosed() {
    final reason = widget.outgoing.closed.value;
    if (reason == null || !mounted) return;
    widget.outgoing.closed.removeListener(_onClosed);
    Navigator.of(context).pop(reason);
  }

  @override
  void dispose() {
    widget.outgoing.closed.removeListener(_onClosed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final client = OnlineScope.of(context);
    return AlertDialog(
      backgroundColor: Palette.bgBottom,
      shape: _dialogShape(),
      icon: Avatar(name: widget.to.name, url: client.avatarUrl(widget.to.avatar), size: 64),
      title: Text(l.challengeWaiting(widget.to.name), textAlign: TextAlign.center),
      content: const SizedBox(height: 4, child: LinearProgressIndicator(color: Palette.gold)),
      actions: [
        TextButton(key: const ValueKey('cancel-challenge'), onPressed: widget.outgoing.cancel, child: Text(l.cancel)),
      ],
    );
  }
}

/// Shown by GameLauncher wherever the player is. Closes itself if the challenger withdraws.
class IncomingChallengeDialog extends StatefulWidget {
  const IncomingChallengeDialog({super.key, required this.challenge});
  final Challenge challenge;

  @override
  State<IncomingChallengeDialog> createState() => _IncomingChallengeDialogState();
}

class _IncomingChallengeDialogState extends State<IncomingChallengeDialog> {
  late final OnlineClient _client = OnlineScope.of(context);
  StreamSubscription<Map<String, dynamic>>? _sub;
  late final DateTime _until = DateTime.now().add(Duration(milliseconds: widget.challenge.expiresInMs));
  Timer? _tick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= _client.events.listen((m) {
      if (m['type'] == 'challenge:closed' && m['challengeId'] == widget.challenge.id && mounted) {
        Navigator.of(context).pop();
      }
    });
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (DateTime.now().isAfter(_until)) {
        Navigator.of(context).pop();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _answer(bool accept) {
    _client.send('challenge:respond', {'challengeId': widget.challenge.id, 'accept': accept});
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.challenge;
    final left = _until.difference(DateTime.now()).inSeconds.clamp(0, 999);
    return AlertDialog(
      backgroundColor: Palette.bgBottom,
      shape: _dialogShape(),
      icon: Avatar(name: c.other.name, url: _client.avatarUrl(c.other.avatar), size: 72),
      title: Text(l.challengeIncoming(c.other.name), textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.other.rating != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Palette.gold, size: 18),
                const SizedBox(width: 4),
                Text(c.other.rating!.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              Chip(
                avatar: const Icon(Icons.timer_outlined, size: 18),
                label: Text(l.minutes(c.timeControl.split('+').first)),
              ),
              Chip(label: Text(c.rated ? l.rated : l.casual)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$left s',
            style: const TextStyle(color: Palette.muted, fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ],
      ),
      actions: [
        TextButton(key: const ValueKey('decline-challenge'), onPressed: () => _answer(false), child: Text(l.decline)),
        FilledButton(key: const ValueKey('accept-challenge'), onPressed: () => _answer(true), child: Text(l.accept)),
      ],
    );
  }
}

/// "1532" / "1500?" in the category of [timeControl].
String ratingLabel(Map<String, RatingInfo> ratings, String timeControl) =>
    ratings[ratingCategory(timeControl)]?.label ?? '1500?';
