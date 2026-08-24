import 'package:flutter/material.dart';

/// Identidade visual da marca CertFly (moodboard: mascote panda, roxo +
/// verde + âmbar sobre fundo escuro, tipografia Nunito). O app em si é
/// dark-first — é como a própria "Aplicação" do moodboard já é mostrada;
/// modo claro fica pro material de marketing (site/banner), não pro app.
///
/// Nunito substituiu Poppins/Fredoka em 2026-08-10, alinhando o app real
/// ao sistema visual refinado no protótipo (ver pubspec.yaml) — é a fonte
/// que a própria Duolingo recomenda como substituto público de sua
/// Feather Bold proprietária.
class AppColors {
  static const ink = Color(0xFF111827); // fundo principal
  static const surface = Color(0xFF1B2333); // cards / superfícies elevadas
  static const surfaceHigh = Color(0xFF232C40); // hover/estado selecionado
  static const line = Color(0xFF2E3750);

  static const textPrimary = Color(0xFFF3F4F6);
  static const textDim = Color(0xFF9AA3B8);

  static const purple = Color(0xFF6D28D9); // primária da marca
  static const purpleLight = Color(0xFFA78BFA); // realces/estados claros
  static const purpleShadow = Color(0xFF4C1D95); // "degrau" sólido dos botões/nós 3D
  static const green = Color(0xFF22C55E); // XP / acerto
  static const amber = Color(0xFFF59E0B); // streak
  static const red = Color(0xFFEF4444); // erro (semântico, fora da paleta de marca)
}

class AppTheme {
  static ThemeData dark() {
    final colorScheme = const ColorScheme.dark(
      surface: AppColors.ink,
      primary: AppColors.purple,
      secondary: AppColors.purpleLight,
      onSurface: AppColors.textPrimary,
      onPrimary: Colors.white,
      error: AppColors.red,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.ink,
      fontFamily: 'Nunito',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        bodySmall: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDim),
        labelLarge: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDim),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        margin: EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: AppColors.line, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ).copyWith(
          // Sombra colorida + elevação: Material precisa de elevation > 0
          // pra desenhar shadowColor (elevação 0 não mostra sombra
          // nenhuma, mesmo com shadowColor setado — não é o box-shadow
          // "degrau" flat do protótipo, mas dá mais peso/dimensão ao
          // botão sem precisar reescrever cada tela que usa FilledButton
          // com um widget custom).
          elevation: const WidgetStatePropertyAll(4),
          shadowColor: const WidgetStatePropertyAll(AppColors.purpleShadow),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppColors.line, width: 2),
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.purple,
        linearTrackColor: AppColors.line,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceHigh,
        labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(color: AppColors.textDim, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.purpleLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
      ),
    );
  }
}
