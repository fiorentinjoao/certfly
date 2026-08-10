import 'package:flutter/material.dart';

/// Barra de progresso que anima suavemente até o novo valor em vez de
/// simplesmente "pular" — usada pra mastery de tópico (Home) e progresso
/// de questões (Lição), onde o valor muda a cada resposta/reload.
class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final double minHeight;
  final Color backgroundColor;
  final Color valueColor;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.minHeight,
    required this.backgroundColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(minHeight / 2),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) {
          return LinearProgressIndicator(
            value: animatedValue,
            minHeight: minHeight,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation(valueColor),
          );
        },
      ),
    );
  }
}
