import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/home/adapters/notificaciones_adapter.dart';
import 'package:sozu_agente_app/features/agente/home/ports/notificaciones_port.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';

/// Puerto de notificaciones. Se reconstruye al cambiar la sesion o el agente
/// impersonado, lo que invalida en cascada la bandeja: sin esto un admin veria
/// las notificaciones del agente anterior.
final notificacionesPortProvider = Provider<NotificacionesPort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return NotificacionesAdapter(impersonate: imp.personaId);
});

/// Notificaciones del agente y su conteo de no leidas.
final notificacionesProvider = FutureProvider<BandejaDeNotificaciones>(
  (ref) => ref.watch(notificacionesPortProvider).notifications(),
);
