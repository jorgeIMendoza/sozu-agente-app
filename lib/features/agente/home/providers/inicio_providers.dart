import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/home/adapters/inicio_adapter.dart';
import 'package:sozu_agente_app/features/agente/home/ports/inicio_port.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';

/// Máximo de citas en la tarjeta de Inicio.
///
/// El backend devuelve la agenda completa: el recorte es de presentación, y por
/// eso vive aquí y no en el contrato. La pantalla de agenda usará la misma lista
/// sin recortar.
const int kMaxCitasInicio = 3;

/// Puerto del tablero de Inicio. Se reconstruye al cambiar de usuario o de
/// agente impersonado, y eso invalida en cascada los providers de datos: sin
/// esto un administrador vería los números del agente anterior.
final inicioPortProvider = Provider<InicioPort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return InicioAdapter(impersonate: imp.active ? imp.personaId : null);
});

/// Números, agenda y último acceso del agente. Un endpoint, un provider: el
/// refresco es `ref.invalidate`.
final resumenInicioProvider = FutureProvider<ResumenInicio>(
  (ref) => ref.watch(inicioPortProvider).cargarResumen(),
);

/// Las citas que caben en la tarjeta de Inicio. Devuelve lista vacía mientras
/// carga: la sección simplemente no se pinta todavía.
final citasInicioProvider = Provider<List<CitaAgente>>((ref) {
  return ref.watch(resumenInicioProvider).maybeWhen(
    data: (r) => r.citas.take(kMaxCitasInicio).toList(growable: false),
    orElse: () => const [],
  );
});
