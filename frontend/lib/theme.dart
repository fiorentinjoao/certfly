import 'package:flutter/material.dart';

/// Tema do app — Material 3, cor semente única. `correct`/`wrong` são os
/// únicos tokens fora do ColorScheme, usados na tela de resposta (RF-04)
/// pra marcar alternativa certa/errada de forma consistente.
class AppTheme {
  static const _seed = Color(0xFF3D5AFE);
  static const correct = Color(0xFF2E7D32);
  static const wrong = Color(0xFFC62828);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: _seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 6),
      ),
    );
  }
}
