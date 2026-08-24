import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/progress.dart';
import '../theme.dart';
import 'fade_slide_in.dart';

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
              // Cascata de entrada — cada nó "chega" um pouco depois do
              // anterior, em vez da trilha inteira aparecer de uma vez só.
              FadeSlideIn(
                delay: Duration(milliseconds: 70 * i),
                child: _PathNode(
                  topic: domain.topics[i],
                  isActive: domain.topics[i].id == activeTopicId,
                  offset: i.isEven ? 0.0 : (i % 4 == 1 ? 46.0 : -46.0),
                  entranceDelay: Duration(milliseconds: 70 * i),
                  onTap: () => onTapTopic(domain.topics[i]),
                ),
              ),
              if (i != domain.topics.length - 1) const SizedBox(height: 30),
            ],
          ],
        ),
      ],
    );
  }
}

class _PathNode extends StatefulWidget {
  final TopicProgress topic;
  final bool isActive;
  final double offset;
  final Duration entranceDelay;
  final VoidCallback onTap;

  const _PathNode({
    required this.topic,
    required this.isActive,
    required this.offset,
    required this.entranceDelay,
    required this.onTap,
  });

  @override
  State<_PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<_PathNode> with TickerProviderStateMixin {
  late final AnimationController _progress;
  late final AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();

    // Anel de mastery enche a partir de 0 (em vez de nascer já no valor
    // final) — só começa depois da entrada (fade/slide) terminar, pra não
    // competir visualmente com ela.
    _progress = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    Future.delayed(widget.entranceDelay, () {
      if (mounted) _progress.forward();
    });

    // Respiração contínua só no nó ativo — chama atenção pro próximo
    // passo sem precisar de texto extra.
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    if (widget.isActive) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PathNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mastery pode mudar depois de completar uma lição (Home recarrega) —
    // reanima o anel do valor antigo pro novo em vez de saltar direto.
    if (widget.topic.masteryPct != oldWidget.topic.masteryPct) {
      _progress
        ..reset()
        ..forward();
    }
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulse.repeat(reverse: true);
      } else {
        _pulse.stop();
        _pulse.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final isActive = widget.isActive;
    final size = isActive ? 64.0 : 54.0;

    return Transform.translate(
      offset: Offset(widget.offset, 0),
      child: GestureDetector(
        onTap: topic.unlocked
            ? () {
                HapticFeedback.selectionClick();
                widget.onTap();
              }
            : null,
        onTapDown: topic.unlocked ? (_) => setState(() => _pressed = true) : null,
        onTapUp: topic.unlocked ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: topic.unlocked ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          // Feedback de toque — o nó "afunda" levemente ao pressionar,
          // antes mesmo de navegar, pra parecer mais físico/responsivo.
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
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
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final pulseScale = isActive ? 1.0 + (0.05 * Curves.easeInOut.transform(_pulse.value)) : 1.0;
                  return Transform.scale(scale: pulseScale, child: child);
                },
                child: SizedBox(
                  width: size + 16,
                  height: size + 16,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (topic.unlocked)
                        AnimatedBuilder(
                          animation: _progress,
                          builder: (context, _) => SizedBox(
                            width: size + 16,
                            height: size + 16,
                            child: CircularProgressIndicator(
                              value: (topic.masteryPct.clamp(0, 1)) * _progress.value,
                              strokeWidth: 5,
                              backgroundColor: AppColors.surfaceHigh,
                              valueColor: const AlwaysStoppedAnimation(AppColors.green),
                            ),
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
                        // Transição de desbloqueio — quando o tópico deixa
                        // de estar bloqueado (após completar o anterior), o
                        // cadeado dá lugar ao ícone real com um "pop" em
                        // vez de simplesmente trocar de ícone sem aviso.
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            topic.unlocked
                                ? (isActive ? Icons.play_arrow_rounded : Icons.menu_book_rounded)
                                : Icons.lock_rounded,
                            key: ValueKey('${topic.unlocked}-$isActive'),
                            color: isActive
                                ? Colors.white
                                : (topic.unlocked ? AppColors.purpleLight : AppColors.textDim),
                            size: isActive ? 26 : 18,
                          ),
                        ),
                      ),
                    ],
                  ),
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
      ),
    );
  }
}
