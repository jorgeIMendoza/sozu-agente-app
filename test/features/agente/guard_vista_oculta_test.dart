import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/router.dart';

/// El portal esconde el tab de una vista recortada, pero la RUTA seguía
/// navegable por deep link o por URL restaurada en web: el backend contestaba
/// 403 y la pantalla pintaba un candado. La web redirige a Inicio, y esto fija
/// ese contrato.
void main() {
  SesionAgente sesion({
    List<String> vistas = const [],
    List<String> ocultas = const [],
  }) => SesionAgente(
    identidad: const IdentidadAgente(email: 'agente@sozu.com'),
    permisos: {for (final v in vistas) v: PermisosVista.todo},
    restricciones: Restricciones(rutasOcultas: ocultas),
  );

  final todas = VistaAgente.rutaApp.keys.toList();

  test('el agente dependiente sale de /comisiones a /inicio', () {
    final s = sesion(vistas: todas, ocultas: [VistaAgente.comisiones]);
    expect(redireccionVistaOculta(s, '/comisiones'), '/inicio');
  });

  test('también en una subruta de la vista oculta', () {
    final s = sesion(vistas: todas, ocultas: [VistaAgente.comisiones]);
    expect(redireccionVistaOculta(s, '/comisiones/2026-08'), '/inicio');
  });

  test('una vista sin permiso de lectura tampoco es navegable', () {
    final s = sesion(vistas: [VistaAgente.inicio, VistaAgente.perfil]);
    expect(redireccionVistaOculta(s, '/pipeline'), '/inicio');
    expect(redireccionVistaOculta(s, '/prospectos/7'), '/inicio');
  });

  test('la vista visible se deja pasar', () {
    final s = sesion(vistas: todas);
    expect(redireccionVistaOculta(s, '/comisiones'), isNull);
    expect(redireccionVistaOculta(s, '/perfil/expediente'), isNull);
  });

  test('mientras la sesión carga NO se redirige', () {
    // El arranque de la app: sin sesión resuelta el menú se recorta a Inicio y
    // Perfil, así que redirigir aquí sacaría de /comisiones a cualquier agente
    // legítimo que abra la app en esa pantalla.
    expect(redireccionVistaOculta(null, '/comisiones'), isNull);
    expect(redireccionVistaOculta(null, '/pipeline'), isNull);
  });

  test('/inicio nunca se redirige a sí mismo', () {
    final s = sesion(ocultas: [VistaAgente.inicio]);
    expect(redireccionVistaOculta(s, '/inicio'), isNull);
  });

  test('las rutas que no son vistas del menú no las toca el guard', () {
    final s = sesion();
    for (final loc in ['/login', '/splash', '/seleccionar-agente']) {
      expect(redireccionVistaOculta(s, loc), isNull, reason: loc);
    }
  });

  test('la sesión entra al refreshListenable del router', () {
    // El redirect lee la sesión con `read`: sin la notificación, el guard no
    // volvería a correr cuando la sesión resuelve y el agente se quedaría en la
    // pantalla con candado.
    final router = File('lib/router.dart').readAsStringSync();
    final merge = RegExp(
      r'refreshListenable: Listenable\.merge\(\[([^\]]+)\]\)',
    ).firstMatch(router);
    expect(merge, isNotNull, reason: 'no se encontró el refreshListenable');
    expect(merge!.group(1), contains('sesion'));
  });
}
