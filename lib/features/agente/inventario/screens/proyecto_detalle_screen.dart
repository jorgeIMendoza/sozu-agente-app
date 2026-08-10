import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/layouts/en_construccion_layout.dart';

/// Detalle de un proyecto del inventario: ficha, amenidades y modelos.
/// Pendiente de conectar a la Edge Function `agente-inventario`.
class ProyectoDetalleScreen extends StatelessWidget {
  final int idProyecto;

  const ProyectoDetalleScreen({super.key, required this.idProyecto});

  @override
  Widget build(BuildContext context) => EnConstruccionLayout(
    titulo: 'Proyecto',
    subtitulo: 'Ficha del proyecto y sus modelos',
    detalle: 'Proyecto #$idProyecto',
  );
}
