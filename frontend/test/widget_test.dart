// Smoke test: o app sobe sem crashar. Sem --dart-define-from-file=dev.json
// (ver lib/config/app_config.dart), cai na MissingConfigScreen — é esse
// caminho que este teste cobre, já que os testes não têm acesso a um
// backend rodando.

import 'package:flutter_test/flutter_test.dart';

import 'package:certfly/main.dart';

void main() {
  testWidgets('sobe sem config de dev e mostra a tela de instruções', (WidgetTester tester) async {
    await tester.pumpWidget(const CertFlyApp());

    expect(find.text('Config de desenvolvimento ausente'), findsOneWidget);
  });
}
