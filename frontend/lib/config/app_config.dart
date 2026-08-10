/// Configuração de ambiente. `supabaseUrl`/`supabaseAnonKey` têm defaults
/// apontando pro projeto Supabase real do CertFly — a "publishable key"
/// é, por design do Supabase, segura pra embutir em código cliente (não é
/// segredo, ao contrário da "secret key" usada só no backend/scripts
/// administrativos). `devToken`/`certificationId` só existem via
/// `--dart-define-from-file=dev.json` (gerado por scripts/seed_dev.py) —
/// atalho de desenvolvimento pra pular o login (ver lib/auth/auth_gateway.dart).
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'apiBaseUrl',
    defaultValue: 'http://localhost:8000',
  );

  static const supabaseUrl = String.fromEnvironment(
    'supabaseUrl',
    defaultValue: 'https://bmrucxfofwbcyyhgrzqt.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'supabaseAnonKey',
    defaultValue: 'sb_publishable_xpX5KYIGL_W1L6VerFsYBg_kBED5dcZ',
  );

  static const devToken = String.fromEnvironment('devToken');

  // Sem endpoint de "listar certificações" no MVP (RF-02 assume que o
  // cliente já sabe qual certificação mostrar) — vem de dev.json
  // (scripts/seed_dev.py), que muda a cada reseed, então NÃO tem default
  // fixo aqui: hardcoded ficaria stale no primeiro reseed.
  static const certificationId = String.fromEnvironment('certificationId');

  static bool get hasDevSession => devToken.isNotEmpty;

  static bool get hasCertification => certificationId.isNotEmpty;
}
