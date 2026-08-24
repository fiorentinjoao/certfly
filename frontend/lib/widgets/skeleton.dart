import 'package:flutter/material.dart';

import '../theme.dart';

/// Bloco de skeleton loading — placeholder cinza pulsando no lugar de um
/// spinner genérico. Sozinho, um `CircularProgressIndicator` centralizado
/// não diz nada sobre o que está carregando; um esboço da UI real (com o
/// mesmo formato/tamanho do conteúdo final) passa sensação de carregamento
/// mais rápido e evita o "pulo" brusco quando os dados chegam.
class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final bool _circle;

  const Skeleton({super.key, required this.width, required this.height, this.borderRadius})
    : _circle = false;

  /// Círculo — atalho pra avatares/ícones em skeleton.
  const Skeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      borderRadius = null,
      _circle = true;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
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
        final opacity = 0.35 + (0.25 * curved.value); // pulsa entre ~35% e ~60%
        return Opacity(
          opacity: opacity,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              shape: widget._circle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widget._circle ? null : (widget.borderRadius ?? BorderRadius.circular(10)),
            ),
          ),
        );
      },
    );
  }
}
