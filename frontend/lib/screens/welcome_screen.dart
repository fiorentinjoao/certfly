import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_page_route.dart';
import '../widgets/fade_slide_in.dart';
import 'login_screen.dart';

/// Primeira tela pra quem não está logado (RF-01) — antes de mostrar
/// qualquer formulário, a pessoa escolhe explicitamente entre "já tenho
/// conta" e "criar conta", em vez de cair direto num formulário ambíguo.
/// Login com Google mora dentro do fluxo de "Já tenho conta"
/// (lib/screens/login_screen.dart), não aqui.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeSlideIn(
                    child: Image.asset('assets/images/mascot_face.png', width: 200, height: 200),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 90),
                    child: const Text(
                      'CertFly',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w700,
                        fontSize: 40,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 150),
                    child: const Text(
                      'Estude. Pratique. Conquiste.',
                      style: TextStyle(color: AppColors.textDim, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 220),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).push(appPageRoute(const LoginScreen(isSignUp: false))),
                            child: const Text('Já tenho conta'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).push(appPageRoute(const LoginScreen(isSignUp: true))),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: AppColors.line),
                              foregroundColor: AppColors.textPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Cadastrar-se'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
