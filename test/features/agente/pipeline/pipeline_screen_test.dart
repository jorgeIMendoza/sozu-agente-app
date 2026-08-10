import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/pipeline/components/negocio_tarjeta.dart';
import 'package:sozu_agente_app/features/agente/pipeline/providers/pipeline_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/screens/pipeline_screen.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import 'fake_pipeline_port.dart';

/// La pantalla se pinta de verdad en las tres vistas y en los dos formatos.
/// Es la red que atrapa lo que los tests de providers no ven: un desborde de
/// layout, un `Expanded` sin caja o una pantalla en blanco.
void main() {
  const sesion = SesionAgente(
    identidad: IdentidadAgente(email: 'agente@sozu.com'),
    permisos: {VistaAgente.pipeline: PermisosVista.todo},
    onboarding: Onboarding(capacitacionCompleta: true),
  );

  Future<void> pintar(
    WidgetTester tester,
    Size tamano, {
    FakePipelinePort? port,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = tamano;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [
            pipelinePortProvider.overrideWithValue(port ?? FakePipelinePort()),
            sesionProvider.overrideWith((ref) async => sesion),
          ],
        ),
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: const PipelineScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('en teléfono pinta la tabla, el resumen y los avisos', (
    tester,
  ) async {
    await pintar(tester, const Size(390, 900));

    expect(find.textContaining('3 negocios'), findsOneWidget);
    expect(find.textContaining('6 ofertas'), findsOneWidget);
    // Modo presentación activo por default: el monto abierto va enmascarado.
    expect(find.textContaining(kMascaraPresentacion), findsWidgets);
    expect(
      find.textContaining('cerrado sin razón registrada'),
      findsOneWidget,
    );
    expect(find.text('O-000001'), findsOneWidget);
    expect(find.text('O-000003'), findsOneWidget);
    // El nombre del prospecto no se lee con el modo presentación activo.
    expect(find.text('Ana Ruiz'), findsNothing);
  });

  testWidgets('apagar el modo presentación revela nombres y montos', (
    tester,
  ) async {
    await pintar(tester, const Size(1400, 1000));

    await tester.tap(find.byTooltip('Desactivar modo presentación'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Ruiz'), findsWidgets);
    expect(find.textContaining(r'$1,000,000.00'), findsWidgets);
  });

  testWidgets('la vista de tarjetas pinta una tarjeta por negocio', (
    tester,
  ) async {
    await pintar(tester, const Size(1400, 1200));

    await tester.tap(find.text('Tarjetas'));
    await tester.pumpAndSettle();

    expect(find.byType(NegocioTarjeta), findsNWidgets(3));
  });

  testWidgets('el tablero pinta una columna por etapa, con candado en las automáticas', (
    tester,
  ) async {
    await pintar(tester, const Size(1400, 1000));

    await tester.tap(find.text('Tablero'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo'), findsOneWidget);
    expect(find.text('Negociando'), findsOneWidget);
    expect(find.text('Oferta enviada'), findsOneWidget);
    expect(find.text('Cierre perdido'), findsOneWidget);
    // La columna manual vacía invita a arrastrar; la automática solo informa.
    expect(find.text('Arrastra aquí'), findsOneWidget);
    expect(find.text('Sin negocios'), findsNothing);
    // El negocio sin pipeline no se puede arrastrar: su botón lo dice.
    expect(
      find.byTooltip(
        'Este negocio todavía no existe en el pipeline: no se puede mover de '
        'etapa',
      ),
      findsOneWidget,
    );
  });

  testWidgets('el filtro de etapa deja la pantalla con un solo negocio', (
    tester,
  ) async {
    await pintar(tester, const Size(1400, 1000));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PipelineScreen)),
    );
    container.read(etapaFiltroProvider.notifier).state = 'perdido';
    await tester.pumpAndSettle();

    expect(find.text('O-000003'), findsOneWidget);
    expect(find.text('O-000001'), findsNothing);
  });

  testWidgets('la fila abre el detalle con esquemas y link del cliente', (
    tester,
  ) async {
    // Desde la vista de tarjetas y en teléfono: ahí el detalle abre como hoja
    // inferior, que es el camino que usa el agente en la calle.
    await pintar(tester, const Size(390, 900));
    await tester.tap(find.text('Tarjetas'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A-1'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del negocio'), findsOneWidget);
    // SSectionLabel (variante `label`) pinta en mayúsculas: el finder busca lo
    // que el design system realmente rinde, no el string que se le pasó.
    expect(find.text('ESQUEMAS DE PAGO (1)'), findsOneWidget);
    expect(find.text('20-60-20'), findsOneWidget);
    expect(find.text('LINK DEL CLIENTE'), findsOneWidget);
    // Bodega incluida y estacionamiento con precio aparte.
    expect(find.textContaining('B-12 (incluido)'), findsOneWidget);
    expect(find.textContaining('Los no incluidos'), findsOneWidget);
  });

  testWidgets('el cerrado sin razón abre la captura y explica el bloqueo', (
    tester,
  ) async {
    await pintar(tester, const Size(390, 900));
    await tester.tap(find.text('Tarjetas'));
    await tester.pumpAndSettle();

    // El negocio perdido es la última tarjeta: en un teléfono su acción queda
    // fuera del viewport y el tap no llega (Flutter avisa "would not hit test").
    final accionRazon = find.byTooltip('¿Por qué no avanzó?');
    // ensureVisible y no scrollUntilVisible: la pantalla tiene varios
    // Scrollable (la lista y las tiras horizontales) y el segundo exige elegir
    // uno a mano ("Bad state: Too many elements").
    await tester.ensureVisible(accionRazon);
    await tester.pumpAndSettle();
    await tester.tap(accionRazon);
    await tester.pumpAndSettle();

    expect(find.text('Está fuera de presupuesto'), findsOneWidget);
    expect(find.text('Elige una razón para guardar.'), findsOneWidget);

    // "Otro motivo" exige detalle: el pie dice exactamente qué falta.
    await tester.tap(find.text('Otro motivo'));
    await tester.pumpAndSettle();
    expect(
      find.text('Este motivo necesita que escribas el detalle.'),
      findsOneWidget,
    );
  });

  testWidgets('sin catálogo de razones no se ofrece capturarla', (
    tester,
  ) async {
    final port = FakePipelinePort()..catalogoDisponible = false;
    await pintar(tester, const Size(390, 900), port: port);
    await tester.tap(find.text('Tarjetas'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('¿Por qué no avanzó?'), findsNothing);
  });

  testWidgets('un fallo del backend deja un error con reintento, no una pantalla en blanco', (
    tester,
  ) async {
    final port = FakePipelinePort()
      ..proximoFallo = ApiError(0, 'network_error');
    await pintar(tester, const Size(390, 900), port: port);

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
