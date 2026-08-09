import 'package:supabase_flutter/supabase_flutter.dart';

/// Fonte do token usado nas chamadas à API (ApiClient) e do e-mail do
/// usuário logado. RF-01: e-mail/senha via Supabase Auth (backend valida
/// o JWT — ver backend/app/auth.py).
abstract class AuthGateway {
  /// Token JWT atual, ou null se não há sessão.
  String? get token;
}

/// Gateway de dev: lê um token já assinado (gerado por
/// scripts/seed_dev.py) via --dart-define-from-file, pulando o login de
/// verdade — só pra iteração rápida local (ver lib/config/app_config.dart).
class DevAuthGateway implements AuthGateway {
  final String? _devToken;

  const DevAuthGateway(this._devToken);

  @override
  String? get token => (_devToken?.isEmpty ?? true) ? null : _devToken;
}

/// Gateway real: token da sessão ativa do Supabase Auth. `signIn`/`signUp`
/// ficam na UI (lib/screens/login_screen.dart) — este gateway só expõe o
/// estado de sessão já resolvido pelo SDK.
class SupabaseAuthGateway implements AuthGateway {
  const SupabaseAuthGateway();

  @override
  String? get token => Supabase.instance.client.auth.currentSession?.accessToken;

  String? get email => Supabase.instance.client.auth.currentUser?.email;

  Stream<AuthState> get onAuthStateChange => Supabase.instance.client.auth.onAuthStateChange;

  Future<void> signOut() => Supabase.instance.client.auth.signOut();
}
