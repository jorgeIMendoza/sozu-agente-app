import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/etiquetas_prospecto.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Catálogo de respaldo de estados de lead del servidor
/// (`ESTADOS_LEAD_FALLBACK` en `agente-prospectos/index.ts`), que es también el
/// catálogo que la plataforma trae de fábrica.
///
/// El catálogo REAL es administrable en runtime, así que un estado nuevo puede
/// aparecer sin tocar el app y caería en gris. Esta lista es el contrato mínimo:
/// si alguien agrega una clave aquí (o la quita de un set de tonos), la prueba
/// avisa en vez de dejarla salir sin significado.
const _catalogoDeRespaldo = <String>[
  'nuevo',
  'en_curso',
  'negocio_abierto',
  'sin_calificar',
  'intento_contacto',
  'conectado',
  'programo_cita',
  'asistio_cita',
  'fuera_presupuesto',
  'compra_futura',
  'sin_respuesta_7',
  'tiempo_entrega',
  'asesor_inmobiliario',
  'registro_error',
  'proveedor',
  'fuera_area',
];

void main() {
  group('tono de los estados de lead', () {
    test('cada clave del catálogo del servidor tiene tono propio', () {
      for (final clave in _catalogoDeRespaldo) {
        expect(
          toneDeEstadoLead(clave),
          isNot(SBadgeTone.neutral),
          reason:
              '"$clave" no está en ninguno de los tres sets de '
              'etiquetas_prospecto.dart y saldría en gris',
        );
      }
    });

    test('una clave desconocida o ausente cae en gris, sin reventar', () {
      expect(toneDeEstadoLead(null), SBadgeTone.neutral);
      expect(toneDeEstadoLead('estado_inventado'), SBadgeTone.neutral);
    });
  });

  group('tono de las etapas del pipeline', () {
    test('a partir del apartado pagado la unidad ya es una compra', () {
      expect(toneDeEtapa('apartado_pagado'), SBadgeTone.positive);
      expect(toneDeEtapa('enganche_contrato'), SBadgeTone.positive);
      expect(toneDeEtapa('ganado'), SBadgeTone.positive);
      expect(toneDeEtapa('perdido'), SBadgeTone.negative);
      expect(toneDeEtapa('oferta_enviada'), SBadgeTone.pending);
      expect(toneDeEtapa('nuevo'), SBadgeTone.neutral);
    });
  });
}
