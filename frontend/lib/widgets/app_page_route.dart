import 'package:flutter/material.dart';

/// Transição de página padrão do app — fade + leve deslocamento pra cima,
/// em vez do slide lateral default do Material (que pode não animar nada
/// no target desktop). Usar em todo `Navigator.push` no lugar de
/// `MaterialPageRoute` mantém a navegação consistente em qualquer tela.
Route<T> appPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
