/// Espelha MeResponse em backend/app/routers/schemas.py — GET /me.
class Me {
  final String id;
  final String email;
  final int totalXp;
  final int currentStreak;
  final int longestStreak;

  const Me({
    required this.id,
    required this.email,
    required this.totalXp,
    required this.currentStreak,
    required this.longestStreak,
  });

  factory Me.fromJson(Map<String, dynamic> json) {
    return Me(
      id: json['id'] as String,
      email: json['email'] as String,
      totalXp: json['total_xp'] as int,
      currentStreak: json['current_streak'] as int,
      longestStreak: json['longest_streak'] as int,
    );
  }
}
