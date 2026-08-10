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
  }) => SesionAgente(
    identidad: const IdentidadAgente(email: 'agente@sozu.com'),
    permisos: {for (final v in vistas) v: PermisosVista.todo},
    restricciones: Restricciones(rutasOcultas: ocultas),
  );

  Future<List<String>> rutasDelMenu(SesionAgente? s) async {
    final container = ProviderContainer(
      overrides: [
        // `s == null` = sesión que nunca resuelve, para ver el menú en carga.
        sesionProvider.overrideWith(
          (ref) => s == null
              ? Completer<SesionAgente>().future
              : Future.value(s),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (s != null) await container.read(sesionProvider.future);
    return container.read(menuAgenteProvider).map((t) => t.route).toList();
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
}
