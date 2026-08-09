import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'auth/auth_gateway.dart';
import 'config/app_config.dart';
import 'screens/home_screen.dart';
import 'screens/missing_config_screen.dart';
import 'theme.dart';

void main() {
  runApp(const CertFlyApp());
}

class CertFlyApp extends StatelessWidget {
  const CertFlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CertFly',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: const _Bootstrap(),
    );
  }
}

/// Decide entre a Home (sessão de dev configurada) e uma tela explicando
/// como gerar `dev.json` — ver lib/auth/auth_gateway.dart. Não há tela de
/// login interativa ainda porque não existe Supabase real por trás pra
/// autenticar de verdade.
class _Bootstrap extends StatelessWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasDevSession) {
      return const MissingConfigScreen();
    }

    final authGateway = const DevAuthGateway(AppConfig.devToken);
    final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl, token: authGateway.token!);

    return HomeScreen(apiClient: apiClient, certificationId: AppConfig.certificationId);
  }
}
