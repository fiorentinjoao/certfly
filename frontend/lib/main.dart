import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api/api_client.dart';
import 'config/app_config.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/missing_config_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
  runApp(const CertFlyApp());
}

class CertFlyApp extends StatelessWidget {
  const CertFlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CertFly',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const _Bootstrap(),
    );
  }
}

/// Decide o que mostrar primeiro:
/// - sem `certificationId` configurado (dev.json) → instrução de setup,
///   já que não existe endpoint de "listar certificações" no MVP (RF-02
///   assume que o cliente já sabe qual mostrar);
/// - com token de dev (scripts/seed_dev.py) → pula o login (atalho local);
/// - senão → login real via Supabase Auth (RF-01), ver [_AuthGate].
class _Bootstrap extends StatelessWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasCertification) {
      return const MissingConfigScreen();
    }

    if (AppConfig.hasDevSession) {
      final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl, token: AppConfig.devToken);
      return HomeScreen(apiClient: apiClient, certificationId: AppConfig.certificationId);
    }

    return const _AuthGate();
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl, token: session.accessToken);
        return HomeScreen(
          apiClient: apiClient,
          certificationId: AppConfig.certificationId,
          onLogout: () => Supabase.instance.client.auth.signOut(),
        );
      },
    );
  }
}
