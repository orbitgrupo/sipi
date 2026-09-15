// Sipi — prueba de humo: la app arranca y muestra la bienvenida.
import 'package:flutter_test/flutter_test.dart';

import 'package:sipi/main.dart';

void main() {
  testWidgets('La app muestra la pantalla de bienvenida',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SipiApp());
    await tester.pumpAndSettle();

    // Marca y acciones principales de la bienvenida.
    expect(find.text('Sipi'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
