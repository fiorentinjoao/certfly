import 'package:flutter/material.dart';

import '../theme.dart';

/// Placeholder pras abas Revisão/Certificações — o backend ainda não tem
/// endpoint de "questões vencendo hoje" nem de listagem/troca de
/// certificação (só GET /certification/{id}/progress, que já assume um
/// ID conhecido — ver docs/requirements.md, seção "Em aberto"). Preferi
/// isso a inventar dado fixo na tela real.
class ComingSoonTab extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const ComingSoonTab({super.key, required this.title, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: AppColors.surfaceHigh, shape: BoxShape.circle),
                child: Icon(icon, size: 26, color: AppColors.textDim),
              ),
              const SizedBox(height: 14),
              const Text(
                'Em breve',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textDim, height: 1.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
