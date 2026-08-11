import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/inventario/adapters/inventario_adapter.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';

/// Puerto del inventario. Se reconstruye al cambiar la sesión o el agente
/// impersonado, y eso invalida en cascada todos los providers de datos: sin
/// esto, un admin que cambia de agente seguiría viendo el inventario del
/// anterior.
final inventarioPortProvider = Provider<InventarioPort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return InventarioAdapter(impersonate: imp.personaId);
});

/// Desarrollos que el agente puede vender. Lista vacía = sin proyectos
/// asignados; la pantalla lo explica, no lo trata como error.
final desarrollosProvider = FutureProvider<List<DesarrolloResumen>>(
  (ref) => ref.watch(inventarioPortProvider).desarrollos(),
);

/// Ficha de un desarrollo. Clave = su id.
final fichaDesarrolloProvider = FutureProvider.family<FichaDesarrollo, int>(
  (ref, id) => ref.watch(inventarioPortProvider).desarrollo(id),
);

/// Página de unidades disponibles. Clave = filtros + página, así que volver a
/// una página ya vista no vuelve a pedirla.
final unidadesProvider =
    FutureProvider.family<PaginaUnidades, ConsultaUnidades>(
      (ref, consulta) => ref.watch(inventarioPortProvider).unidades(consulta),
    );

/// Planos de una unidad. Clave = id de la unidad.
final planosUnidadProvider = FutureProvider.family<PlanosUnidad, int>(
  (ref, id) => ref.watch(inventarioPortProvider).planos(id),
);

// ---------------------------------------------------------------------------
// Estado de sesión de las búsquedas y los filtros
// ---------------------------------------------------------------------------

/// Texto del buscador de desarrollos. Vive en el contenedor raíz (no es
/// autoDispose), así que sobrevive a salir de la pestaña y volver, igual que el
/// `sessionStorage` del portal web. No es dato sensible: no va a secure storage.
final busquedaDesarrollosProvider = StateProvider<String>((ref) => '');

/// Texto del buscador de unidades. El filtrado por número de unidad es del
/// cliente (igual que en la web), así que este valor NO viaja al servidor.
final busquedaUnidadProvider = StateProvider<String>((ref) => '');

/// Filtros vigentes de la búsqueda de unidades, persistidos durante la sesión
/// del app por la misma razón que los buscadores.
final filtrosUnidadesProvider = StateProvider<FiltrosUnidades>(
  (ref) => const FiltrosUnidades(),
);

/// Desarrollo y modelo con los que se entra a la vista de unidades desde el
/// inventario o desde la ficha del desarrollo.
typedef PreseleccionUnidades = ({int? idDesarrollo, int? idModelo});

/// Filtros equivalentes a una preselección por ids.
///
/// La vista de unidades del backend filtra por NOMBRE de desarrollo y de
/// modelo, no por id (es el contrato del RPC que hay debajo), así que los ids
/// con los que se navega se resuelven contra las otras dos vistas: la lista de
/// desarrollos y la ficha del desarrollo. Devuelve filtros LIMPIOS: llegar con
/// una preselección abre un contexto nuevo y lo guardado no debe arrastrarse.
final preseleccionFiltrosProvider =
    FutureProvider.family<FiltrosUnidades, PreseleccionUnidades>((
      ref,
      pre,
    ) async {
      final idDesarrollo = pre.idDesarrollo;
      if (idDesarrollo == null) return const FiltrosUnidades();

      final desarrollos = await ref.watch(desarrollosProvider.future);
      final nombreDesarrollo = desarrollos
          .where((d) => d.id == idDesarrollo)
          .map((d) => d.nombre)
          .firstOrNull;

      var nombreModelo = <String>[];
      if (pre.idModelo != null) {
        final ficha = await ref.watch(
          fichaDesarrolloProvider(idDesarrollo).future,
        );
        nombreModelo = ficha.modelos
            .where((m) => m.id == pre.idModelo)
            .map((m) => m.nombre)
            .toList();
      }

      return FiltrosUnidades(
        desarrollos: nombreDesarrollo == null ? const [] : [nombreDesarrollo],
        modelos: nombreModelo,
      );
    });
