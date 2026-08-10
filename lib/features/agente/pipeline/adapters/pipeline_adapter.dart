import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/shared/adapters/edge_function.dart';

/// Implementación de [PipelinePort] sobre la Edge Function `agente-pipeline`.
///
/// Único archivo de la feature que sabe cómo se sirve el pipeline: el resto
/// habla de negocios, etapas y razones.
class PipelineAdapter implements PipelinePort {
  /// `id_persona` del agente que un admin está viendo; null = su propia sesión.
  final int? impersonate;

  final EdgeFunctions _fn;

  PipelineAdapter({this.impersonate})
    : _fn = EdgeFunctions(impersonate: impersonate);

  static const _fnNombre = 'agente-pipeline';

  /// `YYYY-MM-DD`: es el formato que espera el filtro de fecha del servidor.
  static String _soloFecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<PipelineAgente> negocios({DateTime? desde}) async =>
      PipelineAgente.fromJson(
        await _fn.call(
          _fnNombre,
          body: {
            'action': 'lista',
            if (desde != null) 'desde': _soloFecha(desde),
          },
        ),
      );

  @override
  Future<OfertaDetalle> detalleOferta(int idOferta) async =>
      OfertaDetalle.fromJson(
        await _fn.call(
          _fnNombre,
          body: {'action': 'detalle', 'id_oferta': idOferta},
        ),
      );

  @override
  Future<void> moverEtapa({
    required int idNegocio,
    required String claveEtapa,
  }) async {
    await _fn.call(
      _fnNombre,
      body: {
        'action': 'mover_etapa',
        'id_negocio': idNegocio,
        'clave_etapa': claveEtapa,
      },
    );
  }

  @override
  Future<RazonNoAvance> registrarRazonNoAvance({
    required int idOferta,
    required int idMotivo,
    String? comentario,
  }) async {
    final res = await _fn.call(
      _fnNombre,
      body: {
        'action': 'guardar_no_avance',
        'id_oferta': idOferta,
        'id_motivo': idMotivo,
        if (comentario != null && comentario.trim().isNotEmpty)
          'comentario': comentario.trim(),
      },
    );
    return RazonNoAvance.fromJson(mapaDe(res['no_avance']));
  }

  @override
  Future<CambioEsquema> elegirEsquemaPago({
    required int idOferta,
    required int idEsquema,
  }) async => CambioEsquema.fromJson(
    await _fn.call(
      _fnNombre,
      body: {
        'action': 'guardar_esquema',
        'id_oferta': idOferta,
        'id_esquema': idEsquema,
      },
    ),
  );

  @override
  Future<LinkCliente> generarLinkCliente({
    required int idOferta,
    String? email,
  }) async {
    final res = await _fn.call(
      _fnNombre,
      body: {
        'action': 'crear_link',
        'id_oferta': idOferta,
        if (email != null && email.contains('@')) 'email': email,
      },
    );
    return LinkCliente.fromJson(mapaDe(res['link_digital']));
  }
}
