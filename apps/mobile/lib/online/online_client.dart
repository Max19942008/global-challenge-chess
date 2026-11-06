import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Game server address. Release builds pass the real one:
///   flutter build appbundle --dart-define=SERVER_URL=wss://your.server
const serverUrl = String.fromEnvironment('SERVER_URL', defaultValue: 'ws://localhost:8080');

/// One open connection. Lets tests replace the WebSocket with a fake.
abstract interface class OnlineTransport {
  Stream<String> get incoming;
  void send(String data);
  Future<void> close();
}

typedef Connector = Future<OnlineTransport> Function(Uri url);

Future<OnlineTransport> connectWebSocket(Uri url) async {
  final ch = WebSocketChannel.connect(url);
  await ch.ready.timeout(const Duration(seconds: 8));
  return _WsTransport(ch);
}

class _WsTransport implements OnlineTransport {
  _WsTransport(this._ch);
  final WebSocketChannel _ch;

  @override
  Stream<String> get incoming => _ch.stream.map((d) => d is String ? d : utf8.decode(d as List<int>));

  @override
  void send(String data) => _ch.sink.add(data);

  @override
  Future<void> close() => _ch.sink.close();
}

enum OnlineState { idle, connecting, online, offline }

class RatingInfo {
  const RatingInfo(this.rating, this.provisional);
  final int rating;
  final bool provisional;
  String get label => provisional ? '$rating?' : '$rating';
}

class OnlineUser {
  OnlineUser(this.id, this.name, this.ratings);
  final String id;
  final String name;
  final Map<String, RatingInfo> ratings;

  static OnlineUser fromJson(Map<String, dynamic> j) {
    final r = <String, RatingInfo>{};
    (j['ratings'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      r[k] = RatingInfo((m['rating'] as num).round(), m['provisional'] == true);
    });
    return OnlineUser(j['id'] as String, j['name'] as String, r);
  }
}

/// "3+0" → blitz etc. Mirrors the server.
String ratingCategory(String timeControl) {
  final minutes = double.tryParse(timeControl.split('+').first) ?? 5;
  if (minutes < 3) return 'bullet';
  if (minutes < 8) return 'blitz';
  return 'rapid';
}

/// The single connection to the game server: guest login, reconnects,
/// clock offset. Screens listen to [events] for queue/game messages.
class OnlineClient extends ChangeNotifier {
  OnlineClient({
    required this.prefs,
    Uri? url,
    Connector? connector,
    this.enabled = true,
  })  : url = url ?? Uri.parse(serverUrl),
        _connector = connector ?? connectWebSocket;

  static const _tokenKey = 'online_token';

  final SharedPreferences prefs;
  final Uri url;
  final Connector _connector;

  /// false in widget tests that never touch the network.
  final bool enabled;

  OnlineState state = OnlineState.idle;
  OnlineUser? user;
  int onlineCount = 0;

  /// Last game:start / game:state until game:end: lets screens resume a game.
  Map<String, dynamic>? activeGame;

  int _offsetMs = 0;
  final _samples = <({int rtt, int offset})>[];
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  OnlineTransport? _transport;
  StreamSubscription<String>? _sub;
  Timer? _retry;
  int _attempt = 0;
  bool _wanted = false;
  bool _authed = false;

  Stream<Map<String, dynamic>> get events => _events.stream;

  /// Server clock estimate: what the server's Date.now() is right now.
  int serverNow() => DateTime.now().millisecondsSinceEpoch + _offsetMs;

  void start() {
    if (!enabled) {
      state = OnlineState.offline;
      return;
    }
    if (_wanted) return;
    _wanted = true;
    // Screens call this from didChangeDependencies; notify after the build, not during it.
    if (state == OnlineState.idle || state == OnlineState.offline) scheduleMicrotask(_open);
  }

  /// Retry right away (the user pressed "Retry").
  void retryNow() {
    _retry?.cancel();
    _attempt = 0;
    if (state != OnlineState.connecting && state != OnlineState.online) _open();
  }

  /// Sends an intent. Returns false when not connected.
  bool send(String type, [Map<String, Object?> payload = const {}]) {
    if (state != OnlineState.online) return false;
    _raw(type, payload);
    return true;
  }

  void _raw(String type, Map<String, Object?> payload) {
    _transport?.send(jsonEncode({'v': 1, 'type': type, ...payload}));
  }

  Future<void> _open() async {
    state = OnlineState.connecting;
    _authed = false;
    notifyListeners();
    try {
      final t = await _connector(url);
      if (!_wanted) {
        await t.close();
        return;
      }
      _transport = t;
      _sub = t.incoming.listen(_onData, onDone: _onClosed, onError: (_) => _onClosed());
      final token = prefs.getString(_tokenKey);
      token != null ? _raw('auth', {'token': token}) : _raw('auth:guest', {});
    } catch (_) {
      _onClosed();
    }
  }

  void _onData(String data) {
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (m['type']) {
      case 'auth:ok':
        prefs.setString(_tokenKey, m['token'] as String);
        user = OnlineUser.fromJson(m['user'] as Map<String, dynamic>);
        state = OnlineState.online;
        _authed = true;
        _attempt = 0;
        _samples.clear();
        _raw('ping', {'t': DateTime.now().millisecondsSinceEpoch});
        notifyListeners();
      case 'pong':
        _onPong(m);
      case 'lobby:stats':
        onlineCount = (m['onlineCount'] as num).toInt();
        notifyListeners();
      case 'queue:waiting':
        onlineCount = (m['onlineCount'] as num).toInt();
        _events.add(m);
        notifyListeners();
      case 'game:start' || 'game:state':
        activeGame = m;
        _events.add(m);
        notifyListeners();
      case 'game:end':
        _applyRatingChange(m); // needs activeGame's time control
        activeGame = null;
        _events.add(m);
        notifyListeners();
      case 'error' when !_authed:
        // A token from another server/secret: start over as a new guest.
        prefs.remove(_tokenKey);
        _raw('auth:guest', {});
      default:
        _events.add(m);
    }
  }

  void _onPong(Map<String, dynamic> m) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sent = (m['t'] as num).toInt();
    final server = (m['serverTime'] as num).toInt();
    _samples.add((rtt: now - sent, offset: server - (sent + now) ~/ 2));
    // Five samples; the fastest round trip gives the most accurate offset.
    if (_samples.length < 5) {
      _raw('ping', {'t': DateTime.now().millisecondsSinceEpoch});
    }
    _offsetMs = _samples.reduce((a, b) => a.rtt <= b.rtt ? a : b).offset;
  }

  void _applyRatingChange(Map<String, dynamic> end) {
    final change = end['ratingChange'] as Map<String, dynamic>?;
    final tc = end['timeControl'] as String? ?? (activeGame?['timeControl'] as String?);
    final u = user;
    if (change == null || u == null || tc == null) return;
    final cat = ratingCategory(tc);
    u.ratings[cat] = RatingInfo((change['after'] as num).round(), u.ratings[cat]?.provisional ?? true);
  }

  void _onClosed() {
    _sub?.cancel();
    _sub = null;
    _transport = null;
    _authed = false;
    if (state == OnlineState.idle) return;
    state = OnlineState.offline;
    notifyListeners();
    if (_wanted) {
      _retry?.cancel();
      final delay = Duration(milliseconds: min(10000, 1000 * (1 << min(_attempt, 4))));
      _attempt++;
      _retry = Timer(delay, _open);
    }
  }

  @override
  void dispose() {
    _wanted = false;
    _retry?.cancel();
    _sub?.cancel();
    _transport?.close();
    _events.close();
    super.dispose();
  }
}

/// Makes the [OnlineClient] reachable from any screen.
class OnlineScope extends InheritedNotifier<OnlineClient> {
  const OnlineScope({super.key, required OnlineClient client, required super.child}) : super(notifier: client);

  static OnlineClient of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnlineScope>()!.notifier!;
}
