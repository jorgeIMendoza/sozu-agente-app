import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/perfil/components/documento_del_expediente_fila.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// La fila numerada es paridad con `ExpedienteDocsPanel.tsx`: el agente y quien
/// lo ayuda por teléfono pueden hablar del "documento 3".
void main() {
  const documento = DocumentoDelExpediente(
    clave: 'identidad',
    nombre: 'Identificación oficial',
    emisor: 'INE',
  );

  Future<void> pump(WidgetTester tester, {int? numero}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        builder: (context, child) =>
            SozuAdaptiveTokens(child: child ?? const SizedBox()),
        home: Scaffold(
          body: DocumentoDelExpedienteFila(
            documento: documento,
            numero: numero,
            onEntregar: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pinta la posición cuando se la pasan', (tester) async {
    await pump(tester, numero: 3);

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('sin posición no inventa ningún número', (tester) async {
    await pump(tester);

    expect(find.text('1'), findsNothing);
    expect(find.text('Identificación oficial'), findsOneWidget);
  });
}
