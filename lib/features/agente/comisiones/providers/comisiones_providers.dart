import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/comisiones/adapters/comisiones_adapter.dart';
import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';

/// Valor de "sin filtrar". Es un centinela y no `null` porque el desplegable
/// necesita una opción seleccionable que signifique "todos".
const String kFiltroTodos = 'todos';

/// Puerto de comisiones. Se reconstruye al cambiar de usuario o de agente
/// impersonado: sin esto un administrador vería las comisiones del agente
/// anterior.
final comisionesPortProvider = Provider<ComisionesPort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return ComisionesAdapter(impersonate: imp.active ? imp.personaId : null);
});

/// Comisiones del agente con sus totales, filtros y bloqueo de perfil.
final comisionesProvider = FutureProvider<ComisionesAgente>(
  (ref) => ref.watch(comisionesPortProvider).cargarComisiones(),
);

/// Proyecto elegido, o [kFiltroTodos].
final filtroProyectoProvider = StateProvider<String>((ref) => kFiltroTodos);

/// Etapa elegida, o [kFiltroTodos].
final filtroEtapaProvider = StateProvider<String>((ref) => kFiltroTodos);

/// Texto del buscador de cliente (nombre o correo).
final filtroClienteProvider = StateProvider<String>((ref) => '');

/// Comisiones que pasan los tres filtros.
///
/// El filtrado es del cliente y no del backend a propósito: son las comisiones
/// de UN agente (decenas, no miles), ya están en memoria, y filtrar aquí hace
/// que el buscador responda mientras escribe.
final comisionesFiltradasProvider = Provider<List<Comision>>((ref) {
  final datos = ref.watch(comisionesProvider).valueOrNull;
  if (datos == null) return const [];

  final proyecto = ref.watch(filtroProyectoProvider);
  final etapa = ref.watch(filtroEtapaProvider);
  final cliente = ref.watch(filtroClienteProvider);

  return datos.comisiones.where((c) {
    if (proyecto != kFiltroTodos && c.proyecto != proyecto) return false;
    if (etapa != kFiltroTodos && c.etapa.clave != etapa) return false;
    return c.coincideCliente(cliente);
  }).toList(growable: false);
});

/// ¿Hay algún filtro puesto? Distingue "este agente no tiene comisiones" de
/// "ninguna comisión coincide con lo que filtraste", que piden mensajes
/// distintos.
final hayFiltrosActivosProvider = Provider<bool>((ref) {
  return ref.watch(filtroProyectoProvider) != kFiltroTodos ||
      ref.watch(filtroEtapaProvider) != kFiltroTodos ||
      ref.watch(filtroClienteProvider).trim().isNotEmpty;
});
