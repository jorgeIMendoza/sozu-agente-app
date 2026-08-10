import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/perfil/adapters/profile_adapter.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/profile_port.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';

/// Puerto de perfil. Se reconstruye al cambiar la sesion o el cliente
/// impersonado, lo que invalida en cascada los providers de datos de la hoja.
final profilePortProvider = Provider<ProfilePort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return ProfileAdapter(impersonate: imp.personaId);
});

/// Perfil completo del cliente.
final profileProvider = FutureProvider<ClientePerfil>(
  (ref) => ref.watch(profilePortProvider).profile(),
);
