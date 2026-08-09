/// Espelha LessonSummaryResponse em backend/app/routers/schemas.py —
/// POST /lesson-session/{id}/complete (RF-08, RF-09, RF-11).
class LessonSummary {
  final int xpEarned;
  final int currentStreak;
  final double masteryPct;
  final bool topicUnlocked;

  const LessonSummary({
    required this.xpEarned,
    required this.currentStreak,
    required this.masteryPct,
    required this.topicUnlocked,
  });

  factory LessonSummary.fromJson(Map<String, dynamic> json) {
    return LessonSummary(
      xpEarned: json['xp_earned'] as int,
      currentStreak: json['current_streak'] as int,
      masteryPct: (json['mastery_pct'] as num).toDouble(),
      topicUnlocked: json['topic_unlocked'] as bool,
    );
  }
}
