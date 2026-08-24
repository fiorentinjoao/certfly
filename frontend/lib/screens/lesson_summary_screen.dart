import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../theme.dart';
import '../models/lesson_summary.dart';
import '../widgets/count_up_text.dart';
import '../widgets/fade_slide_in.dart';

/// Marcos de streak que ganham celebração especial (RF-11 + métrica de
/// retenção do produto — ver README, "streak de 7+ dias" como sucesso).
/// Sem isso, bater 7 dias fica visualmente idêntico a bater 2, perdendo a
/// chance de reforçar o hábito nos marcos que mais importam.
const _streakMilestones = {7, 14, 30, 60, 100, 200, 365};

/// Resumo ao fim da lição (RF-11) — XP ganho, streak, mudança no % de
/// domínio e se o tópico foi desbloqueado (RF-09).
class LessonSummaryScreen extends StatefulWidget {
  final LessonSummary summary;
  const LessonSummaryScreen({super.key, required this.summary});

  @override
  State<LessonSummaryScreen> createState() => _LessonSummaryScreenState();
}

class _LessonSummaryScreenState extends State<LessonSummaryScreen> {
  bool get _isMilestone => _streakMilestones.contains(widget.summary.currentStreak);

  @override
  void initState() {
    super.initState();
    if (_isMilestone) {
      // Distingue o marco de um acerto comum — o toque de resposta certa
      // já usa lightImpact (ver lesson_screen.dart), então aqui precisa
      // ser algo mais forte pra não passar despercebido.
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LivelyMascot(
                  glow: _isMilestone,
                  child: Lottie.asset(
                    'assets/animations/panda_hero.lottie',
                    height: 180,
                    repeat: true,
                    frameRate: FrameRate.max,
                  ),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: Text('Lição concluída!', style: Theme.of(context).textTheme.headlineSmall),
                ),
                if (_isMilestone) ...[
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.amber.withValues(alpha: 0.22),
                            AppColors.amber.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(color: AppColors.amber.withValues(alpha: 0.5), width: 1.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '🔥 Marco de ${summary.currentStreak} dias seguidos!',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.amber),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 240),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SummaryStat(
                        icon: Icons.bolt_rounded,
                        color: AppColors.green,
                        value: summary.xpEarned,
                        format: (v) => '+$v',
                        label: 'XP',
                      ),
                      _SummaryStat(
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.amber,
                        value: summary.currentStreak,
                        format: (v) => '$v',
                        label: 'dias seguidos',
                        pulse: _isMilestone,
                      ),
                      _SummaryStat(
                        icon: Icons.insights_rounded,
                        color: AppColors.purpleLight,
                        value: (summary.masteryPct * 100).round(),
                        format: (v) => '$v%',
                        label: 'domínio',
                      ),
                    ],
                  ),
                ),
                if (summary.topicUnlocked) ...[
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 320),
                    child: Container(
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
                  ),
                ],
                const SizedBox(height: 32),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 380),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Voltar para o início'),
                    ),
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

/// Entrada em "pop" (escala com leve exagero) pro mascote — a animação em
/// si (aceno, piscar, respiração) já vem de dentro do arquivo `.lottie`
/// (ver `panda_hero.lottie`, `Lottie.asset(..., repeat: true)`), então este
/// widget só cuida da chegada na tela, sem competir com o movimento do
/// personagem. `glow` acrescenta um halo âmbar pulsante atrás do mascote
/// nos marcos de streak (ver `_streakMilestones`).
class _LivelyMascot extends StatelessWidget {
  final Widget child;
  final bool glow;
  const _LivelyMascot({required this.child, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final entrance = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(scale: value, child: child),
      child: child,
    );

    if (!glow) return entrance;

    return _PulsingGlow(child: entrance);
  }
}

class _PulsingGlow extends StatefulWidget {
  final Widget child;
  const _PulsingGlow({required this.child});

  @override
  State<_PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<_PulsingGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.amber.withValues(alpha: 0.18 + (0.14 * curved.value)),
                blurRadius: 40 + (20 * curved.value),
                spreadRadius: 4 + (6 * curved.value),
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String Function(int) format;
  final String label;
  final bool pulse;

  const _SummaryStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.format,
    required this.label,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: color);
    return Column(
      children: [
        pulse ? _IconPulse(child: iconWidget) : iconWidget,
        const SizedBox(height: 4),
        CountUpText(value: value, format: format, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Pulso contínuo pro ícone de streak — só ativo em marco (ver
/// `_streakMilestones`), reforça qual das 3 estatísticas é a especial
/// desta tela sem precisar de texto extra.
class _IconPulse extends StatefulWidget {
  final Widget child;
  const _IconPulse({required this.child});

  @override
  State<_IconPulse> createState() => _IconPulseState();
}

class _IconPulseState extends State<_IconPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Transform.scale(scale: 1.0 + (0.18 * curved.value), child: child),
      child: widget.child,
    );
  }
}
