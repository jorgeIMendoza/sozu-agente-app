import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/features/admin/components/agente_row.dart';
import 'package:sozu_agente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_agente_app/features/admin/screens/select_agente_screen.dart';
import 'package:sozu_agente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../auth/fake_auth_port.dart';
import 'fake_admin_port.dart';

/// Lo que fija este archivo: el selector del admin lista AGENTES y se acota por
/// rol y por texto, y los dos filtros se combinan.
///
/// A diferencia del selector de clientes del que venia portado, aqui NO hace
/// falta escribir para ver algo: los agentes son decenas.
void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(1280, 900),
    FakeAdminPort? admin,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminPortProvider.overrideWithValue(admin ?? FakeAdminPort()),
          authPortProvider.overrideWithValue(FakeAuthPort()),
        ],
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: const SelectAgenteScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista los agentes sin escribir nada', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(AgenteRow), findsNWidgets(3));
    expect(find.text('Selecciona un agente'), findsOneWidget);
  });

  testWidgets('las pastillas traen el conteo real por rol', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Todos (3)'), findsOneWidget);
    expect(find.text('Agente Inmobiliario (1)'), findsOneWidget);
    expect(find.text('Agente Interno (1)'), findsOneWidget);
  });

  testWidgets('el filtro de rol acota la lista', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Agente Interno (1)'));
    await tester.pumpAndSettle();

    expect(find.byType(AgenteRow), findsOneWidget);
    expect(find.text('Bruno Pérez'), findsOneWidget);
    expect(find.text('Alex Hernández'), findsNothing);
  });

  testWidgets('rol + busqueda se combinan y pueden quedar en vacio', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Agente Interno (1)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SSearchField), 'alex');
    await tester.pumpAndSettle();

    // Alex existe, pero es Inmobiliario: con el rol Interno activo no aparece.
    expect(find.byType(AgenteRow), findsNothing);
    expect(find.text('Sin resultados'), findsOneWidget);
  });

  testWidgets('busca por correo, no solo por nombre', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(SSearchField), 'bruno@x.com');
    await tester.pumpAndSettle();

    expect(find.byType(AgenteRow), findsOneWidget);
    expect(find.text('Bruno Pérez'), findsOneWidget);
  });

  testWidgets('un rol que no es 3 ni 9 solo sale en "Todos"', (tester) async {
    await pumpScreen(tester);

    // Carla es "Coordinador": el backend la manda, la fila la muestra con el
    // nombre de rol de la BD, pero ninguna pastilla de rol la reclama.
    expect(find.text('Carla Ruiz'), findsOneWidget);
    expect(find.text('Coordinador'), findsOneWidget);

    await tester.tap(find.text('Agente Inmobiliario (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Carla Ruiz'), findsNothing);
  });

  testWidgets('sin agentes el vacio lo dice, no deja la pantalla en blanco', (
    tester,
  ) async {
    await pumpScreen(tester, admin: _PortSinAgentes());

    expect(find.text('Sin agentes'), findsOneWidget);
    expect(find.byType(SEmptyState), findsOneWidget);
  });
}

/// Backend que responde con la lista vacia (ningun usuario con rol de agente).
class _PortSinAgentes extends FakeAdminPort {
  @override
  Future<AdminAgentes> agentes() async => const AdminAgentes([]);
}
