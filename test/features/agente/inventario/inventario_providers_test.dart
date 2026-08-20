import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/inventario/adapters/inventario_adapter.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/features/agente/inventario/providers/inventario_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

import '../agente_test_support.dart';
import 'fake_inventario_port.dart';

/// Providers del inventario contra el PUERTO (sin backend) y lo que no se puede
/// romper: la reconstrucción del puerto al cambiar de agente impersonado, el
/// vacío por falta de acceso y la traducción de la preselección por ids.
void main() {
  test('los providers de datos resuelven contra el puerto', () async {
    final port = FakeInventarioPort();
    final container = makeClientContainer(
      overrides: [inventarioPortProvider.overrideWithValue(port)],
    );

    final desarrollos = await container.read(desarrollosProvider.future);
    final ficha = await container.read(fichaDesarrolloProvider(7).future);
    final pagina = await container.read(
      unidadesProvider(const ConsultaUnidades()).future,
    );
    final planos = await container.read(planosUnidadProvider(101).future);

    expect(desarrollos.map((d) => d.nombre), [
      'Torre Margot',
      'Distrito Andares',
    ]);
    expect(desarrollos.first.precioDesde, 3250000.0);
    expect(desarrollos.last.agotado, isTrue);
    expect(ficha.desarrollo.nombre, 'Torre Margot');
    expect(ficha.modelos.single.m2, 82.5);
    // Una vista sin archivo no se pinta: el puerto la descarta al leer.
    expect(ficha.vistas.map((v) => v.nombre), ['Lobby']);
    expect(ficha.avance.video?.idVideo, 'abc123');
    expect(pagina.unidades.map((u) => u.numero), ['1203', '905']);
    expect(pagina.total, 2);
    expect(planos.regiones.map((r) => r.unidad), ['03', '4']);
    expect(port.log, [
      'desarrollos',
      'desarrollo:7',
      'unidades:0:30',
      'planos:101',
    ]);
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakeInventarioPort()..nextFailure = ApiError(403, 'not_owner');
    final container = makeClientContainer(
      overrides: [inventarioPortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(desarrollosProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'not_owner')),
    );
  });

  test('sin proyectos asignados la lista viene vacía, no falla', () async {
    final port = FakeInventarioPort()..sinAcceso = true;
    final container = makeClientContainer(
      overrides: [inventarioPortProvider.overrideWithValue(port)],
    );

    expect(await container.read(desarrollosProvider.future), isEmpty);
    final pagina = await container.read(
      unidadesProvider(const ConsultaUnidades()).future,
    );
    expect(pagina.unidades, isEmpty);
    expect(pagina.total, 0);
    expect(pagina.opciones.desarrollos, isEmpty);
  });

  test('la preselección por ids se traduce a nombres de filtro', () async {
    final port = FakeInventarioPort();
    final container = makeClientContainer(
      overrides: [inventarioPortProvider.overrideWithValue(port)],
    );

    final filtros = await container.read(
      preseleccionFiltrosProvider((idDesarrollo: 7, idModelo: 55)).future,
    );

    expect(filtros.desarrollos, ['Torre Margot']);
    expect(filtros.modelos, ['Modelo B']);
  });

  test('sin desarrollo preseleccionado no se pide nada al puerto', () async {
    final port = FakeInventarioPort();
    final container = makeClientContainer(
      overrides: [inventarioPortProvider.overrideWithValue(port)],
    );

    final filtros = await container.read(
      preseleccionFiltrosProvider((idDesarrollo: null, idModelo: null)).future,
    );

    expect(filtros.desarrollos, isEmpty);
    expect(port.log, isEmpty);
  });

  test('cambiar la impersonación reconstruye el puerto con el id', () {
    final container = makeClientContainer();

    final antes = container.read(inventarioPortProvider) as InventarioAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante = container.read(inventarioPortProvider) as InventarioAdapter;
    expect(durante.impersonate, 7);
    expect(identical(antes, durante), isFalse);

    container.read(impersonationProvider).clear();
    expect(
      (container.read(inventarioPortProvider) as InventarioAdapter).impersonate,
      isNull,
    );
  });

  test('cambiar de usuario autenticado reconstruye el puerto', () {
    final container = makeClientContainer();

    final antes = container.read(inventarioPortProvider);
    container.read(testUserIdProvider.notifier).state = 'user-2';

    expect(identical(container.read(inventarioPortProvider), antes), isFalse);
  });

  test('la consulta de unidades es la clave de caché', () async {
    final port = FakeInventarioPort();
    final container = makeClientContainer(
      overrides: [inventarioPortProvider.overrideWithValue(port)],
    );

    const a = ConsultaUnidades(
      filtros: FiltrosUnidades(desarrollos: ['Torre Margot']),
    );
    const b = ConsultaUnidades(
      filtros: FiltrosUnidades(desarrollos: ['Torre Margot']),
    );
    // Dos consultas con el mismo contenido son la MISMA clave: sin == por valor,
    // cada rebuild pediría la página otra vez.
    expect(a == b, isTrue);
    expect(a.hashCode == b.hashCode, isTrue);

    await container.read(unidadesProvider(a).future);
    await container.read(unidadesProvider(b).future);
    expect(port.log.where((l) => l.startsWith('unidades')), hasLength(1));

    const otra = ConsultaUnidades(
      filtros: FiltrosUnidades(desarrollos: ['Distrito Andares']),
    );
    expect(a == otra, isFalse);
  });

  test(
    'las opciones de nivel salen ordenadas por número, no por texto',
    () async {
      final port = FakeInventarioPort();
      final container = makeClientContainer(
        overrides: [inventarioPortProvider.overrideWithValue(port)],
      );

      final pagina = await container.read(
        unidadesProvider(const ConsultaUnidades()).future,
      );

      expect(pagina.opciones.niveles, ['2', '9', '10']);
    },
  );

  test('los esquemas y los meses de la unidad salen del desarrollo', () async {
    final port = FakeInventarioPort();
    final container = makeClientContainer(
      overrides: [inventarioPortProvider.overrideWithValue(port)],
    );

    final pagina = await container.read(
      unidadesProvider(const ConsultaUnidades()).future,
    );
    final unidad = pagina.unidades.first;

    // La unidad viene con `esquemas_pago` vacío: los que sirven (con tramos y
    // orden) están indexados por desarrollo.
    expect(unidad.esquemasPago, isEmpty);
    expect(pagina.esquemasDe(unidad).single.nombre, 'Tradicional');
    expect(pagina.mesesDe(unidad), 18);
  });

  test('los filtros se traducen a las llaves del backend', () {
    const filtros = FiltrosUnidades(
      desarrollos: ['Torre Margot'],
      recamaras: ['2', '4+'],
      conBodega: true,
      ordenPrecio: OrdenPrecio.ascendente,
      precioMin: 1000000,
    );

    // "4+" abre el rango 4-10: pedir solo 4 escondería las de 5 recámaras.
    expect(filtros.recamarasNumericas, [2, 4, 5, 6, 7, 8, 9, 10]);
    expect(filtros.ordenPrecio.clave, 'asc');
    expect(filtros.activos, 4);
    expect(const FiltrosUnidades().hayFiltros, isFalse);
  });

  test('la unidad lee los extras y su total, con y sin ellos', () {
    final conExtras = Unidad.fromJson(const {
      'id': 101,
      'precio_lista': '9381714.05',
      'precio_total': '9535014.05',
      'extras_total': '153300.00',
      'extras_bodegas': '153300.00',
      'extras_estacionamientos': '0',
      'extras': [
        {'id': 1, 'tipo': 'bodega', 'nombre': 'B-12', 'costo': '153300.00'},
        {'id': 2, 'tipo': 'estacionamiento', 'nombre': 'E-08', 'costo': '0'},
      ],
    });

    expect(conExtras.precioAlCliente, 9535014.05);
    expect(conExtras.extrasTotal, 153300.00);
    expect(conExtras.extrasBodegas, 153300.00);
    expect(conExtras.extrasEstacionamientos, 0);
    // Los de costo 0 llegan a propósito, pero no se desglosan.
    expect(conExtras.extras.length, 2);
    expect(conExtras.extrasConCosto.single.nombre, 'B-12');
    expect(conExtras.extrasConCosto.single.tipo, TipoExtra.bodega);
    expect(conExtras.totalExtrasConCosto, 153300.00);

    // Payload sin extras (backend anterior): se cae al precio de lista y no
    // hay nada que desglosar.
    final sinExtras = Unidad.fromJson(const {
      'id': 102,
      'precio_lista': '2980000.00',
    });
    expect(sinExtras.precioAlCliente, 2980000.00);
    expect(sinExtras.extras, isEmpty);
    expect(sinExtras.extrasConCosto, isEmpty);

    // precio_total en 0 tampoco puede borrar el precio de la tarjeta.
    final totalCero = Unidad.fromJson(const {
      'id': 103,
      'precio_lista': '1500000.00',
      'precio_total': 0,
    });
    expect(totalCero.precioAlCliente, 1500000.00);
  });
}
