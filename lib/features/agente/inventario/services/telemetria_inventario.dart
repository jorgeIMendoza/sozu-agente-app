/// Identificadores de telemetría del menú Inventario.
///
/// Son los MISMOS que emite el portal web (`AgentInventario.tsx`,
/// `AgentProyectoDetalle.tsx`, `AgentUnidadesProyecto.tsx`): si el app inventa
/// otro nombre, el tablero de CTA cuenta el mismo botón en dos series y ninguna
/// de las dos es el total.
library;

/// Rutas de vista, páginas de CTA y ids de elemento del inventario.
abstract final class TelemetriaInventario {
  // ── Listado de desarrollos ──
  static const rutaListado = '/admin/agent/inventario';
  static const paginaListado = 'agent_inventario';

  // ── Ficha de un desarrollo ──
  static const paginaFicha = 'agent_detalle_desarrollo';

  /// Ruta de la ficha; lleva el id porque la bitácora agrupa por ruta.
  static String rutaFicha(int idDesarrollo) =>
      '/admin/agent/inventario/proyecto/$idDesarrollo';

  // ── Buscador de unidades ──
  static const rutaUnidades = '/admin/agent/inventario/unidades';
  static const paginaUnidades = 'agent_unidades';

  // ── Elementos ──
  static const vistaPantalla = 'page_view';
  static const inputBuscarDesarrollo = 'input_buscar_desarrollo';
  static const btnVerDesarrollo = 'btn_ver_desarrollo';
  static const btnVerInventario = 'btn_ver_inventario';
  static const btnVerInventarioModelo = 'btn_ver_inventario_modelo';
  static const btnAgendarCita = 'btn_agendar_cita';
  static const btnCompartir = 'btn_compartir';
  static const btnCompartirPlataforma = 'btn_compartir_plataforma';
  static const btnDescargarBrochure = 'btn_descargar_brochure';
  static const btnDescargarFicha = 'btn_descargar_ficha';
  static const btnFiltros = 'btn_filtros';
  static const btnDetalleUnidad = 'btn_detalle_unidad';
  static const btnConfigurarOferta = 'btn_configurar_oferta';

  // ── Tipos de `registrarExportacion` ──
  static const exportBrochure = 'brochure';
  static const exportFichaTecnica = 'ficha_tecnica';

  // ── Tipos de elemento de `registrarCta` ──
  static const tipoPagina = 'page';
  static const tipoCampo = 'input';
}
