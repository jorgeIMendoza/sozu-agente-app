import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/features/agente/comisiones/providers/comisiones_providers.dart';
import 'package:sozu_agente_app/features/agente/comisiones/screens/comisiones_screen.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import 'fake_comisiones_port.dart';
import 'fake_telemetria_port.dart';

/// Telemetría de Comisiones. Los identificadores son los MISMOS que manda el
/// portal web (`/admin/agent/comisiones`, `agent_comisiones`, ...): si cambian,
/// el tablero de CTA queda partido entre web y app.
void main() {
  Future<FakeTelemetriaPort> pintar(
    WidgetTester tester, {
    Map<String, dynamic>? payload,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);

    final telemetria = FakeTelemetriaPort();
    final port = FakeComisionesPort();
    if (payload != null) port.payload = payload;

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ComisionesScreen()),
        GoRoute(
          path: '/perfil',
          builder: (_, _) => const Scaffold(body: Text('Perfil del agente')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [
            comisionesPortProvider.overrideWithValue(port),
            telemetriaPortProvider.overrideWithValue(telemetria),
          ],
        ),
        child: MaterialApp.router(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return telemetria;
  }

  testWidgets('al montar registra la vista y el page_view', (tester) async {
    final telemetria = await pintar(tester);

    expect(telemetria.vistas, ['/admin/agent/comisiones']);
    final cta = telemetria.ctas.single;
    expect(cta.pagina, 'agent_comisiones');
    expect(cta.elementoId, 'page_view');
    expect(cta.tipo, 'page');
  });

  testWidgets('el CTA de la factura manda el folio de la cuenta y nada más', (
    tester,
  ) async {
    final telemetria = await pintar(tester);

    // La comisión facturable queda bajo el pliegue: hay que llegar a ella.
    final boton = find.text('Subir factura');
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();

    final cta = telemetria.ctas.last;
    expect(cta.pagina, 'agent_comisiones');
    expect(cta.elementoId, 'btn_subir_factura_agent');
    expect(cta.etiqueta, 'Subir factura (PDF)');
    // `cuentaId` en camelCase, igual que la web. Y NADA más: ni montos, ni
    // nombres, ni correos.
    expect(cta.metadata, {'cuentaId': 102});
  });

  testWidgets('el CTA del bloqueo se registra y lleva al perfil', (
    tester,
  ) async {
    final telemetria = await pintar(
      tester,
      payload: FakeComisionesPort.payloadBloqueado(),
    );

    expect(
      find.text('Completa tu perfil para ver y recibir comisiones.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Completar perfil'));
    await tester.pumpAndSettle();

    final cta = telemetria.ctas.last;
    expect(cta.elementoId, 'btn_completar_perfil_comisiones');
    expect(cta.etiqueta, 'Completar perfil');
    expect(cta.metadata, isEmpty);
    expect(find.text('Perfil del agente'), findsOneWidget);
  });
}
