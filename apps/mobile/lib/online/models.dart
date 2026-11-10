/// Data the game server sends, parsed from JSON. Mirrors the types in
/// packages/chess-core/src/events.ts.
library;

/// "3+0" → blitz etc. Mirrors the server.
String ratingCategory(String timeControl) {
  final minutes = double.tryParse(timeControl.split('+').first) ?? 5;
  if (minutes < 3) return 'bullet';
  if (minutes < 8) return 'blitz';
  return 'rapid';
}

const ratingCategories = ['blitz', 'rapid', 'bullet'];

class RatingInfo {
  const RatingInfo(this.rating, this.provisional);
  final int rating;
  final bool provisional;
  String get label => provisional ? '$rating?' : '$rating';

  static Map<String, RatingInfo> mapFromJson(Object? json) {
    final r = <String, RatingInfo>{};
    (json as Map<String, dynamic>? ?? {}).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      r[k] = RatingInfo((m['rating'] as num).round(), m['provisional'] == true);
    });
    return r;
  }
}

/// Finished online games (aborted ones don't count).
class GameStats {
  const GameStats(this.wins, this.losses, this.draws);
  final int wins;
  final int losses;
  final int draws;
  int get games => wins + losses + draws;

  static GameStats fromJson(Map<String, dynamic>? j) => GameStats(
    (j?['wins'] as num?)?.toInt() ?? 0,
    (j?['losses'] as num?)?.toInt() ?? 0,
    (j?['draws'] as num?)?.toInt() ?? 0,
  );
}

/// The signed-in player.
class OnlineUser {
  OnlineUser(this.id, this.name, this.ratings, {this.avatar, this.stats = const GameStats(0, 0, 0)});
  final String id;
  final String name;
  final Map<String, RatingInfo> ratings;

  /// Server path (`/avatar/<id>?v=2`); null = no photo. See OnlineClient.avatarUrl.
  final String? avatar;
  final GameStats stats;

  static OnlineUser fromJson(Map<String, dynamic> j) => OnlineUser(
    j['id'] as String,
    j['name'] as String,
    RatingInfo.mapFromJson(j['ratings']),
    avatar: j['avatar'] as String?,
    stats: GameStats.fromJson(j['stats'] as Map<String, dynamic>?),
  );
}

enum PresenceStatus {
  /// In the app, not taking challenges.
  watching,

  /// Others may challenge them.
  ready,

  /// Has an online game in progress.
  playing;

  static PresenceStatus parse(Object? s) =>
      PresenceStatus.values.firstWhere((v) => v.name == s, orElse: () => PresenceStatus.watching);
}

/// Someone online, as the lobby list shows them.
class LobbyPlayer {
  const LobbyPlayer({
    required this.id,
    required this.name,
    required this.avatar,
    required this.status,
    required this.ratings,
    required this.stats,
  });

  final String id;
  final String name;
  final String? avatar;
  final PresenceStatus status;
  final Map<String, RatingInfo> ratings;
  final GameStats stats;

  static LobbyPlayer fromJson(Map<String, dynamic> j) => LobbyPlayer(
    id: j['id'] as String,
    name: j['name'] as String,
    avatar: j['avatar'] as String?,
    status: PresenceStatus.parse(j['status']),
    ratings: RatingInfo.mapFromJson(j['ratings']),
    stats: GameStats.fromJson(j),
  );
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.id,
    required this.name,
    required this.avatar,
    required this.rating,
    required this.stats,
    required this.games,
  });

  final int rank;
  final String id;
  final String name;
  final String? avatar;
  final RatingInfo rating;
  final GameStats stats;

  /// Rated games in the category.
  final int games;

  static LeaderboardEntry fromJson(Map<String, dynamic> j) => LeaderboardEntry(
    rank: (j['rank'] as num).toInt(),
    id: j['id'] as String,
    name: j['name'] as String,
    avatar: j['avatar'] as String?,
    rating: RatingInfo((j['rating'] as num).round(), j['provisional'] == true),
    stats: GameStats.fromJson(j),
    games: (j['games'] as num?)?.toInt() ?? 0,
  );
}

enum LeaderboardSort { rating, wins }

class Leaderboard {
  const Leaderboard(this.category, this.sort, this.players, this.me);
  final String category;
  final LeaderboardSort sort;
  final List<LeaderboardEntry> players;

  /// The signed-in player's own row; null until they've finished a game.
  final LeaderboardEntry? me;

  static Leaderboard fromJson(Map<String, dynamic> j) => Leaderboard(
    j['category'] as String,
    j['sort'] == 'wins' ? LeaderboardSort.wins : LeaderboardSort.rating,
    [for (final p in j['players'] as List) LeaderboardEntry.fromJson(p as Map<String, dynamic>)],
    j['me'] == null ? null : LeaderboardEntry.fromJson(j['me'] as Map<String, dynamic>),
  );
}

/// The other side of a challenge, from challenge:sent / challenge:incoming.
class ChallengePlayer {
  const ChallengePlayer(this.id, this.name, this.avatar, this.rating);
  final String id;
  final String name;
  final String? avatar;
  final RatingInfo? rating;

  static ChallengePlayer fromJson(Map<String, dynamic> j) => ChallengePlayer(
    j['id'] as String,
    j['name'] as String,
    j['avatar'] as String?,
    j['rating'] == null ? null : RatingInfo((j['rating'] as num).round(), j['provisional'] == true),
  );
}

class Challenge {
  const Challenge({
    required this.id,
    required this.other,
    required this.timeControl,
    required this.rated,
    required this.expiresInMs,
    required this.incoming,
  });

  final String id;

  /// The challenger for an incoming challenge, the challenged player for an outgoing one.
  final ChallengePlayer other;
  final String timeControl;
  final bool rated;
  final int expiresInMs;
  final bool incoming;

  static Challenge fromJson(Map<String, dynamic> j) {
    final incoming = j['type'] == 'challenge:incoming';
    return Challenge(
      id: j['challengeId'] as String,
      other: ChallengePlayer.fromJson((incoming ? j['from'] : j['to']) as Map<String, dynamic>),
      timeControl: j['timeControl'] as String,
      rated: j['rated'] != false,
      expiresInMs: (j['expiresInMs'] as num?)?.toInt() ?? 60000,
      incoming: incoming,
    );
  }
}

/// Why a challenge closed (challenge:closed). "accepted" is followed by game:start.
enum ChallengeClosedReason { accepted, declined, cancelled, expired, unavailable }

ChallengeClosedReason parseClosedReason(Object? s) =>
    ChallengeClosedReason.values.firstWhere((v) => v.name == s, orElse: () => ChallengeClosedReason.unavailable);
