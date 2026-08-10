import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/shared/adapters/edge_function.dart';

/// Implementación de [InventarioPort] sobre la Edge Function
/// `agente-inventario`, que sirve las cuatro vistas del inventario en un solo
/// endpoint (`vista: proyectos | proyecto | unidades | planos`).
///
/// El filtro de proyectos accesibles lo aplica el servidor: aquí NO se manda
/// nada que amplíe el universo visible.
class InventarioAdapter implements InventarioPort {
  /// `id_persona` del agente que un admin está viendo; null = su propia sesión.
  final int? impersonate;

  final EdgeFunctions _fn;

  InventarioAdapter({this.impersonate})
    : _fn = EdgeFunctions(impersonate: impersonate);

  static const _funcion = 'agente-inventario';

  @override
  Future<List<DesarrolloResumen>> desarrollos() async {
    final res = await _fn.call(_funcion, body: {'vista': 'proyectos'});
    return listaDe(res['proyectos'])
        .map(DesarrolloResumen.fromJson)
        .toList(growable: false);
  }

  @override
  Future<FichaDesarrollo> desarrollo(int idDesarrollo) async =>
      FichaDesarrollo.fromJson(
        await _fn.call(
          _funcion,
          body: {'vista': 'proyecto', 'id_proyecto': idDesarrollo},
        ),
      );

  @override
  Future<PaginaUnidades> unidades(ConsultaUnidades consulta) async =>
      PaginaUnidades.fromJson(
        await _fn.call(
          _funcion,
          body: {
            'vista': 'unidades',
            'page': consulta.pagina,
            'page_size': consulta.porPagina,
            'filtros': _filtros(consulta.filtros),
          },
        ),
      );

  @override
  Future<PlanosUnidad> planos(int idUnidad) async => PlanosUnidad.fromJson(
    await _fn.call(_funcion, body: {'vista': 'planos', 'id_propiedad': idUnidad}),
  );

  /// Traduce los filtros del dominio a las llaves del backend. Se omite lo que
  /// no está puesto: mandar una lista vacía filtraría por "nada" y devolvería
  /// cero resultados.
  static Map<String, dynamic> _filtros(FiltrosUnidades f) {
    final recamaras = f.recamarasNumericas;
    return {
      if (f.desarrollos.isNotEmpty) 'proyectos': f.desarrollos,
      if (f.modelos.isNotEmpty) 'modelos': f.modelos,
      if (recamaras.isNotEmpty) 'recamaras': recamaras,
      if (f.niveles.isNotEmpty) 'niveles': f.niveles,
      if (f.conBodega != null) 'con_bodega': f.conBodega,
      if (f.conEstacionamiento != null)
        'con_estacionamiento': f.conEstacionamiento,
      if (f.ordenPrecio.clave != null) 'orden_precio': f.ordenPrecio.clave,
      if (f.precioMin != null) 'precio_min': f.precioMin,
      if (f.precioMax != null) 'precio_max': f.precioMax,
    };
  }
}
