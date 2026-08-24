import 'package:shared_preferences/shared_preferences.dart';

/// Persiste qual certificação o usuário escolheu como ativa (ver
/// CertificationsScreen) — sem isso, a escolha se perde a cada restart do
/// app e volta pro valor fixo de `AppConfig.certificationId` (dart-define).
class ActiveCertificationStore {
  static const _key = 'active_certification_id';

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> write(String certificationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, certificationId);
  }
}
