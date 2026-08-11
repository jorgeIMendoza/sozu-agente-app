import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/pipeline/adapters/pipeline_adapter.dart';
import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';

/// Vistas de la pantalla. Las tres del portal web: la tabla es el estándar de
/// cobranza, las tarjetas la lectura rápida y el tablero el pipeline por etapa.
enum VistaPipeline { tabla, tarjetas, tablero }

/// Valor del filtro cuando no se está filtrando por etapa.
const String kTodasLasEtapas = 'all';

/// Puerto del pipeline. Se reconstruye al cambiar la sesión o el agente
/// impersonado, y eso invalida en cascada a los providers de datos.
final pipelinePortProvider = Provider<PipelinePort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return PipelineAdapter(impersonate: imp.active ? imp.personaId : null);
});

/// Negocios del agente (últimos 30 días), etapas, cifras y catálogo de razones.
final pipelineProvider = FutureProvider<PipelineAgente>(
  (ref) => ref.watch(pipelinePortProvider).negocios(),
);

/// Detalle de una oferta. `family` por oferta: al abrir dos detalles distintos
/// cada uno conserva su carga.
final detalleOfertaProvider = FutureProvider.family<OfertaDetalle, int>(
  (ref, idOferta) => ref.watch(pipelinePortProvider).detalleOferta(idOferta),
);

/// Etapas del catálogo indexadas por clave, para resolver la etapa de un
/// negocio sin recorrer la lista en cada celda.
final etapasPorClaveProvider = Provider<Map<String, EtapaPipeline>>((ref) {
  final datos = ref.watch(pipelineProvider).valueOrNull;
  if (datos == null) return const {};
  return {for (final e in datos.etapas) e.clave: e};
});

/// Vista activa (tabla · tarjetas · tablero).
final vistaPipelineProvider = StateProvider<VistaPipeline>(
  (ref) => VistaPipeline.tabla,
);

/// Texto del buscador de prospecto.
final busquedaProspectoProvider = StateProvider<String>((ref) => '');

/// Clave de la etapa filtrada, o [kTodasLasEtapas].
final etapaFiltroProvider = StateProvider<String>((ref) => kTodasLasEtapas);

/// Etapas movidas a mano que el servidor todavía no confirmó, por id de oferta.
/// Es lo que hace que la tarjeta se quede en la columna nueva mientras responde;
/// si falla, [PipelineAcciones.moverEtapa] la revierte.
final etapasOptimistasProvider = StateProvider<Map<int, String>>(
  (ref) => const {},
);

/// Negocios con las etapas optimistas ya aplicadas. Lista vacía mientras carga:
/// el esqueleto lo pinta la pantalla leyendo [pipelineProvider].
final negociosProvider = Provider<List<Negocio>>((ref) {
  final datos = ref.watch(pipelineProvider).valueOrNull;
  if (datos == null) return const [];
  final optimistas = ref.watch(etapasOptimistasProvider);
  if (optimistas.isEmpty) return datos.negocios;
  return datos.negocios
      .map(
        (n) => optimistas.containsKey(n.idOferta)
            ? n.copyWith(etapa: optimistas[n.idOferta])
            : n,
      )
      .toList(growable: false);
});

/// Negocios que pasan el buscador de prospecto (sin filtrar por etapa: el
/// tablero necesita todas las columnas).
final negociosBuscadosProvider = Provider<List<Negocio>>((ref) {
  final negocios = ref.watch(negociosProvider);
  final q = ref.watch(busquedaProspectoProvider).trim().toLowerCase();
  if (q.isEmpty) return negocios;
  return negocios
      .where((n) => n.lead.nombre.toLowerCase().contains(q))
      .toList(growable: false);
});

/// Negocios visibles en tabla y tarjetas: buscador + filtro de etapa.
final negociosVisiblesProvider = Provider<List<Negocio>>((ref) {
  final etapa = ref.watch(etapaFiltroProvider);
  final negocios = ref.watch(negociosBuscadosProvider);
  if (etapa == kTodasLasEtapas) return negocios;
  return negocios.where((n) => n.etapa == etapa).toList(growable: false);
});

/// Cuántos negocios hay en cada etapa. Se cuenta por NEGOCIO (una unidad = un
/// negocio), no por oferta: si no, el filtro dice "19" y la tabla muestra 4.
final conteoPorEtapaProvider = Provider<Map<String, int>>((ref) {
  final conteo = <String, int>{};
  for (final n in ref.watch(negociosProvider)) {
    conteo[n.etapa] = (conteo[n.etapa] ?? 0) + 1;
  }
  return conteo;
});

/// Negocios cerrados como perdidos sin razón registrada. Se recalcula en el app
/// (y no se usa `resumen.cerrados_sin_razon`) para que el aviso siga cuadrando
/// con la tabla después de registrar una razón, antes de recargar.
final cerradosSinRazonProvider = Provider<List<Negocio>>((ref) {
  return ref
      .watch(negociosProvider)
      .where((n) => n.etapa == 'perdido' && n.razonNoAvance == null)
      .toList(growable: false);
});

/// Mutaciones de la pantalla. Cada una decide en el app lo que se puede decidir
/// sin red (etapa automática, negocio sin pipeline) para no mandar una llamada
/// que el servidor va a rechazar.
class PipelineAcciones {
  final Ref _ref;

  PipelineAcciones(this._ref);

  PipelinePort get _port => _ref.read(pipelinePortProvider);

  /// Mueve el negocio de etapa con actualización optimista.
  ///
  /// Lanza [AccionNoDisponible] si la etapa es automática o si el negocio no
  /// existe en el pipeline (`id_negocio` nulo), sin tocar la red.
  Future<void> moverEtapa(Negocio negocio, EtapaPipeline destino) async {
    if (destino.automatica) throw AccionNoDisponible('etapa_automatica');
    if (!negocio.sePuedeMover) throw AccionNoDisponible('negocio_sin_pipeline');
    if (negocio.etapa == destino.clave) return;

    final previa = negocio.etapa;
    _fijarOptimista(negocio.idOferta, destino.clave);
    try {
      await _port.moverEtapa(
        idNegocio: negocio.idNegocio!,
        claveEtapa: destino.clave,
      );
      // Se recarga para que la etapa venga del servidor y no de la suposición.
      _ref.invalidate(pipelineProvider);
    } catch (_) {
      _fijarOptimista(negocio.idOferta, previa);
      rethrow;
    }
  }

  /// Registra o corrige la razón por la que un negocio cerrado no avanzó.
  Future<RazonNoAvance> registrarRazon({
    required int idOferta,
    required int idMotivo,
    String? comentario,
  }) async {
    final razon = await _port.registrarRazonNoAvance(
      idOferta: idOferta,
      idMotivo: idMotivo,
      comentario: comentario,
    );
    _ref.invalidate(pipelineProvider);
    return razon;
  }

  /// Fija el esquema de pago de la oferta.
  Future<CambioEsquema> elegirEsquema({
    required int idOferta,
    required int idEsquema,
  }) async {
    final cambio = await _port.elegirEsquemaPago(
      idOferta: idOferta,
      idEsquema: idEsquema,
    );
    _ref.invalidate(detalleOfertaProvider(idOferta));
    _ref.invalidate(pipelineProvider);
    return cambio;
  }

  /// Emite el link del cliente de una oferta que todavía no lo tiene.
  Future<LinkCliente> generarLink({required int idOferta, String? email}) async {
    final link = await _port.generarLinkCliente(
      idOferta: idOferta,
      email: email,
    );
    _ref.invalidate(detalleOfertaProvider(idOferta));
    _ref.invalidate(pipelineProvider);
    return link;
  }

  void _fijarOptimista(int idOferta, String clave) {
    final estado = _ref.read(etapasOptimistasProvider.notifier);
    estado.state = {...estado.state, idOferta: clave};
  }
}

final pipelineAccionesProvider = Provider<PipelineAcciones>(
  (ref) => PipelineAcciones(ref),
);
