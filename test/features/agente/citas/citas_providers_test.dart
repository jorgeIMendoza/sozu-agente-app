import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/citas/adapters/citas_adapter.dart';
import 'package:sozu_agente_app/features/agente/citas/ports/citas_port.dart';
import 'package:sozu_agente_app/features/agente/citas/providers/citas_providers.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

import '../agente_test_support.dart';
import '../prospectos/fake_prospectos_port.dart';
import 'fake_citas_port.dart';

/// La agenda contra el PUERTO (sin Supabase): el mapeo del contrato de
/// `agente-citas`, el universo de a quién se puede citar y la reconstrucción del
/// puerto al cambiar de agente impersonado - si eso último se rompe, un
/// administrador agenda con la disponibilidad de otro agente.
void main() {
  test('la disponibilidad mapea fechas y cupos del contrato', () async {
    final port = FakeCitasPort();
    final container = makeClientContainer(
      overrides: [citasPortProvider.overrideWithValue(port)],
    );

    final dias = await container.read(disponibilidadProvider(7).future);

    // El día sin cupos no llega a la pantalla.
    expect(dias.map((d) => d.fecha), ['2026-08-21', '2026-08-24']);
    expect(port.log, ['disponibilidad:7']);

    final primero = dias.first;
    expect(primero.horarios.length, 2);
    // Dos agendas a la misma hora: lo que las distingue es la configuración.
    expect(primero.horarios.map((h) => h.hora), [10, 10]);
    expect(primero.horarios.map((h) => h.idConfiguracion), [7, 9]);
    expect(primero.horarios.first.configuracion, 'Showroom Reforma');
    expect(primero.horarios.first.responsable, 'Ana Torres');
    expect(primero.horarios.first.idTipoCita, 2);
    expect(primero.horarios.first.duracionMinutos, 60);
  });

  test('sin hora_label el cupo arma su etiqueta con la hora', () async {
    final container = makeClientContainer(
      overrides: [citasPortProvider.overrideWithValue(FakeCitasPort())],
    );

    final dias = await container.read(disponibilidadProvider(7).future);

    expect(dias.last.horarios.single.etiqueta, '09:00');
  });

  test('la disponibilidad se pide por desarrollo', () async {
    final port = FakeCitasPort();
    final container = makeClientContainer(
      overrides: [citasPortProvider.overrideWithValue(port)],
    );

    await container.read(disponibilidadProvider(7).future);
    await container.read(disponibilidadProvider(9).future);

    expect(port.log, ['disponibilidad:7', 'disponibilidad:9']);
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakeCitasPort()..proximoFallo = ApiError(0, 'network_error');
    final container = makeClientContainer(
      overrides: [citasPortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(disponibilidadProvider(7).future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'network_error')),
    );
  });

  test(
    'agendar y reagendar llevan el cupo elegido, sin tipo de cita',
    () async {
      final port = FakeCitasPort();
      final container = makeClientContainer(
        overrides: [citasPortProvider.overrideWithValue(port)],
      );
      const solicitud = SolicitudDeCita(
        idPersonaProspecto: 11,
        idDesarrollo: 7,
        fecha: '2026-08-21',
        horaInicio: '10:00',
        idConfiguracion: 9,
        notas: 'Viene acompañado',
      );

      final cita = await container.read(citasPortProvider).agendar(solicitud);
      await container.read(citasPortProvider).reagendar(solicitud);

      expect(port.log, ['agendar', 'reagendar']);
      expect(port.ultimaSolicitud?.idConfiguracion, 9);
      expect(port.ultimaSolicitud?.idPersonaProspecto, 11);
      expect(cita.idCita, 501);
      expect(cita.fecha, '2026-08-21');
    },
  );

  test('la cita agendada mapea id, meet y aviso del contrato', () {
    final cita = CitaAgendada.desdeJson({
      'ok': true,
      'cita': {
        'id': 77,
        'fecha': '2026-08-21',
        'hora_inicio': '10:00:00',
        'hora_fin': '11:00:00',
      },
      'meet_link': 'https://meet.google.com/abc-defg-hij',
      'aviso': 'El prospecto podría no recibir la invitación.',
    });

    expect(cita.idCita, 77);
    expect(cita.horaInicio, '10:00:00');
    expect(cita.enlaceReunion, 'https://meet.google.com/abc-defg-hij');
    expect(cita.aviso, 'El prospecto podría no recibir la invitación.');
  });

  test('sin cita en la respuesta el resultado degrada en vez de reventar', () {
    final cita = CitaAgendada.desdeJson({'ok': true});

    expect(cita.idCita, isNull);
    expect(cita.enlaceReunion, isNull);
  });

  test('los prospectos que se pueden citar salen de la cartera', () async {
    final container = makeClientContainer(
      overrides: [
        citasPortProvider.overrideWithValue(FakeCitasPort()),
        prospectosPortProvider.overrideWithValue(FakeProspectosPort()),
      ],
    );

    final lista = await container.read(prospectosParaCitaProvider.future);

    // Ordenados por nombre, igual que el diálogo del portal web.
    expect(lista.map((p) => p.nombre), ['Ana Torres', 'Bruno Díaz']);
    expect(lista.first.idPersona, 11);
    expect(lista.first.desarrollos.single.id, 7);
    expect(lista.first.desarrollos.single.nombre, 'Margot');
  });

  test('cambiar de agente impersonado reconstruye el puerto con su id', () {
    final container = makeClientContainer();

    final antes = container.read(citasPortProvider) as CitasAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante = container.read(citasPortProvider) as CitasAdapter;
    expect(durante.impersonate, 7);
    expect(identical(antes, durante), isFalse);

    container.read(impersonationProvider).clear();
    expect(
      (container.read(citasPortProvider) as CitasAdapter).impersonate,
      isNull,
    );
  });
}
