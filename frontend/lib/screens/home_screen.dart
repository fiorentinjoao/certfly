import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/me.dart';
import '../models/progress.dart';
import '../theme.dart';
import 'lesson_screen.dart';

/// GET /me + GET /certification/{id}/progress (RF-02) — trilha de
/// domínios/tópicos com % de domínio e status de desbloqueio.
class HomeScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String certificationId;

  const HomeScreen({super.key, required this.apiClient, required this.certificationId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeData {
  final Me me;
  final List<DomainProgress> domains;
  const _HomeData({required this.me, required this.domains});
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final results = await Future.wait([
      widget.apiClient.getMe(),
      widget.apiClient.getCertificationProgress(widget.certificationId),
    ]);
    return _HomeData(me: results[0] as Me, domains: results[1] as List<DomainProgress>);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CertFly'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ClipOval(
              child: Image.asset('assets/images/mascot_avatar.png', width: 34, height: 34),
            ),
          ),
        ],
      ),
      body: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString(), onRetry: _reload);
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileHeader(me: data.me),
                const SizedBox(height: 20),
                for (final domain in data.domains) _DomainSection(domain: domain, onTopicCompleted: _reload, apiClient: widget.apiClient),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Me me;
  const _ProfileHeader({required this.me});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.purple, Color(0xFF4C1D95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(icon: Icons.bolt_rounded, iconColor: AppColors.green, label: '${me.totalXp} XP'),
          _StatChip(
            icon: Icons.local_fire_department_rounded,
            iconColor: AppColors.amber,
            label: '${me.currentStreak} dias',
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  const _StatChip({required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
        ),
      ],
    );
  }
}

class _DomainSection extends StatelessWidget {
  final DomainProgress domain;
  final VoidCallback onTopicCompleted;
  final ApiClient apiClient;

  const _DomainSection({required this.domain, required this.onTopicCompleted, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            domain.name.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.8,
              color: AppColors.textDim,
            ),
          ),
        ),
        for (final topic in domain.topics)
          _TopicTile(topic: topic, apiClient: apiClient, onTopicCompleted: onTopicCompleted),
      ],
    );
  }
}

class _TopicTile extends StatelessWidget {
  final TopicProgress topic;
  final ApiClient apiClient;
  final VoidCallback onTopicCompleted;

  const _TopicTile({required this.topic, required this.apiClient, required this.onTopicCompleted});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: topic.unlocked
            ? () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LessonScreen(apiClient: apiClient, topicId: topic.id, topicName: topic.name),
                  ),
                );
                onTopicCompleted();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: topic.unlocked ? AppColors.purple.withValues(alpha: 0.2) : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  topic.unlocked ? Icons.auto_stories_rounded : Icons.lock_rounded,
                  color: topic.unlocked ? AppColors.purpleLight : AppColors.textDim,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: topic.unlocked ? AppColors.textPrimary : AppColors.textDim,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: topic.masteryPct,
                        minHeight: 6,
                        backgroundColor: AppColors.line,
                        valueColor: const AlwaysStoppedAnimation(AppColors.purple),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(topic.masteryPct * 100).round()}%',
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/mascot_icon.png', width: 64, height: 64),
            const SizedBox(height: 16),
            const Text('Não consegui falar com o backend.', textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(error, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}
