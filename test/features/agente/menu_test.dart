import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/layouts/portal_shell.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';

/// El catálogo del menú vive en CÓDIGO (`_portalNavItems`); lo que se PINTA sale
/// de `menuAgenteProvider`, que le aplica los permisos de la BD.
///
/// Dos riesgos, uno por capa: un ítem puede apuntar a una ruta que el router no
/// registra (solo se ve al tocarlo), y una ruta puede dejar de casar con la vista
/// de la BD (entonces ningún permiso coincide y el portal sale vacío para todos).
/// Estos tests cazan ambos leyendo el router y el provider, sin montar nada.
void main() {
  SesionAgente sesion({
    List<String> vistas = const [],
    List<String> ocultas = const [],
    List<TabAgente>? tabs,
    bool accesoTotal = false,
  }) => SesionAgente(
    identidad: const IdentidadAgente(email: 'agente@sozu.com'),
    permisos: {for (final v in vistas) v: PermisosVista.todo},
    restricciones: Restricciones(rutasOcultas: ocultas),
    accesoTotal: accesoTotal,
    tabs: tabs ?? tabsAgenteRespaldo,
  );

  Future<List<String>> rutasDelMenu(SesionAgente? s) async {
    final container = ProviderContainer(
      overrides: [
        // `s == null` = sesión que nunca resuelve, para ver el menú en carga.
        sesionProvider.overrideWith(
          (ref) =>
              s == null ? Completer<SesionAgente>().future : Future.value(s),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (s != null) await container.read(sesionProvider.future);
    return container.read(menuAgenteProvider).map((t) => t.route).toList();
  }

  Future<List<String>> etiquetasDelMenu(SesionAgente s) async {
    final container = ProviderContainer(
      overrides: [sesionProvider.overrideWith((ref) => Future.value(s))],
    );
    addTearDown(container.dispose);
    await container.read(sesionProvider.future);
    return container.read(menuAgenteProvider).map((t) => t.label).toList();
  }

  test('cada ítem del menú apunta a una ruta que el router registra', () {
    final router = File('lib/router.dart').readAsStringSync();
    final rutas = RegExp(
      r"path: '([^']+)'",
    ).allMatches(router).map((m) => m.group(1)!).toSet();

    expect(rutas, isNotEmpty, reason: 'el barrido del router no encontró nada');

    final huerfanas = agenteMenuTabs()
        .map((t) => t.route)
        .where((r) => !rutas.contains(r))
        .toList();

    expect(
      huerfanas,
      isEmpty,
      reason: 'estas rutas del menú no existen en el router: $huerfanas',
    );
  });

  test('el menú y las rutas permitidas no se desincronizan', () {
    expect(portalAllowedRoutes(), agenteMenuTabs().map((t) => t.route).toSet());
  });

  test('no hay rutas repetidas: cada ítem es un destino distinto', () {
    final rutas = agenteMenuTabs().map((t) => t.route).toList();
    expect(rutas.toSet().length, rutas.length);
  });

  test('toda vista de la BD tiene su ítem en el menú', () {
    final delMenu = agenteMenuTabs().map((t) => t.route).toSet();
    for (final ruta in VistaAgente.rutaApp.values) {
      expect(
        delMenu,
        contains(ruta),
        reason: 'la vista $ruta no está en el menú: su permiso nunca se aplica',
      );
    }
  });

  test('mientras la sesión carga solo salen Inicio y Perfil', () async {
    expect(await rutasDelMenu(null), ['/inicio', '/perfil']);
  });

  test('el menú se recorta a las vistas con permiso de lectura', () async {
    expect(
      await rutasDelMenu(
        sesion(
          vistas: [
            VistaAgente.inicio,
            VistaAgente.inventario,
            VistaAgente.perfil,
          ],
        ),
      ),
      ['/inicio', '/inventario', '/notificaciones', '/perfil'],
    );
  });

  test('el agente dependiente no ve Comisiones', () async {
    final rutas = await rutasDelMenu(
      sesion(
        vistas: VistaAgente.rutaApp.keys.toList(),
        ocultas: [VistaAgente.comisiones],
      ),
    );
    expect(rutas, isNot(contains('/comisiones')));
    expect(rutas, contains('/pipeline'));
  });

  // --- Hallazgo 1: el menú se resuelve en la BD ------------------------------

  group('tabs de la BD', () {
    test('sin la clave `tabs` se cae al catálogo de respaldo', () {
      final s = SesionAgente.fromJson({
        'identity': {'email': 'a@sozu.com'},
      });
      expect(s.tabs.map((t) => t.ruta), tabsAgenteRespaldo.map((t) => t.ruta));
    });

    test('`tabs` vacío se respeta: es "todo apagado en Administrar Menús"', () {
      final s = SesionAgente.fromJson({
        'identity': {'email': 'a@sozu.com'},
        'tabs': <Object>[],
      });
      expect(s.tabs, isEmpty);
    });

    test('se parsea ruta, nombre y orden', () {
      final s = SesionAgente.fromJson({
        'identity': {'email': 'a@sozu.com'},
        'tabs': [
          {'ruta': VistaAgente.inventario, 'nombre': 'Catálogo', 'orden': 2},
        ],
      });
      expect(s.tabs.single.ruta, VistaAgente.inventario);
      expect(s.tabs.single.nombre, 'Catálogo');
      expect(s.tabs.single.orden, 2);
    });

    test('el menú respeta el ORDEN que manda la BD', () async {
      final rutas = await rutasDelMenu(
        sesion(
          vistas: VistaAgente.rutaApp.keys.toList(),
          tabs: const [
            TabAgente(ruta: VistaAgente.inicio, nombre: 'Inicio', orden: 1),
            TabAgente(
              ruta: VistaAgente.comisiones,
              nombre: 'Comisiones',
              orden: 2,
            ),
            TabAgente(
              ruta: VistaAgente.inventario,
              nombre: 'Inventario',
              orden: 3,
            ),
            TabAgente(ruta: VistaAgente.perfil, nombre: 'Perfil', orden: 4),
          ],
        ),
      );
      expect(rutas, [
        '/inicio',
        '/comisiones',
        '/inventario',
        '/notificaciones',
        '/perfil',
      ]);
    });

    test('el menú usa el NOMBRE de la BD, no el del catálogo local', () async {
      final etiquetas = await etiquetasDelMenu(
        sesion(
          vistas: VistaAgente.rutaApp.keys.toList(),
          tabs: const [
            TabAgente(ruta: VistaAgente.inicio, nombre: 'Tablero', orden: 1),
            TabAgente(
              ruta: VistaAgente.inventario,
              nombre: 'Catálogo',
              orden: 2,
            ),
          ],
        ),
      );
      expect(etiquetas, ['Tablero', 'Catálogo', 'Notificaciones']);
    });

    test('con el menú padre apagado no queda ninguna vista', () async {
      // `menus.activo = false` deja la consulta en cero filas: el backend manda
      // `tabs: []` y la app NO revive el catálogo.
      final rutas = await rutasDelMenu(
        sesion(vistas: VistaAgente.rutaApp.keys.toList(), tabs: const []),
      );
      expect(rutas, ['/notificaciones']);
    });

    test('full_access no revive una vista apagada en la BD', () async {
      final rutas = await rutasDelMenu(
        sesion(
          accesoTotal: true,
          tabs: const [
            TabAgente(ruta: VistaAgente.inicio, nombre: 'Inicio', orden: 1),
            TabAgente(ruta: VistaAgente.perfil, nombre: 'Perfil', orden: 2),
          ],
        ),
      );
      expect(rutas, ['/inicio', '/notificaciones', '/perfil']);
    });
  });

  // --- Hallazgo 4: título de sección del topbar ------------------------------

  group('título de la sección', () {
    test('sale del nombre que tiene la vista en la BD', () {
      const catalogo = [
        TabAgente(ruta: VistaAgente.inventario, nombre: 'Catálogo', orden: 1),
      ];
      expect(tituloSeccion(catalogo, '/inventario'), 'Catálogo');
    });

    test('una secundaria hereda el título de su tab', () {
      expect(tituloSeccion(tabsAgenteRespaldo, '/perfil/expediente'), 'Perfil');
      expect(
        tituloSeccion(tabsAgenteRespaldo, '/inventario/proyecto/7'),
        'Inventario',
      );
    });

    test(
      'una vista que el catálogo de la BD no lista sigue teniendo título',
      () {
        // Es el caso de la carga (catálogo vacío) y el de una vista apagada a la
        // que se llega por deep link: caer a "Inicio" era el bug.
        expect(tituloSeccion(const [], '/comisiones'), 'Comisiones');
        expect(tituloSeccion(const [], '/notificaciones'), 'Notificaciones');
      },
    );

    test('una ruta sin sección cae a Inicio', () {
      expect(tituloSeccion(tabsAgenteRespaldo, '/loquesea'), 'Inicio');
    });
  });
}
