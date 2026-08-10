import 'package:flutter/material.dart';

/// Número que conta de 0 até [value] — usado no resumo da lição (XP,
/// streak, % de domínio) pra reforçar a sensação de conquista, em vez de
/// só mostrar o número final parado.
class CountUpText extends StatelessWidget {
  final int value;
  final String Function(int) format;
  final TextStyle? style;

  const CountUpText({super.key, required this.value, required this.format, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) => Text(format(animatedValue), style: style),
    );
  }
}
