import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/citas/adapters/citas_adapter.dart';
import 'package:sozu_agente_app/features/agente/citas/ports/citas_port.dart';
import 'package:sozu_agente_app/features/agente/citas/services/seleccion_de_cita.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';

/// Puerto de la agenda. Se reconstruye al cambiar de usuario o de agente
/// impersonado: sin eso, un administrador agendaría con la disponibilidad
/// cacheada del agente anterior.
///
/// Se sobreescribe en tests con un doble
/// (`citasPortProvider.overrideWithValue(FakeCitasPort())`).
final citasPortProvider = Provider<CitasPort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return CitasAdapter(impersonate: imp.active ? imp.personaId : null);
});

/// Días con horarios libres de un desarrollo. Key = id del desarrollo.
///
/// `autoDispose` porque la disponibilidad caduca: al reabrir la hoja de
/// agendado se vuelve a pedir en vez de ofrecer un cupo que ya tomó alguien.
final disponibilidadProvider = FutureProvider.autoDispose
    .family<List<DiaDisponible>, int>(
      (ref, idDesarrollo) =>
          ref.watch(citasPortProvider).disponibilidad(idDesarrollo),
    );

/// Prospectos que el agente puede citar, con sus desarrollos.
///
/// Sale de la cartera del CRM y no de `agente-citas`: el universo de a quién se
/// puede citar es exactamente el de Prospectos, y el servidor lo revalida al
/// agendar (`not_owner`).
final prospectosParaCitaProvider = FutureProvider<List<ProspectoParaCita>>((
  ref,
) async {
  final cartera = await ref.watch(carteraProspectosProvider.future);
  return prospectosParaCita(cartera.prospectos);
});
