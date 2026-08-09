/// Configuração de ambiente, lida via `--dart-define-from-file=dev.json`
/// (gerado por scripts/seed_dev.py). Nada aqui é segredo de produção — é
/// só o caminho de desenvolvimento local enquanto não existe um projeto
/// Supabase real (ver docs/requirements.md, seção "Em aberto", e
/// lib/auth/auth_gateway.dart).
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'apiBaseUrl',
    defaultValue: 'http://localhost:8000',
  );

  static const devToken = String.fromEnvironment('devToken');

  static const certificationId = String.fromEnvironment('certificationId');

  static bool get hasDevSession => devToken.isNotEmpty && certificationId.isNotEmpty;
}
