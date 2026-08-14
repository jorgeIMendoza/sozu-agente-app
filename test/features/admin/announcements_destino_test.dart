import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_agente_app/features/admin/screens/announcements_screen.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import 'fake_admin_port.dart';

/// Lo que fija este archivo: el aviso se dirige por ROL y la pantalla dice a
/// cuantos va ANTES de mandarlo.
///
/// Antes esta pantalla segmentaba por proyecto / modelo / nivel / unidad y el
/// resumen decia "Todos los clientes": era la del portal del cliente portada
/// tal cual, asi que un aviso escrito para agentes salia a los compradores.
void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminPortProvider.overrideWithValue(FakeAdminPort())],
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: const AnnouncementsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el destino por defecto son todos los agentes, con su total', (
    tester,
  ) async {
    await pumpScreen(tester);

    // 3 inmobiliarios + 2 internos del doble del puerto: el total sale de la
    // misma consulta que resuelve los destinatarios, no de un conteo aparte.
    expect(find.text('Destino: Todos los agentes (5)'), findsOneWidget);
    expect(find.textContaining('clientes'), findsNothing);
  });

  testWidgets('hay UN campo de destino y es el de roles', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Roles'), findsOneWidget);
    // Sin selección el campo invita a mandarlo a todos, que es lo que el
    // backend entiende por `ids_roles` vacío.
    expect(find.text('Todos los agentes'), findsOneWidget);
  });

  testWidgets('ya no quedan filtros de propiedad: no aplican a un agente', (
    tester,
  ) async {
    await pumpScreen(tester);

    for (final label in ['Proyectos', 'Modelos', 'Niveles', 'Propiedades']) {
      expect(find.text(label), findsNothing, reason: '$label es del cliente');
    }
  });
}
