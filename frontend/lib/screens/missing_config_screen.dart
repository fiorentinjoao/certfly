import 'package:flutter/material.dart';

/// Mostrada quando o app sobe sem `dev.json` (ver lib/config/app_config.dart)
/// — instrui como gerar a config de desenvolvimento, já que ainda não há
/// login real (Supabase) implementado.
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
                'Config de desenvolvimento ausente',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Ainda não há um projeto Supabase real conectado, então o app '
                'precisa de um token de teste pra rodar.\n\n'
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
