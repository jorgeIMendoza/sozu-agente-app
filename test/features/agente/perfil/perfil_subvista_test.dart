import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/perfil/components/perfil_subvista.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import 'fake_perfil_agente_port.dart';

/// Las subvistas del Perfil comparten envoltorio, así que el pull-to-refresh y
/// el orden scroll → limitador de ancho se fijan una vez aquí.
void main() {
  Future<void> pump(WidgetTester tester, Widget subvista) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        builder: (context, child) =>
            SozuAdaptiveTokens(child: child ?? const SizedBox()),
        home: subvista,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin onRefrescar no monta indicador de arrastre', (tester) async {
    await pump(
      tester,
      const PerfilSubvista(titulo: 'Cuenta', children: [Text('contenido')]),
    );

    expect(find.byType(RefreshIndicator), findsNothing);
  });

  testWidgets('el arrastre hacia abajo dispara el refresco', (tester) async {
    var veces = 0;
    await pump(
      tester,
      PerfilSubvista(
        titulo: 'Cuenta',
        onRefrescar: () async => veces++,
        children: const [SizedBox(height: 1200, child: Text('contenido'))],
      ),
    );

    expect(find.byType(RefreshIndicator), findsOneWidget);
    await tester.fling(find.text('contenido'), const Offset(0, 320), 1000);
    await tester.pumpAndSettle();

    expect(veces, 1);
  });

  testWidgets('el scroll envuelve al limitador de ancho, no al revés', (
    tester,
  ) async {
    // Al revés, la rueda del ratón solo mueve la columna central y en los
    // laterales la página no responde (la trampa que documenta AdminScrollArea).
    await pump(
      tester,
      const PerfilSubvista(titulo: 'Cuenta', children: [Text('contenido')]),
    );

    final limitador = find.byWidgetPredicate(
      (w) => w is ConstrainedBox && w.constraints.maxWidth == 900,
    );
    expect(limitador, findsOneWidget);
    expect(
      find.ancestor(of: limitador, matching: find.byType(ListView)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: limitador, matching: find.byType(ListView)),
      findsNothing,
    );
  });

  testWidgets('refrescarPerfilDelAgente vuelve a pedir el perfil', (
    tester,
  ) async {
    final port = FakePerfilAgentePort();
    late WidgetRef capturado;

    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [perfilAgentePortProvider.overrideWithValue(port)],
        ),
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              capturado = ref;
              ref.watch(perfilAgenteProvider);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(port.log, ['cargar']);

    await refrescarPerfilDelAgente(capturado);

    expect(port.log, ['cargar', 'cargar']);
  });
}
