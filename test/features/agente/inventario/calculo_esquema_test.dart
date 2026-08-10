import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/features/agente/inventario/services/calculo_esquema.dart';

/// Aritmética de los esquemas de pago. Es la misma que firma el cliente en la
/// oferta digital: si estos números se mueven, el agente cotiza distinto de lo
/// que emite el sistema.
void main() {
  EsquemaPago esquema(Map<String, dynamic> extra) => EsquemaPago.fromJson({
    'id': 1,
    'id_proyecto': 7,
    'nombre': 'Prueba',
    'porcentaje_descuento_aumento': '0',
    'porcentaje_enganche': '20',
    'porcentaje_mensualidades': '30',
    'numero_mensualidades': 30,
    'porcentaje_entrega': '50',
    'es_manual': false,
    ...extra,
  });

  group('esquema por porcentajes', () {
    test('sin meses efectivos usa los valores guardados', () {
      final m = montosDeEsquema(esquema(const {}), 1000000);

      expect(m.precioFinal, 1000000);
      expect(m.enganche, 200000);
      expect(m.meses, 30);
      expect(m.mensualidad, closeTo(10000, 0.01));
      expect(m.mensualidadesTotal, closeTo(300000, 0.01));
      expect(m.porcentajeMensualidades, closeTo(30, 0.001));
      expect(m.porcentajeEntrega, closeTo(50, 0.001));
    });

    test('al acortarse el plazo la mensualidad NO cambia y la entrega absorbe', () {
      final m = montosDeEsquema(esquema(const {}), 1000000, mesesEfectivos: 10);

      expect(m.meses, 10);
      // El monto mensual sigue saliendo del plazo ORIGINAL (30 meses).
      expect(m.mensualidad, closeTo(10000, 0.01));
      expect(m.mensualidadesTotal, closeTo(100000, 0.01));
      expect(m.porcentajeMensualidades, closeTo(10, 0.001));
      expect(m.porcentajeEntrega, closeTo(70, 0.001));
      expect(m.entrega, closeTo(700000, 0.01));
    });

    test('nunca se estira más allá del plazo pactado', () {
      final m = montosDeEsquema(esquema(const {}), 1000000, mesesEfectivos: 90);
      expect(m.meses, 30);
    });

    test('un esquema sin mensualidades ignora la fecha de entrega', () {
      final m = montosDeEsquema(
        esquema(const {
          'porcentaje_mensualidades': '0',
          'numero_mensualidades': 0,
          'porcentaje_entrega': '80',
        }),
        1000000,
        mesesEfectivos: 12,
      );

      expect(m.meses, 0);
      expect(m.porcentajeEntrega, closeTo(80, 0.001));
      expect(m.entrega, closeTo(800000, 0.01));
    });

    test('el descuento se aplica al precio antes de repartir', () {
      final m = montosDeEsquema(
        esquema(const {'porcentaje_descuento_aumento': '-10'}),
        1000000,
      );

      expect(m.precioFinal, closeTo(900000, 0.01));
      expect(m.enganche, closeTo(180000, 0.01));
    });
  });

  group('escalonado con monto fijo', () {
    /// Los tramos guardan el monto en CENTAVOS: 1,500,000 = $15,000.
    final conTramos = esquema(const {
      'porcentaje_mensualidades': '0',
      'numero_mensualidades': 0,
      'porcentaje_entrega': '0',
      'tramos_mensualidad': [
        {'monto_mensualidad': 1500000, 'numero_mensualidades': 12},
        {'monto_mensualidad': 2000000, 'numero_mensualidades': 6},
      ],
    });

    test('se detecta por los tramos, no por los porcentajes', () {
      expect(conTramos.esEscalonadoMontoFijo, isTrue);
      expect(esquema(const {}).esEscalonadoMontoFijo, isFalse);
    });

    test('sin fecha de entrega conserva los tramos definidos', () {
      final m = montosDeEsquema(conTramos, 1000000);

      expect(m.meses, 18);
      // 12 x 15,000 + 6 x 20,000 = 300,000.
      expect(m.mensualidadesTotal, closeTo(300000, 0.01));
      expect(m.mensualidad, closeTo(300000 / 18, 0.01));
      expect(m.entrega, closeTo(1000000 - 200000 - 300000, 0.01));
    });

    test('con fecha de entrega recalcula con el monto fijo del primer tramo', () {
      final m = montosDeEsquema(conTramos, 1000000, mesesEfectivos: 24);

      expect(m.meses, 24);
      expect(m.mensualidad, closeTo(15000, 0.01));
      expect(m.mensualidadesTotal, closeTo(360000, 0.01));
      expect(m.entrega, closeTo(440000, 0.01));
    });

    test('un esquema manual conserva sus tramos aunque haya fecha', () {
      final manual = esquema(const {
        'es_manual': true,
        'tramos_mensualidad': [
          {'monto_mensualidad': 1500000, 'numero_mensualidades': 12},
        ],
      });

      final m = montosDeEsquema(manual, 1000000, mesesEfectivos: 24);
      expect(m.meses, 12);
      expect(m.mensualidadesTotal, closeTo(180000, 0.01));
    });

    test('la entrega nunca es negativa', () {
      final caro = esquema(const {
        'tramos_mensualidad': [
          {'monto_mensualidad': 9000000, 'numero_mensualidades': 30},
        ],
      });

      final m = montosDeEsquema(caro, 1000000);
      expect(m.entrega, 0);
      expect(m.porcentajeEntrega, 0);
    });

    test('un tramo con fecha límite recalcula sus mensualidades', () {
      final conLimite = esquema(const {
        'tramos_mensualidad': [
          {
            'monto_mensualidad': 1000000,
            'numero_mensualidades': 99,
            'fecha_limite': '2026-12-01',
          },
        ],
      });

      final tramos = tramosResueltos(
        conLimite.tramos,
        referencia: DateTime(2026, 6, 1),
      );
      expect(tramos.single.numeroMensualidades, 6);
    });
  });

  group('mensualidades restantes', () {
    test('descuenta el mes de entrega, que es el pago a escrituración', () {
      final meses = mesesMensualidadesRestantes(
        '2027-06-30',
        desde: DateTime(2026, 6, 15),
      );
      expect(meses, 11);
    });

    test('una entrega pasada no deja mensualidades', () {
      expect(
        mesesMensualidadesRestantes('2020-01-01', desde: DateTime(2026, 6, 1)),
        0,
      );
      expect(mesesMensualidadesRestantes(null), 0);
      expect(mesesMensualidadesRestantes('no es fecha'), 0);
    });
  });
}
