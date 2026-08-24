import 'package:flutter/material.dart';

import '../theme.dart';
import 'count_up_text.dart';

/// Card em destaque de streak — a métrica de sucesso do MVP (retenção via
/// streak de 7+ dias, ver docs/product-spec.md) precisa ser o elemento
/// emocional central da Home, não um stat igual aos outros.
class StreakHero extends StatelessWidget {
  final int currentStreak;
  final int totalXp;

  const StreakHero({super.key, required this.currentStreak, required this.totalXp});

  @override
  Widget build(BuildContext context) {
    final isDayZero = currentStreak == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.amber.withValues(alpha: 0.14), AppColors.amber.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.32), width: 2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department_rounded, color: AppColors.amber, size: 26),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CountUpText(
                  value: currentStreak,
                  format: (v) => '$v',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'dias seguidos',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDim),
                ),
                const SizedBox(height: 6),
                Text(
                  isDayZero ? 'Comece sua primeira lição hoje' : 'Estude hoje pra manter o streak',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.amber),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, size: 12, color: AppColors.green),
                const SizedBox(width: 4),
                CountUpText(
                  value: totalXp,
                  format: (v) => '$v',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
