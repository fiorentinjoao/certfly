import 'package:flutter/material.dart';

import '../models/lesson_summary.dart';
import '../theme.dart';

/// Resumo ao fim da lição (RF-11) — XP ganho, streak, mudança no % de
/// domínio e se o tópico foi desbloqueado (RF-09).
class LessonSummaryScreen extends StatelessWidget {
  final LessonSummary summary;
  const LessonSummaryScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('Lição concluída!', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SummaryStat(icon: Icons.bolt, value: '+${summary.xpEarned}', label: 'XP'),
                    _SummaryStat(
                      icon: Icons.local_fire_department,
                      value: '${summary.currentStreak}',
                      label: 'dias seguidos',
                    ),
                    _SummaryStat(
                      icon: Icons.insights,
                      value: '${(summary.masteryPct * 100).round()}%',
                      label: 'domínio',
                    ),
                  ],
                ),
                if (summary.topicUnlocked) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.correct.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_open, color: AppTheme.correct),
                        const SizedBox(width: 8),
                        const Text(
                          'Próximo tópico desbloqueado!',
                          style: TextStyle(color: AppTheme.correct, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Voltar para o início'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _SummaryStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
