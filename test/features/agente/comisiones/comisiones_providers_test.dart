import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/comisiones/adapters/comisiones_adapter.dart';
import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/features/agente/comisiones/providers/comisiones_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

import '../agente_test_support.dart';
import 'fake_comisiones_port.dart';

/// Comisiones contra el PUERTO (sin Supabase): el mapeo del contrato, el
/// bloqueo por perfil incompleto, los tres filtros del cliente y la
/// reconstrucción del puerto al cambiar de agente impersonado.
void main() {
  test('mapea totales, filtros y comisiones del contrato', () async {
    final port = FakeComisionesPort();
    final container = makeClientContainer(
      overrides: [comisionesPortProvider.overrideWithValue(port)],
    );

    final datos = await container.read(comisionesProvider.future);

    expect(datos.bloqueo, isNull);
    expect(datos.totales.cobrado, 125000.5);
    // `numeric` de Postgres llega como texto.
    expect(datos.totales.porCobrar, 48250.25);
    expect(datos.filtros.proyectos, ['Kavia', 'Margot']);
    expect(datos.filtros.estatus.map((e) => e.valor), [
      'pagada',
      'aprobado',
      'pendiente',
    ]);
    expect(datos.comisiones.length, 3);
    expect(port.log, ['cargarComisiones']);
  });

  test('la etapa y su rótulo llegan resueltos del backend', () async {
    final container = makeClientContainer(
      overrides: [
        comisionesPortProvider.overrideWithValue(FakeComisionesPort()),
      ],
    );

    final datos = await container.read(comisionesProvider.future);

    expect(datos.comisiones[0].etapa, EtapaComision.pagada);
    expect(datos.comisiones[1].etapa, EtapaComision.aprobado);
    expect(datos.comisiones[2].etapa, EtapaComision.pendiente);
    // El rótulo NO se recalcula en la app: se muestra el del backend.
    expect(datos.comisiones[1].etapaEtiqueta, 'Aprobado');
    // La clave del filtro tiene que coincidir con la del contrato o el
    // desplegable de estatus no filtraría nada.
    expect(
      datos.comisiones.map((c) => c.etapa.clave),
      containsAll(<String>['pagada', 'aprobado', 'pendiente']),
    );
  });

  test('la unidad cae al nombre del producto cuando no hay propiedad', () async {
    final container = makeClientContainer(
      overrides: [
        comisionesPortProvider.overrideWithValue(FakeComisionesPort()),
      ],
    );

    final datos = await container.read(comisionesProvider.future);

    expect(datos.comisiones[0].unidad, 'A-301');
    expect(datos.comisiones[2].unidad, 'Bodega 12');
  });

  test('el permiso de facturar es del backend, no se recalcula', () async {
    final container = makeClientContainer(
      overrides: [
        comisionesPortProvider.overrideWithValue(FakeComisionesPort()),
      ],
    );

    final datos = await container.read(comisionesProvider.future);

    // Pagada pero con factura ya cargada: no puede volver a subir.
    expect(datos.comisiones[0].puedeSubirFactura, isFalse);
    expect(datos.comisiones[1].puedeSubirFactura, isTrue);
  });

  test('perfil incompleto llega como bloqueo con sus faltantes', () async {
    final port = FakeComisionesPort()
      ..payload = FakeComisionesPort.payloadBloqueado();
    final container = makeClientContainer(
      overrides: [comisionesPortProvider.overrideWithValue(port)],
    );

    final datos = await container.read(comisionesProvider.future);

    expect(datos.bloqueo, isNotNull);
    expect(datos.bloqueo!.motivo, 'perfil_incompleto');
    expect(datos.bloqueo!.faltantes, [
      'Información fiscal',
      'Cuenta bancaria',
    ]);
    expect(datos.comisiones, isEmpty);
  });

  group('filtros', () {
    test('sin filtros devuelve todas y no hay filtros activos', () async {
      final container = makeClientContainer(
        overrides: [
          comisionesPortProvider.overrideWithValue(FakeComisionesPort()),
        ],
      );
      await container.read(comisionesProvider.future);

      expect(container.read(comisionesFiltradasProvider).length, 3);
      expect(container.read(hayFiltrosActivosProvider), isFalse);
    });

    test('filtra por proyecto', () async {
      final container = makeClientContainer(
        overrides: [
          comisionesPortProvider.overrideWithValue(FakeComisionesPort()),
        ],
      );
      await container.read(comisionesProvider.future);

      container.read(filtroProyectoProvider.notifier).state = 'Kavia';

      expect(
        container.read(comisionesFiltradasProvider).map((c) => c.folio),
        ['CC-000102'],
      );
      expect(container.read(hayFiltrosActivosProvider), isTrue);
    });

    test('filtra por etapa con la clave del contrato', () async {
      final container = makeClientContainer(
        overrides: [
          comisionesPortProvider.overrideWithValue(FakeComisionesPort()),
        ],
      );
      await container.read(comisionesProvider.future);

      container.read(filtroEtapaProvider.notifier).state = 'pagada';

      expect(
        container.read(comisionesFiltradasProvider).map((c) => c.folio),
        ['CC-000101'],
      );
    });

    test('busca cliente por nombre y por correo, sin importar mayúsculas',
        () async {
      final container = makeClientContainer(
        overrides: [
          comisionesPortProvider.overrideWithValue(FakeComisionesPort()),
        ],
      );
      await container.read(comisionesProvider.future);

      container.read(filtroClienteProvider.notifier).state = 'MARTA';
      expect(
        container.read(comisionesFiltradasProvider).map((c) => c.folio),
        ['CC-000102'],
      );

      container.read(filtroClienteProvider.notifier).state = 'luis@example';
      expect(
        container.read(comisionesFiltradasProvider).map((c) => c.folio),
        ['CC-000101'],
      );
    });

    test('los filtros se acumulan y pueden dejar la lista vacía', () async {
      final container = makeClientContainer(
        overrides: [
          comisionesPortProvider.overrideWithValue(FakeComisionesPort()),
        ],
      );
      await container.read(comisionesProvider.future);

      container.read(filtroProyectoProvider.notifier).state = 'Kavia';
      container.read(filtroEtapaProvider.notifier).state = 'pagada';

      expect(container.read(comisionesFiltradasProvider), isEmpty);
    });

    test('espacios en blanco no cuentan como filtro activo', () async {
      final container = makeClientContainer(
        overrides: [
          comisionesPortProvider.overrideWithValue(FakeComisionesPort()),
        ],
      );
      await container.read(comisionesProvider.future);

      container.read(filtroClienteProvider.notifier).state = '   ';

      expect(container.read(comisionesFiltradasProvider).length, 3);
      expect(container.read(hayFiltrosActivosProvider), isFalse);
    });

    test('mientras carga, la lista filtrada está vacía', () {
      final container = makeClientContainer(
        overrides: [
          comisionesPortProvider.overrideWithValue(FakeComisionesPort()),
        ],
      );

      expect(container.read(comisionesFiltradasProvider), isEmpty);
    });
  });

  test('subir factura llega al puerto con cuenta, nombre y bytes', () async {
    final port = FakeComisionesPort();
    final container = makeClientContainer(
      overrides: [comisionesPortProvider.overrideWithValue(port)],
    );

    final url = await container.read(comisionesPortProvider).subirFactura(
      idCuentaCobranza: 102,
      nombreArchivo: 'factura.pdf',
      archivo: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d]),
    );

    expect(url, 'https://firmada/factura.pdf');
    expect(port.facturas.single.cuenta, 102);
    expect(port.facturas.single.nombre, 'factura.pdf');
    expect(port.facturas.single.bytes, 5);
  });

  test('un rechazo del backend sale como ApiError con su código', () async {
    final port = FakeComisionesPort()
      ..proximoFallo = ApiError(403, 'forbidden_role');
    final container = makeClientContainer(
      overrides: [comisionesPortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(comisionesProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'forbidden_role')),
    );
  });

  test('cambiar de agente impersonado reconstruye el puerto con su id', () {
    final container = makeClientContainer();

    final antes = container.read(comisionesPortProvider) as ComisionesAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante = container.read(comisionesPortProvider) as ComisionesAdapter;
    expect(durante.impersonate, 7);
    expect(identical(antes, durante), isFalse);
  });
}
