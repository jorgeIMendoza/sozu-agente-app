import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/citas/components/agendar_capacitacion_hoja.dart';
import 'package:sozu_agente_app/features/agente/citas/providers/citas_providers.dart';
import 'package:sozu_agente_app/features/agente/citas/services/textos_de_agenda.dart';
import 'package:sozu_agente_app/features/agente/inventario/providers/inventario_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import '../inventario/fake_inventario_port.dart';
import 'fake_citas_port.dart';

/// La hoja de capacitación se recorre de verdad: el segmentado, el cupo que
/// viaja con su configuración y su desarrollo, y el "Ya acudí".
void main() {
  Future<ResultadoDeCapacitacion?> abrir(
    WidgetTester tester, {
    required FakeCitasPort port,
    bool reportarAsistencia = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.reset);

    ResultadoDeCapacitacion? resultado;
    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [
            citasPortProvider.overrideWithValue(port),
            inventarioPortProvider.overrideWithValue(FakeInventarioPort()),
          ],
        ),
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  resultado = await mostrarAgendarCapacitacion(
                    context,
                    reportarAsistencia: reportarAsistencia,
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return resultado;
  }

  testWidgets('abre en Agendar y ofrece las fechas con cupo', (tester) async {
    await abrir(tester, port: FakeCitasPort());

    expect(find.text('Agendar cita'), findsWidgets);
    expect(find.text('Ya acudí'), findsOneWidget);
    expect(find.text('jue 3 sep'), findsOneWidget);
    // Los horarios solo aparecen tras elegir la fecha.
    expect(find.text('11:00'), findsNothing);
  });

  testWidgets('el cupo elegido viaja con su configuración y su desarrollo', (
    tester,
  ) async {
    final port = FakeCitasPort();
    final resultado = await abrir(tester, port: port);
    expect(resultado, isNull);

    await tester.tap(find.text('jue 3 sep'));
    await tester.pumpAndSettle();
    expect(find.text('Capacitación PV'), findsOneWidget);
    expect(find.text('Responsable: Mora Salas'), findsOneWidget);

    await tester.tap(find.text('13:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SButton, 'Agendar cita').last);
    await tester.pumpAndSettle();

    final solicitud = port.ultimaCapacitacion!;
    expect(solicitud.fecha, '2026-09-03');
    expect(solicitud.hora, '13:00');
    expect(solicitud.idConfiguracion, 42);
    // El desarrollo sale de la fusión: es el `id_proyecto` del agendado.
    expect(solicitud.idDesarrollo, 7);
    expect(port.log, contains('agendar_capacitacion'));
  });

  testWidgets('sin cupo elegido no se puede agendar', (tester) async {
    final port = FakeCitasPort();
    await abrir(tester, port: port);

    await tester.tap(find.widgetWithText(SButton, 'Agendar cita').last);
    await tester.pumpAndSettle();

    expect(port.log, isNot(contains('agendar_capacitacion')));
  });

  testWidgets('el cupo tomado se dice en la hoja y no la cierra', (
    tester,
  ) async {
    final port = FakeCitasPort();
    await abrir(tester, port: port);

    await tester.tap(find.text('jue 3 sep'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('11:00'));
    await tester.pumpAndSettle();
    port.proximoFallo = ApiError(409, 'no_disponible');
    await tester.tap(find.widgetWithText(SButton, 'Agendar cita').last);
    await tester.pumpAndSettle();

    expect(find.text('Ese horario acaba de ocuparse. Elige otro.'), findsOne);
  });

  testWidgets('el segmentado cambia a "Ya acudí"', (tester) async {
    await abrir(tester, port: FakeCitasPort());

    await tester.tap(find.text('Ya acudí'));
    await tester.pumpAndSettle();

    expect(find.text('¿En qué fecha acudiste? *'), findsOneWidget);
    expect(find.text('Elegir la fecha'), findsOneWidget);
    expect(find.textContaining('pendiente de que un administrador'), findsOne);
    // Ya no se ofrece el calendario de cupos.
    expect(find.text('jue 3 sep'), findsNothing);
  });

  testWidgets('reportar la asistencia manda la fecha elegida', (tester) async {
    final port = FakeCitasPort();
    final hoy = DateTime.now();
    await abrir(tester, port: port, reportarAsistencia: true);

    // El selector abre en hoy: confirmar sin moverlo reporta la fecha de hoy.
    await tester.tap(find.text('Elegir la fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SButton, 'Reportar'));
    await tester.pumpAndSettle();

    expect(port.ultimaFechaDeAsistencia, isoDeFecha(hoy));
    expect(port.log, contains('reportar_asistencia:${isoDeFecha(hoy)}'));
  });
}
