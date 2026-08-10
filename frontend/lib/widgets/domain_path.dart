import 'package:flutter/material.dart';

import '../models/progress.dart';
import '../theme.dart';

/// Trilha em zigue-zague — substitui a lista plana de tópicos por domínio.
/// O nó ativo (primeiro tópico desbloqueado ainda não dominado) ganha
/// destaque com um anel de mastery real (RF-02) e um botão de play; os
/// demais aparecem como nós menores (dominado) ou bloqueados (cadeado).
class DomainPathSection extends StatelessWidget {
  final DomainProgress domain;
  final String? activeTopicId;
  final void Function(TopicProgress topic) onTapTopic;

  const DomainPathSection({
    super.key,
    required this.domain,
    required this.activeTopicId,
    required this.onTapTopic,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
          decoration: BoxDecoration(color: AppColors.purple, borderRadius: BorderRadius.circular(16)),
          child: Text(
            domain.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.white),
          ),
        ),
        const SizedBox(height: 30),
        Column(
          children: [
            for (var i = 0; i < domain.topics.length; i++) ...[
              _PathNode(
                topic: domain.topics[i],
                isActive: domain.topics[i].id == activeTopicId,
                offset: i.isEven ? 0.0 : (i % 4 == 1 ? 46.0 : -46.0),
                onTap: () => onTapTopic(domain.topics[i]),
              ),
              if (i != domain.topics.length - 1) const SizedBox(height: 30),
            ],
          ],
        ),
      ],
    );
  }
}

class _PathNode extends StatelessWidget {
  final TopicProgress topic;
  final bool isActive;
  final double offset;
  final VoidCallback onTap;

  const _PathNode({
    required this.topic,
    required this.isActive,
    required this.offset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = isActive ? 64.0 : 54.0;

    return Transform.translate(
      offset: Offset(offset, 0),
      child: GestureDetector(
        onTap: topic.unlocked ? onTap : null,
        child: Column(
          children: [
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.purple, width: 2),
                  ),
                  child: Text(
                    topic.masteryPct > 0 ? 'Continuar' : 'Começar',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.purpleLight,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: size + 16,
              height: size + 16,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (topic.unlocked)
                    SizedBox(
                      width: size + 16,
                      height: size + 16,
                      child: CircularProgressIndicator(
                        value: topic.masteryPct.clamp(0, 1),
                        strokeWidth: 5,
                        backgroundColor: AppColors.surfaceHigh,
                        valueColor: const AlwaysStoppedAnimation(AppColors.green),
                      ),
                    ),
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? AppColors.purple : AppColors.surface,
                      border: isActive ? null : Border.all(color: AppColors.line, width: 2),
                      boxShadow: isActive
                          ? const [BoxShadow(color: AppColors.purpleShadow, offset: Offset(0, 5))]
                          : null,
                    ),
                    child: Icon(
                      topic.unlocked
                          ? (isActive ? Icons.play_arrow_rounded : Icons.menu_book_rounded)
                          : Icons.lock_rounded,
                      color: isActive
                          ? Colors.white
                          : (topic.unlocked ? AppColors.purpleLight : AppColors.textDim),
                      size: isActive ? 26 : 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: topic.unlocked ? 1 : 0.5,
              child: Text(
                topic.unlocked && topic.masteryPct > 0
                    ? '${topic.name} · ${(topic.masteryPct * 100).round()}%'
                    : topic.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                  color: isActive ? AppColors.textPrimary : AppColors.textDim,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
