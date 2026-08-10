import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/me.dart';
import '../models/progress.dart';
import '../theme.dart';
import '../widgets/app_page_route.dart';
import '../widgets/domain_path.dart';
import '../widgets/streak_hero.dart';
import 'lesson_screen.dart';

/// Threshold do gate de desbloqueio (RF-09, core-loop-srs.md) — usado só
/// pra decidir qual nó ganha o destaque de "nó ativo" na trilha (o
/// primeiro tópico desbloqueado ainda não dominado); não duplica a regra
/// de negócio em si — o servidor já decide `unlocked`.
const _gateThreshold = 0.8;

/// GET /me + GET /certification/{id}/progress (RF-02) — trilha de
/// domínios/tópicos em zigue-zague, com anel de mastery real por tópico.
class HomeScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String certificationId;

  /// Null quando a sessão é via token de dev (scripts/seed_dev.py) — sem
  /// sessão real pra encerrar (ver lib/auth/auth_gateway.dart). Repassado
  /// pro MainShell construir a ProfileScreen; HomeScreen em si não usa
  /// mais isso desde que o logout mudou pra aba Perfil.
  final VoidCallback? onLogout;

  const HomeScreen({
    super.key,
    required this.apiClient,
    required this.certificationId,
    this.onLogout,
  });

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

  /// Primeiro tópico desbloqueado ainda não dominado, varrendo todos os
  /// domínios em ordem — esse é o nó que ganha destaque ("Continuar"/
  /// "Começar") na trilha. Sem isso, ficaria ambíguo qual card mostrar
  /// como "próximo passo" quando há vários tópicos desbloqueados.
  String? _activeTopicId(List<DomainProgress> domains) {
    for (final domain in domains) {
      for (final topic in domain.topics) {
        if (topic.unlocked && topic.masteryPct < _gateThreshold) return topic.id;
      }
    }
    // Fallback: tudo dominado ou nada desbloqueado — usa o primeiro
    // desbloqueado que existir, se houver.
    for (final domain in domains) {
      for (final topic in domain.topics) {
        if (topic.unlocked) return topic.id;
      }
    }
    return null;
  }

  void _openTopic(TopicProgress topic) {
    Navigator.of(context)
        .push(
          appPageRoute(
            LessonScreen(apiClient: widget.apiClient, topicId: topic.id, topicName: topic.name),
          ),
        )
        .then((_) => _reload());
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
            return _ErrorState(onRetry: _reload);
          }

          final data = snapshot.data!;
          final activeTopicId = _activeTopicId(data.domains);

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              children: [
                StreakHero(currentStreak: data.me.currentStreak, totalXp: data.me.totalXp),
                const SizedBox(height: 22),
                for (final domain in data.domains) ...[
                  DomainPathSection(
                    domain: domain,
                    activeTopicId: activeTopicId,
                    onTapTopic: _openTopic,
                  ),
                  const SizedBox(height: 22),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 26, color: AppColors.red),
            ),
            const SizedBox(height: 14),
            const Text(
              'Não consegui carregar seus dados',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Verifique sua conexão e tente de novo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textDim),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
