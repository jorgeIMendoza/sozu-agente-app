import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/layouts/en_construccion_layout.dart';

/// Buscador de unidades del inventario. Llega con el proyecto y el modelo
/// preseleccionados desde el detalle del proyecto, y con [abrirFiltros] cuando
/// el usuario entra por el atajo de "filtrar".
class UnidadesScreen extends StatelessWidget {
  final int? idProyecto;
  final int? idModelo;
  final bool abrirFiltros;

  const UnidadesScreen({
    super.key,
    this.idProyecto,
    this.idModelo,
    this.abrirFiltros = false,
  });

  @override
  Widget build(BuildContext context) {
    final contexto = [
      if (idProyecto != null) 'proyecto #$idProyecto',
      if (idModelo != null) 'modelo #$idModelo',
      if (abrirFiltros) 'con filtros abiertos',
    ];
    return EnConstruccionLayout(
      titulo: 'Unidades',
      subtitulo: 'Disponibilidad, precios y esquemas de pago',
      detalle: contexto.isEmpty ? null : 'Filtro: ${contexto.join(' · ')}',
    );
  }
}
