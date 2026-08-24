import 'package:flutter/material.dart';

import '../theme.dart';

/// Aba da navegação inferior persistente do app.
enum AppTab { home, review, certifications, profile }

/// Barra de navegação inferior — Home / Revisão / Certificações / Perfil.
/// Fica só nas telas "raiz" logadas (ver MainShell); Lição/Resumo escondem
/// a navegação por serem um fluxo modal de tarefa única.
class CertFlyBottomNav extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  const CertFlyBottomNav({super.key, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line, width: 2)),
      ),
      child: Row(
        children: [
          _NavItem(
            tab: AppTab.home,
            label: 'Home',
            icon: Icons.home_rounded,
            current: current,
            onSelect: onSelect,
          ),
          _NavItem(
            tab: AppTab.review,
            label: 'Revisão',
            icon: Icons.history_rounded,
            current: current,
            onSelect: onSelect,
          ),
          _NavItem(
            tab: AppTab.certifications,
            label: 'Certificações',
            icon: Icons.school_rounded,
            current: current,
            onSelect: onSelect,
          ),
          _NavItem(
            tab: AppTab.profile,
            label: 'Perfil',
            icon: Icons.person_rounded,
            current: current,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final AppTab tab;
  final String label;
  final IconData icon;
  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  const _NavItem({
    required this.tab,
    required this.label,
    required this.icon,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final active = tab == current;
    final color = active ? AppColors.purpleLight : AppColors.textDim;

    return Expanded(
      child: InkWell(
        onTap: () => onSelect(tab),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: active ? AppColors.purpleLight.withValues(alpha: 0.16) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
