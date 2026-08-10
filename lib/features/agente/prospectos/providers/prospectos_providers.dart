import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/prospectos/adapters/prospectos_adapter.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';

/// Puerto de prospectos. Se reconstruye al cambiar la sesión o el agente
/// impersonado, lo que invalida en cascada los providers de datos: sin eso, un
/// administrador que cambia de agente seguiría viendo la cartera del anterior.
///
/// Se sobreescribe en tests con un doble
/// (`prospectosPortProvider.overrideWithValue(FakeProspectosPort())`).
final prospectosPortProvider = Provider<ProspectosPort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return ProspectosAdapter(impersonate: imp.active ? imp.personaId : null);
});

/// Cartera completa del agente.
///
/// Se pide de una sola vez y los filtros (texto, estado, desarrollo) se aplican
/// en memoria, igual que el portal web: así el conteo del encabezado
/// corresponde con lo que se ve y escribir en el buscador no dispara una
/// petición por tecla. El servidor también sabe filtrar; se usaría si una
/// cartera dejara de caber en una página.
final carteraProspectosProvider = FutureProvider<CarteraProspectos>(
  (ref) => ref.watch(prospectosPortProvider).cartera(),
);

/// Ficha de un prospecto. Key = id de la persona.
final detalleProspectoProvider = FutureProvider.family<DetalleProspecto, int>(
  (ref, idPersona) => ref.watch(prospectosPortProvider).detalle(idPersona),
);

/// Agentes a los que se puede transferir un prospecto. Solo se pide cuando se
/// abre el diálogo de transferencia (`autoDispose`): es un catálogo grande que
/// no hace falta mantener en memoria mientras se navega la cartera.
final agentesDestinoProvider = FutureProvider.autoDispose<List<AgenteDestino>>(
  (ref) => ref.watch(prospectosPortProvider).agentesDestino(),
);

/// Desarrollos que el agente puede ligar a un prospecto (para el alta y la
/// edición).
final desarrollosVinculablesProvider =
    FutureProvider.autoDispose<List<DesarrolloVinculable>>(
      (ref) => ref.watch(prospectosPortProvider).desarrollosVinculables(),
    );
