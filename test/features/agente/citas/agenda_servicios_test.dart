import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/citas/services/seleccion_de_cita.dart';
import 'package:sozu_agente_app/features/agente/citas/services/textos_de_agenda.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Las dos piezas sin UI del agendado: de dónde sale a quién se puede citar y
/// qué lee el agente cuando algo falla o hay que rotular una fecha.
void main() {
  group('selección', () {
    test('la cartera se vuelve prospectos citables, ordenados por nombre', () {
      final cartera = [
        Prospecto.fromJson({
          'id_persona': 12,
          'nombre': 'bruno díaz',
          'proyectos': [
            {
              'id_entidad_relacionada': 1,
              'id_proyecto': 9,
              'proyecto': 'Torre',
            },
          ],
        }),
        Prospecto.fromJson({
          'id_persona': 11,
          'nombre': 'Ana Torres',
          'proyectos': [
            {
              'id_entidad_relacionada': 2,
              'id_proyecto': 7,
              'proyecto': 'Margot',
            },
          ],
        }),
      ];

      final lista = prospectosParaCita(cartera);

      expect(lista.map((p) => p.idPersona), [11, 12]);
    });

    test('el mismo desarrollo repetido se cuenta una vez', () {
      final cartera = [
        Prospecto.fromJson({
          'id_persona': 11,
          'nombre': 'Ana',
          'proyectos': [
            {
              'id_entidad_relacionada': 1,
              'id_proyecto': 7,
              'proyecto': 'Margot',
            },
            {
              'id_entidad_relacionada': 2,
              'id_proyecto': 7,
              'proyecto': 'Margot',
            },
          ],
        }),
      ];

      expect(prospectosParaCita(cartera).single.desarrollos.length, 1);
    });

    test(
      'un desarrollo sin id se descarta: no hay agenda a la que pedirle',
      () {
        final cartera = [
          Prospecto.fromJson({
            'id_persona': 11,
            'nombre': 'Ana',
            'proyectos': [
              {'id_entidad_relacionada': 1, 'proyecto': 'Sin id'},
            ],
          }),
        ];

        expect(prospectosParaCita(cartera).single.desarrollos, isEmpty);
      },
    );

    test('los desarrollos de una ficha llegan listos para el selector', () {
      final desarrollos = [
        DesarrolloDeInteres.fromJson({
          'id': 101,
          'id_proyecto': 7,
          'nombre': 'Margot',
        }),
        DesarrolloDeInteres.fromJson({'id': 102, 'nombre': 'Sin id'}),
      ];

      final lista = desarrollosDeFicha(desarrollos);

      expect(lista.single.id, 7);
      expect(lista.single.nombre, 'Margot');
    });
  });

  group('textos', () {
    test('la fecha se rotula corta y larga en español', () {
      expect(etiquetaDiaCorto('2026-08-21'), 'vie 21 ago');
      expect(etiquetaDiaLargo('2026-08-21'), 'viernes 21 de agosto');
    });

    test('una fecha inválida no revienta el rótulo', () {
      expect(etiquetaDiaCorto(null), '-');
      expect(etiquetaDiaLargo('2026-13'), '-');
    });

    test(
      'la fecha se ancla al mediodía y vuelve a ISO sin correrse de día',
      () {
        final d = fechaDeAgenda('2026-08-21T00:00:00Z');

        expect(d?.hour, 12);
        expect(isoDeFecha(d!), '2026-08-21');
      },
    );

    test('los códigos del servidor se traducen a algo accionable', () {
      expect(
        mensajeErrorAgenda(ApiError(409, 'no_disponible')),
        'Ese horario acaba de ocuparse. Elige otro.',
      );
      expect(
        mensajeErrorAgenda(ApiError(403, 'not_owner')),
        'Este prospecto no está en tu cartera.',
      );
      // Un código nuevo del backend cae en el genérico, nunca se muestra crudo.
      expect(
        mensajeErrorAgenda(ApiError(500, 'algo_nuevo')),
        'No pudimos agendar la cita. Intenta de nuevo.',
      );
      expect(
        mensajeErrorAgenda(Exception('boom')),
        'Ocurrió un problema inesperado. Intenta de nuevo.',
      );
    });
  });
}
