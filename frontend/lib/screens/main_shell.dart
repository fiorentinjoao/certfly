import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../widgets/bottom_nav_bar.dart';
import 'certifications_screen.dart';
import 'coming_soon_tab.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Host da navegação inferior persistente (Home / Revisão / Certificações
/// / Perfil) — substitui a antiga HomeScreen como tela raiz pós-login.
/// Revisão continua placeholder: o backend ainda não tem endpoint de
/// "questões vencendo hoje" (ver docs/requirements.md, seção "Em aberto")
/// — melhor isso do que inventar dado fixo numa tela de produção.
/// Certificações já é real (GET /certifications), mas sem troca de
/// certificação ativa ainda — ver certifications_screen.dart.
class MainShell extends StatefulWidget {
  final ApiClient apiClient;
  final String certificationId;
  final VoidCallback? onLogout;

  const MainShell({
    super.key,
    required this.apiClient,
    required this.certificationId,
    this.onLogout,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AppTab _current = AppTab.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: AppTab.values.indexOf(_current),
        children: [
          HomeScreen(apiClient: widget.apiClient, certificationId: widget.certificationId),
          const ComingSoonTab(
            title: 'Revisão',
            icon: Icons.history_rounded,
            message: 'Em breve: questões vencendo hoje, reunidas num só lugar.',
          ),
          CertificationsScreen(
            apiClient: widget.apiClient,
            activeCertificationId: widget.certificationId,
          ),
          ProfileScreen(apiClient: widget.apiClient, onLogout: widget.onLogout),
        ],
      ),
      bottomNavigationBar: CertFlyBottomNav(
        current: _current,
        onSelect: (tab) => setState(() => _current = tab),
      ),
    );
  }
}
