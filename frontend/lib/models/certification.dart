/// Espelha CertificationOverviewResponse em backend/app/routers/schemas.py
/// — GET /certifications.
class CertificationOverview {
  final String id;
  final String name;
  final String slug;
  final String providerName;
  final String providerSlug;
  final double overallMasteryPct;

  const CertificationOverview({
    required this.id,
    required this.name,
    required this.slug,
    required this.providerName,
    required this.providerSlug,
    required this.overallMasteryPct,
  });

  factory CertificationOverview.fromJson(Map<String, dynamic> json) {
    return CertificationOverview(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      providerName: json['provider_name'] as String,
      providerSlug: json['provider_slug'] as String,
      overallMasteryPct: (json['overall_mastery_pct'] as num).toDouble(),
    );
  }
}
