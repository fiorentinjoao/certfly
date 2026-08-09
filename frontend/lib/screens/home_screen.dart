import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/me.dart';
import '../models/progress.dart';
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
      appBar: AppBar(title: const Text('CertFly')),
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
                const SizedBox(height: 16),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatChip(icon: Icons.bolt, label: '${me.totalXp} XP'),
            _StatChip(icon: Icons.local_fire_department, label: '${me.currentStreak} dias'),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
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
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(domain.name, style: Theme.of(context).textTheme.titleMedium),
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
      child: ListTile(
        enabled: topic.unlocked,
        leading: Icon(topic.unlocked ? Icons.school_outlined : Icons.lock_outline),
        title: Text(topic.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: topic.masteryPct, minHeight: 6),
          ),
        ),
        trailing: Text('${(topic.masteryPct * 100).round()}%'),
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
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
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
