class RateLog {
  const RateLog({
    required this.username,
    required this.score,
    this.uid,
    this.ratedAt,
    this.reason = '',
  });

  final String? uid;
  final String username;
  final int score;
  final DateTime? ratedAt;
  final String reason;

  bool get isPositive => score > 0;
}

class PostRateLog {
  const PostRateLog({
    required this.pid,
    required this.entries,
    required this.totalScore,
    required this.participantCount,
  });

  final String pid;
  final List<RateLog> entries;
  final int totalScore;
  final int participantCount;

  bool get isEmpty => entries.isEmpty;
}
