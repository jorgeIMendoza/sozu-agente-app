import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/citas/components/agendar_cita_hoja.dart';
import 'package:sozu_agente_app/features/agente/citas/ports/citas_port.dart';
import 'package:sozu_agente_app/features/agente/citas/providers/citas_providers.dart';
import 'package:sozu_agente_app/features/agente/citas/services/seleccion_de_cita.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import '../prospectos/fake_prospectos_port.dart';
import 'fake_citas_port.dart';

/// La hoja de agendado se pinta y se recorre de verdad: es la red que atrapa lo
/// que los tests de providers no ven (un cupo que no se puede tocar, un botón
/// que se habilita sin datos, un estado vacío que no aparece).
void main() {
  /// Prospecto con un solo desarrollo: la hoja lo resuelve sola, como el modal
  /// web, y se salta el selector de desarrollo.
  const prospecto = ProspectoParaCita(
    idPersona: 11,
    nombre: 'Ana Torres',
    desarrollos: [DesarrolloParaCita(id: 7, nombre: 'Margot')],
  );

  Future<CitaAgendada?> abrir(
    WidgetTester tester, {
    required FakeCitasPort port,
    ProspectoParaCita? conProspecto = prospecto,
    DesarrolloParaCita? conDesarrollo,
    bool reagendar = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.reset);

    CitaAgendada? resultado;
    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [
            citasPortProvider.overrideWithValue(port),
            prospectosPortProvider.overrideWithValue(FakeProspectosPort()),
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
                  resultado = await mostrarAgendarCita(
                    context,
                    prospecto: conProspecto,
                    desarrollo: conDesarrollo,
                    reagendar: reagendar,
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

  testWidgets('con el prospecto precargado ofrece fechas y cupos', (
    tester,
  ) async {
    await abrir(tester, port: FakeCitasPort());

    expect(find.text('Agendar cita'), findsWidgets);
    // El prospecto y su único desarrollo llegan resueltos.
    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('Margot'), findsOneWidget);
    // Fechas con cupo, rotuladas en español.
    expect(find.text('vie 21 ago'), findsOneWidget);
    expect(find.text('lun 24 ago'), findsOneWidget);
    // Los horarios solo aparecen tras elegir la fecha.
    expect(find.text('10:00'), findsNothing);
  });

  testWidgets('elegir fecha muestra los cupos agrupados por agenda', (
    tester,
  ) async {
    await abrir(tester, port: FakeCitasPort());

    await tester.tap(find.text('vie 21 ago'));
    await tester.pumpAndSettle();

    expect(find.textContaining('viernes 21 de agosto'), findsOneWidget);
    expect(find.text('Showroom Reforma'), findsOneWidget);
    expect(find.text('Visita en obra'), findsOneWidget);
    expect(find.text('Responsable: Ana Torres'), findsOneWidget);
    // Las dos agendas tienen cupo a las 10: son dos pastillas distintas.
    expect(find.text('10:00'), findsNWidgets(2));
  });

  testWidgets('el cupo elegido se manda con su configuración', (tester) async {
    final port = FakeCitasPort();
    await abrir(tester, port: port);

    await tester.tap(find.text('vie 21 ago'));
    await tester.pumpAndSettle();
    // La segunda pastilla de las 10:00 es la de la otra agenda.
    await tester.tap(find.text('10:00').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendar cita').last);
    await tester.pumpAndSettle();

    expect(port.log, ['disponibilidad:7', 'agendar']);
    expect(port.ultimaSolicitud?.idConfiguracion, 9);
    expect(port.ultimaSolicitud?.fecha, '2026-08-21');
    expect(port.ultimaSolicitud?.horaInicio, '10:00');
    expect(port.ultimaSolicitud?.idPersonaProspecto, 11);
    expect(port.ultimaSolicitud?.idDesarrollo, 7);
  });

  testWidgets('sin cupo elegido no se puede agendar', (tester) async {
    final port = FakeCitasPort();
    await abrir(tester, port: port);

    await tester.tap(find.text('Agendar cita').last);
    await tester.pumpAndSettle();

    expect(port.log, ['disponibilidad:7']);
  });

  testWidgets('un desarrollo sin horarios abiertos lo dice y no ofrece nada', (
    tester,
  ) async {
    final port = FakeCitasPort()
      ..payloadDisponibilidad = {'fechas': <Map<String, dynamic>>[]};

    await abrir(tester, port: port);

    expect(find.text('Sin fechas disponibles'), findsOneWidget);
  });

  testWidgets('si la disponibilidad falla, ofrece reintentar', (tester) async {
    final port = FakeCitasPort()..proximoFallo = ApiError(0, 'network_error');

    await abrir(tester, port: port);

    expect(find.text('No pudimos cargar los horarios'), findsOneWidget);
    expect(find.text('Revisa tu conexión e intenta de nuevo.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('vie 21 ago'), findsOneWidget);
  });

  testWidgets('el fallo al agendar se queda en la hoja con su motivo', (
    tester,
  ) async {
    final port = FakeCitasPort();
    await abrir(tester, port: port);

    await tester.tap(find.text('vie 21 ago'));
    await tester.pumpAndSettle();
    port.proximoFallo = ApiError(409, 'no_disponible');
    await tester.tap(find.text('10:00').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendar cita').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Ese horario acaba de ocuparse. Elige otro.'),
      findsOneWidget,
    );
  });

  testWidgets('reagendar cambia los textos y la acción del servidor', (
    tester,
  ) async {
    final port = FakeCitasPort();
    await abrir(tester, port: port, reagendar: true);

    expect(find.text('Reagendar cita'), findsOneWidget);

    await tester.tap(find.text('vie 21 ago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reagendar'));
    await tester.pumpAndSettle();

    expect(port.log.last, 'reagendar');
  });

  testWidgets('con solo el desarrollo precargado, el prospecto se elige', (
    tester,
  ) async {
    final port = FakeCitasPort();
    await abrir(
      tester,
      port: port,
      conProspecto: null,
      conDesarrollo: const DesarrolloParaCita(id: 7, nombre: 'Margot'),
    );

    // El desarrollo queda fijo y la cartera del agente alimenta el selector.
    expect(find.text('Margot'), findsOneWidget);
    expect(find.text('Elige a tu prospecto'), findsOneWidget);
    // Con el desarrollo resuelto la disponibilidad ya se puede pedir.
    expect(port.log, ['disponibilidad:7']);
    expect(find.text('vie 21 ago'), findsOneWidget);
  });
}
