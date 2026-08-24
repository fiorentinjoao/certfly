import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/active_certification_store.dart';
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
///
/// Certificação ativa: começa com `initialCertificationId` (hoje vem de
/// `AppConfig.certificationId`, fixo via dart-define), mas pode ser trocada
/// em runtime pela aba Certificações — a escolha é persistida via
/// `ActiveCertificationStore` (shared_preferences) e sobrevive a restart.
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
  late String _activeCertificationId = widget.certificationId;

  @override
  void initState() {
    super.initState();
    _restorePersistedCertification();
  }

  Future<void> _restorePersistedCertification() async {
    final saved = await ActiveCertificationStore.read();
    // Sem isso, o app sempre voltaria pra certificação fixa do dart-define
    // depois de reabrir, ignorando a última escolha do usuário.
    if (saved != null && saved != _activeCertificationId && mounted) {
      setState(() => _activeCertificationId = saved);
    }
  }

  void _onSelectCertification(String certificationId) {
    if (certificationId == _activeCertificationId) return;
    setState(() => _activeCertificationId = certificationId);
    ActiveCertificationStore.write(certificationId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: AppTab.values.indexOf(_current),
        children: [
          HomeScreen(apiClient: widget.apiClient, certificationId: _activeCertificationId),
          const ComingSoonTab(
            title: 'Revisão',
            icon: Icons.history_rounded,
            message: 'Em breve: questões vencendo hoje, reunidas num só lugar.',
          ),
          CertificationsScreen(
            apiClient: widget.apiClient,
            activeCertificationId: _activeCertificationId,
            onSelect: _onSelectCertification,
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
