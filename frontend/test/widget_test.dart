// Smoke test: o app sobe sem crashar. Sem --dart-define-from-file=dev.json
// (ver lib/config/app_config.dart), certificationId vem vazio e cai na
// MissingConfigScreen ANTES de tocar em Supabase — é esse caminho que
// este teste cobre, já que os testes não inicializam o SDK real.

import 'package:flutter_test/flutter_test.dart';

import 'package:certfly/main.dart';

void main() {
  testWidgets('sobe sem certificação configurada e mostra a tela de instruções', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CertFlyApp());

    expect(find.text('Nenhuma certificação configurada'), findsOneWidget);
  });
}
