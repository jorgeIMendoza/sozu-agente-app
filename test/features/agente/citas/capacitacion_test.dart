import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/citas/adapters/citas_adapter.dart';
import 'package:sozu_agente_app/features/agente/citas/ports/citas_port.dart';
import 'package:sozu_agente_app/features/agente/citas/providers/citas_providers.dart';
import 'package:sozu_agente_app/features/agente/citas/services/agenda_de_capacitacion.dart';
import 'package:sozu_agente_app/features/agente/inventario/providers/inventario_providers.dart';

import '../agente_test_support.dart';
import '../inventario/fake_inventario_port.dart';
import 'fake_citas_port.dart';

/// La capacitación del agente contra el PUERTO: el mapeo de su disponibilidad,
/// el cuerpo que viaja al servidor (sin la identidad del agente) y las dos
/// formas de éxito del "Ya acudí".
void main() {
  /// Contenedor con el inventario falso (desarrollos 7 y 9) y el puerto de
  /// citas falso, que es de donde sale la agenda de capacitación.
  ProviderContainer makeContainer(FakeCitasPort port) => makeClientContainer(
    overrides: [
      citasPortProvider.overrideWithValue(port),
      inventarioPortProvider.overrideWithValue(FakeInventarioPort()),
    ],
  );

  group('disponibilidad de capacitación', () {
    test(
      'mapea el contrato y pregunta por cada desarrollo del agente',
      () async {
        final port = FakeCitasPort();
        final container = makeContainer(port);

        final agenda = await container.read(
          agendaDeCapacitacionProvider.future,
        );

        // Un desarrollo asignado, una llamada: la capacitación cuelga de la
        // configuración y preguntar por uno solo esconde cupos.
        expect(port.log, [
          'disponibilidad_capacitacion:7',
          'disponibilidad_capacitacion:9',
        ]);
        expect(agenda.dias.map((d) => d.fecha), ['2026-09-03']);

        final cupos = agenda.dias.single.horarios;
        expect(cupos.map((h) => h.hora), [11, 13]);
        expect(cupos.first.etiqueta, '11:00');
        expect(cupos.first.idConfiguracion, 42);
        expect(cupos.first.configuracion, 'Capacitación PV');
        expect(cupos.first.responsable, 'Mora Salas');
        expect(cupos.first.idTipoCita, kTipoCitaCapacitacion);
        expect(cupos.first.duracionMinutos, 60);
      },
    );

    test('el mismo cupo en dos desarrollos se pinta una vez', () async {
      final port = FakeCitasPort()
        // Los dos desarrollos cuelgan de la misma configuración: el servidor
        // repite el cupo tantas veces como desarrollos tenga el agente.
        ..payloadCapacitacionPorDesarrollo[9] = {
          'fechas': [
            {
              'fecha': '2026-09-03',
              'slots': [
                {'hora': 11, 'id_configuracion_cita': 42},
                {'hora': 9, 'id_configuracion_cita': 55},
              ],
            },
            {
              'fecha': '2026-09-01',
              'slots': [
                {'hora': 16, 'id_configuracion_cita': 55},
              ],
            },
          ],
          'slots': null,
        };
      final container = makeContainer(port);

      final agenda = await container.read(agendaDeCapacitacionProvider.future);

      // Las fechas quedan en orden aunque el segundo desarrollo traiga una
      // anterior, y el cupo repetido (config 42 a las 11) no se duplica.
      expect(agenda.dias.map((d) => d.fecha), ['2026-09-01', '2026-09-03']);
      final tercero = agenda.dias.last.horarios;
      expect(tercero.map((h) => (h.hora, h.idConfiguracion)), [
        (9, 55),
        (11, 42),
        (13, 42),
      ]);
      // Cada configuración recuerda de qué desarrollo salió: es el `id_proyecto`
      // del agendado.
      expect(agenda.desarrolloPorConfiguracion, {42: 7, 55: 9});
    });

    test('sin desarrollos asignados la agenda queda vacía', () async {
      final port = FakeCitasPort();
      final container = makeClientContainer(
        overrides: [
          citasPortProvider.overrideWithValue(port),
          inventarioPortProvider.overrideWithValue(
            FakeInventarioPort()..sinAcceso = true,
          ),
        ],
      );

      final agenda = await container.read(agendaDeCapacitacionProvider.future);

      expect(agenda.vacia, isTrue);
      expect(agenda.dia('2026-09-03'), isNull);
      // Sin desarrollos no hay a qué agenda preguntarle.
      expect(port.log, isEmpty);
    });
  });

  group('agendar_capacitacion', () {
    test('NO manda la identidad del agente', () {
      final cuerpo = cuerpoAgendarCapacitacion(
        const SolicitudDeCapacitacion(
          fecha: '2026-09-03',
          hora: '11:00',
          idConfiguracion: 42,
          idDesarrollo: 17,
        ),
      );

      expect(cuerpo, {
        'action': 'agendar_capacitacion',
        'fecha': '2026-09-03',
        'hora': '11:00',
        'id_configuracion': 42,
        'id_proyecto': 17,
      });
      // La identidad la deriva el servidor del JWT: mandarla desde el app sería
      // la vía para agendarle la capacitación a otro agente.
      for (final prohibido in const [
        'id_persona',
        'id_agente',
        'email',
        'agent_email',
        'auth_user_id',
      ]) {
        expect(cuerpo.containsKey(prohibido), isFalse, reason: prohibido);
      }
    });

    test('sin desarrollo no manda id_proyecto', () {
      final cuerpo = cuerpoAgendarCapacitacion(
        const SolicitudDeCapacitacion(
          fecha: '2026-09-03',
          hora: '11:00',
          idConfiguracion: 42,
        ),
      );

      expect(cuerpo.containsKey('id_proyecto'), isFalse);
    });

    test('la cita agendada lee el enlace de la fila cruda', () async {
      final port = FakeCitasPort();

      final cita = await port.agendarCapacitacion(
        const SolicitudDeCapacitacion(
          fecha: '2026-09-03',
          hora: '11:00',
          idConfiguracion: 42,
        ),
      );

      expect(cita.idCita, 4321);
      expect(cita.fecha, '2026-09-03');
      expect(cita.horaInicio, '11:00:00');
      // `meet_link` viene nulo en la raíz: el enlace está en la propia fila.
      expect(cita.enlaceReunion, 'https://meet.google.com/abc-defg-hij');
    });
  });

  group('reportar_asistencia', () {
    test('éxito con reporte nuevo', () {
      final reporte = AsistenciaReportada.desdeJson(const {
        'ok': true,
        'id': 4455,
        'pendiente_confirmacion': true,
      });

      expect(reporte.idCita, 4455);
      expect(reporte.yaReportada, isFalse);
      expect(reporte.pendienteDeConfirmacion, isTrue);
    });

    test('éxito cuando ya existía una del mismo día', () {
      final reporte = AsistenciaReportada.desdeJson(const {
        'ok': true,
        'ya_reportada': true,
      });

      // La otra forma de éxito no trae id: es idempotente por día.
      expect(reporte.yaReportada, isTrue);
      expect(reporte.idCita, isNull);
      expect(reporte.pendienteDeConfirmacion, isFalse);
    });

    test('el puerto recibe la fecha y devuelve las dos formas', () async {
      final port = FakeCitasPort();

      final nueva = await port.reportarAsistencia('2026-09-03');
      port.asistenciaYaReportada = true;
      final repetida = await port.reportarAsistencia('2026-09-03');

      expect(port.ultimaFechaDeAsistencia, '2026-09-03');
      expect(nueva.yaReportada, isFalse);
      expect(nueva.idCita, 4455);
      expect(repetida.yaReportada, isTrue);
      expect(repetida.idCita, isNull);
    });
  });

  test('la fusión conserva el desarrollo del primer cupo de cada agenda', () {
    final agenda = fusionarAgendaDeCapacitacion({
      7: const [
        DiaDisponible(
          fecha: '2026-09-03',
          horarios: [
            HorarioDisponible(hora: 11, etiqueta: '11:00', idConfiguracion: 42),
          ],
        ),
        // Día sin cupos: no llega al calendario.
        DiaDisponible(fecha: '2026-09-04'),
      ],
      9: const [
        DiaDisponible(
          fecha: '2026-09-03',
          horarios: [
            HorarioDisponible(hora: 11, etiqueta: '11:00', idConfiguracion: 42),
          ],
        ),
      ],
    });

    expect(agenda.dias.length, 1);
    expect(agenda.dia('2026-09-03')!.horarios.length, 1);
    expect(agenda.desarrolloPorConfiguracion, {42: 7});
  });
}
