/// Espelha DomainProgressResponse/TopicProgressResponse em
/// backend/app/routers/schemas.py — GET /certification/{id}/progress (RF-02).
class TopicProgress {
  final String id;
  final String name;
  final String slug;
  final double masteryPct;
  final bool unlocked;

  const TopicProgress({
    required this.id,
    required this.name,
    required this.slug,
    required this.masteryPct,
    required this.unlocked,
  });

  factory TopicProgress.fromJson(Map<String, dynamic> json) {
    return TopicProgress(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      masteryPct: (json['mastery_pct'] as num).toDouble(),
      unlocked: json['unlocked'] as bool,
    );
  }
}

class DomainProgress {
  final String id;
  final String name;
  final String slug;
  final List<TopicProgress> topics;

  const DomainProgress({
    required this.id,
    required this.name,
    required this.slug,
    required this.topics,
  });

  factory DomainProgress.fromJson(Map<String, dynamic> json) {
    return DomainProgress(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      topics: (json['topics'] as List)
          .map((t) => TopicProgress.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}
