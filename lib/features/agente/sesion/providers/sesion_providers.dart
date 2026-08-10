import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/sesion/adapters/sesion_adapter.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/auth/providers/auth_provider.dart';

/// Puerto de sesión. Se sobreescribe en tests con un doble
/// (`sesionPortProvider.overrideWithValue(FakeSesionPort())`).
final sesionPortProvider = Provider<SesionPort>((ref) {
  final imp = ref.watch(impersonationProvider);
  return SesionAdapter(impersonate: imp.active ? imp.personaId : null);
});

/// Bootstrap del portal. Todo lo que gatea la UI (tabs, permisos, recortes,
/// activación) sale de aquí, así que se carga una vez por sesión y se invalida
/// al cambiar de agente impersonado — de eso se encarga [sesionPortProvider],
/// que cambia de identidad y hace que este provider se reconstruya.
///
/// Se mantiene como `FutureProvider` (no un controlador con estado) por la misma
/// razón que en el app del cliente: un endpoint = un provider, y el refresco es
/// `ref.invalidate`.
final sesionProvider = FutureProvider<SesionAgente>((ref) async {
  // Sin sesión de auth no hay nada que pedir: evita un 401 en el arranque.
  final auth = ref.watch(authProvider);
  if (auth.session == null) throw StateError('sin sesión');
  return ref.watch(sesionPortProvider).cargar();
});

/// Permisos de una vista (`VistaAgente.*`) ya resueltos. Devuelve permisos vacíos
/// mientras carga: la UI se pinta deshabilitada y luego se habilita, nunca al
/// revés — habilitar primero deja al usuario tocar un botón que el backend va a
/// rechazar.
final permisosVistaProvider = Provider.family<PermisosVista, String>((
  ref,
  vista,
) {
  final sesion = ref.watch(sesionProvider);
  return sesion.maybeWhen(
    data: (s) => s.permisosDe(vista),
    orElse: () => const PermisosVista(),
  );
});

/// Identidad efectiva del agente (la del impersonado cuando aplica).
final identidadAgenteProvider = Provider<IdentidadAgente?>((ref) {
  return ref.watch(sesionProvider).maybeWhen(
    data: (s) => s.identidad,
    orElse: () => null,
  );
});

/// Estado de activación del agente.
final onboardingProvider = Provider<Onboarding>((ref) {
  return ref.watch(sesionProvider).maybeWhen(
    data: (s) => s.onboarding,
    orElse: () => const Onboarding(),
  );
});

/// Recortes de vista del agente dependiente.
final restriccionesProvider = Provider<Restricciones>((ref) {
  return ref.watch(sesionProvider).maybeWhen(
    data: (s) => s.restricciones,
    orElse: () => const Restricciones(),
  );
});

/// Tabs visibles, en el orden fijo del portal web. Se filtran por permiso de
/// lectura y por los recortes (Comisiones desaparece para el dependiente).
final tabsVisiblesProvider = Provider<List<String>>((ref) {
  final sesion = ref.watch(sesionProvider);
  const orden = [
    VistaAgente.inicio,
    VistaAgente.inventario,
    VistaAgente.pipeline,
    VistaAgente.prospectos,
    VistaAgente.comisiones,
    VistaAgente.perfil,
  ];
  return sesion.maybeWhen(
    // Mientras carga: solo Inicio y Perfil, que ningún rol de agente tiene
    // restringidos. Pintar los seis y luego quitar dos hace saltar la barra.
    orElse: () => const [VistaAgente.inicio, VistaAgente.perfil],
    data: (s) => orden.where(s.vistaVisible).toList(growable: false),
  );
});
