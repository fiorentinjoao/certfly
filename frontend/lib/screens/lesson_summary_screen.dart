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
                Image.asset('assets/images/mascot_hero.png', height: 180),
                const SizedBox(height: 8),
                Text('Lição concluída!', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SummaryStat(icon: Icons.bolt_rounded, color: AppColors.green, value: '+${summary.xpEarned}', label: 'XP'),
                    _SummaryStat(
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.amber,
                      value: '${summary.currentStreak}',
                      label: 'dias seguidos',
                    ),
                    _SummaryStat(
                      icon: Icons.insights_rounded,
                      color: AppColors.purpleLight,
                      value: '${(summary.masteryPct * 100).round()}%',
                      label: 'domínio',
                    ),
                  ],
                ),
                if (summary.topicUnlocked) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_open_rounded, color: AppColors.green),
                        SizedBox(width: 8),
                        Text(
                          'Próximo tópico desbloqueado!',
                          style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Voltar para o início'),
                  ),
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
  final Color color;
  final String value;
  final String label;
  const _SummaryStat({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
