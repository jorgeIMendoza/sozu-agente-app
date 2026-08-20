import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/inventario/services/telemetria_inventario.dart';

/// Los identificadores de telemetría del inventario son un CONTRATO con el
/// portal web (`AgentInventario.tsx`, `AgentProyectoDetalle.tsx`,
/// `AgentUnidadesProyecto.tsx`). Este test los fija como literales: cambiar uno
/// aquí sin cambiarlo allá parte la serie del tablero en dos.
void main() {
  test('rutas y páginas son las de la web', () {
    expect(TelemetriaInventario.rutaListado, '/admin/agent/inventario');
    expect(TelemetriaInventario.paginaListado, 'agent_inventario');
    expect(
      TelemetriaInventario.rutaFicha(42),
      '/admin/agent/inventario/proyecto/42',
    );
    expect(TelemetriaInventario.paginaFicha, 'agent_detalle_desarrollo');
    expect(
      TelemetriaInventario.rutaUnidades,
      '/admin/agent/inventario/unidades',
    );
    expect(TelemetriaInventario.paginaUnidades, 'agent_unidades');
  });

  test('los ids de elemento son los de la web', () {
    expect(TelemetriaInventario.vistaPantalla, 'page_view');
    expect(
      TelemetriaInventario.inputBuscarDesarrollo,
      'input_buscar_desarrollo',
    );
    expect(TelemetriaInventario.btnVerDesarrollo, 'btn_ver_desarrollo');
    expect(TelemetriaInventario.btnVerInventario, 'btn_ver_inventario');
    expect(
      TelemetriaInventario.btnVerInventarioModelo,
      'btn_ver_inventario_modelo',
    );
    expect(TelemetriaInventario.btnAgendarCita, 'btn_agendar_cita');
    expect(TelemetriaInventario.btnCompartir, 'btn_compartir');
    expect(
      TelemetriaInventario.btnCompartirPlataforma,
      'btn_compartir_plataforma',
    );
    expect(TelemetriaInventario.btnDescargarBrochure, 'btn_descargar_brochure');
    expect(TelemetriaInventario.btnDescargarFicha, 'btn_descargar_ficha');
    expect(TelemetriaInventario.btnFiltros, 'btn_filtros');
    expect(TelemetriaInventario.btnDetalleUnidad, 'btn_detalle_unidad');
    expect(TelemetriaInventario.btnConfigurarOferta, 'btn_configurar_oferta');
  });

  test('los tipos de exportación y de elemento son los de la web', () {
    expect(TelemetriaInventario.exportBrochure, 'brochure');
    expect(TelemetriaInventario.exportFichaTecnica, 'ficha_tecnica');
    expect(TelemetriaInventario.tipoPagina, 'page');
    expect(TelemetriaInventario.tipoCampo, 'input');
  });
}
