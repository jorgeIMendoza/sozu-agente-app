import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/features/agente/comisiones/providers/comisiones_providers.dart';

import '../agente_test_support.dart';
import 'fake_comisiones_port.dart';

/// Orden del listado: los comparadores (puros, sin UI ni backend) y el orden
/// aplicado sobre las comisiones ya filtradas. Los comparadores espejan los
/// `sortAccessor` de la tabla del portal web.
void main() {
  group('comparadores', () {
    test('el folio compara por el id de la cuenta', () {
      expect(
        OrdenComisiones.folio.comparar(_comision(id: 101), _comision(id: 102)),
        isNegative,
      );
    });

    test('proyecto y cliente comparan en minúsculas', () {
      // Sin bajar a minúsculas, 'Z' (90) iría antes que 'a' (97) y el listado
      // saldría partido en dos alfabetos.
      expect(
        OrdenComisiones.proyecto.comparar(
          _comision(proyecto: 'Zeta'),
          _comision(proyecto: 'alfa'),
        ),
        isPositive,
      );
      expect(
        OrdenComisiones.cliente.comparar(
          _comision(cliente: 'Zulema'),
          _comision(cliente: 'ana'),
        ),
        isPositive,
      );
    });

    test('la operación sin clientes queda al principio', () {
      expect(
        OrdenComisiones.cliente.comparar(
          _comision(),
          _comision(cliente: 'Ana'),
        ),
        isNegative,
      );
    });

    test('precio y monto comparan como números, no como texto', () {
      expect(
        OrdenComisiones.precioFinal.comparar(
          _comision(precio: 900000),
          _comision(precio: 4200000),
        ),
        isNegative,
      );
      expect(
        OrdenComisiones.montoComision.comparar(
          _comision(monto: 9000),
          _comision(monto: 126000),
        ),
        isNegative,
      );
    });

    test('la comisión sin fecha de pago vale cero', () {
      expect(
        OrdenComisiones.fechaPago.comparar(
          _comision(),
          _comision(fechaPago: '2026-07-24'),
        ),
        isNegative,
      );
      // Fecha ilegible = sin fecha: no revienta ni se cuela al final.
      expect(
        OrdenComisiones.fechaPago.comparar(
          _comision(fechaPago: 'no es fecha'),
          _comision(),
        ),
        isZero,
      );
    });

    test('cada llave trae su propio rótulo', () {
      final etiquetas = OrdenComisiones.values.map((o) => o.etiqueta).toSet();
      expect(etiquetas.length, OrdenComisiones.values.length);
      expect(etiquetas, isNot(contains('')));
    });
  });

  group('orden del listado', () {
    test('sin llave elegida manda el orden del backend', () async {
      final container = _container();
      await container.read(comisionesProvider.future);

      // Ni siquiera invertir la dirección lo mueve: sin llave no hay qué
      // invertir.
      container.read(ordenAscendenteProvider.notifier).state = false;

      expect(container.read(comisionesFiltradasProvider).map((c) => c.folio), [
        'CC-000101',
        'CC-000102',
        'CCP-000103',
      ]);
    });

    test('ordena por monto de comisión y la dirección lo invierte', () async {
      final container = _container();
      await container.read(comisionesProvider.future);

      container.read(ordenComisionesProvider.notifier).state =
          OrdenComisiones.montoComision;

      expect(container.read(comisionesFiltradasProvider).map((c) => c.folio), [
        'CCP-000103',
        'CC-000102',
        'CC-000101',
      ]);

      container.read(ordenAscendenteProvider.notifier).state = false;

      expect(container.read(comisionesFiltradasProvider).map((c) => c.folio), [
        'CC-000101',
        'CC-000102',
        'CCP-000103',
      ]);
    });

    test('ordena por cliente con el nombre del primer comprador', () async {
      final container = _container();
      await container.read(comisionesProvider.future);

      container.read(ordenComisionesProvider.notifier).state =
          OrdenComisiones.cliente;

      expect(container.read(comisionesFiltradasProvider).map((c) => c.folio), [
        'CCP-000103', // sin clientes
        'CC-000101', // Ana López
        'CC-000102', // Marta Díaz
      ]);
    });

    test('al empatar la llave se conserva el orden del backend', () async {
      final container = _container();
      await container.read(comisionesProvider.future);

      // Dos comisiones sin fecha de pago: empatan en 0 y deben quedar como
      // llegaron (102 antes de 103), como el `sort` estable de la web.
      container.read(ordenComisionesProvider.notifier).state =
          OrdenComisiones.fechaPago;

      expect(container.read(comisionesFiltradasProvider).map((c) => c.folio), [
        'CC-000102',
        'CCP-000103',
        'CC-000101',
      ]);
    });

    test('el orden se aplica sobre lo ya filtrado', () async {
      final container = _container();
      await container.read(comisionesProvider.future);

      container.read(filtroProyectoProvider.notifier).state = 'Margot';
      container.read(ordenComisionesProvider.notifier).state =
          OrdenComisiones.precioFinal;
      container.read(ordenAscendenteProvider.notifier).state = false;

      expect(container.read(comisionesFiltradasProvider).map((c) => c.folio), [
        'CC-000101',
        'CCP-000103',
      ]);
    });

    test('el orden NO cuenta como filtro activo', () async {
      final container = _container();
      await container.read(comisionesProvider.future);

      container.read(ordenComisionesProvider.notifier).state =
          OrdenComisiones.folio;

      expect(container.read(hayFiltrosActivosProvider), isFalse);
    });
  });
}

/// Container con el puerto falso: el orden es del cliente, no viaja al backend.
ProviderContainer _container() => makeClientContainer(
  overrides: [comisionesPortProvider.overrideWithValue(FakeComisionesPort())],
);

/// Comisión mínima para probar UN comparador: solo el campo que se compara.
Comision _comision({
  int id = 0,
  String proyecto = '',
  String cliente = '',
  double precio = 0,
  double monto = 0,
  String? fechaPago,
}) => Comision(
  idCuentaCobranza: id,
  folio: 'CC-$id',
  proyecto: proyecto,
  precioFinal: precio,
  montoComision: monto,
  fechaPago: fechaPago,
  clientes: cliente.isEmpty ? const [] : [ClienteComision(nombre: cliente)],
);
