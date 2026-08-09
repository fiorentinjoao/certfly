/// Fonte do token usado nas chamadas à API (ApiClient).
///
/// RF-01 pede e-mail/senha OU OAuth Google via Supabase Auth — isso é
/// responsabilidade do backend validar (ver backend/app/auth.py), não
/// deste app. O que falta aqui é integrar o SDK `supabase_flutter` de
/// verdade, quando existir um projeto Supabase (ver docs/requirements.md,
/// seção "Em aberto").
///
/// Até lá, [DevAuthGateway] é o único gateway: lê um token já assinado
/// (gerado por scripts/seed_dev.py) via --dart-define-from-file, sem
/// nenhuma tela de login de verdade — não há com o que autenticar
/// interativamente sem um Supabase real por trás.
abstract class AuthGateway {
  /// Token JWT atual, ou null se não há sessão.
  String? get token;
}

class DevAuthGateway implements AuthGateway {
  final String? _devToken;

  const DevAuthGateway(this._devToken);

  @override
  String? get token => (_devToken?.isEmpty ?? true) ? null : _devToken;
}
