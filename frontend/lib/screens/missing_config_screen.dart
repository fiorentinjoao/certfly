import 'package:flutter/material.dart';

/// Mostrada quando o app sobe sem `certificationId` configurado (ver
/// lib/config/app_config.dart) — sem endpoint de "listar certificações"
/// no MVP (RF-02), o cliente precisa saber de antemão qual mostrar, e
/// isso só existe depois de rodar scripts/seed_dev.py. Login real
/// (Supabase) já funciona nesse ponto — o que falta é conteúdo semeado.
class MissingConfigScreen extends StatelessWidget {
  const MissingConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/mascot_icon.png', width: 56, height: 56),
              const SizedBox(height: 16),
              Text(
                'Nenhuma certificação configurada',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'O app ainda não sabe qual certificação mostrar (não há endpoint '
                'de listagem no MVP). Semeie conteúdo de exemplo primeiro.\n\n'
                'Na raiz do repo:\n'
                'backend/.venv/bin/python scripts/seed_dev.py\n\n'
                'E rode o app com:\n'
                'flutter run -d linux --dart-define-from-file=dev.json',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
