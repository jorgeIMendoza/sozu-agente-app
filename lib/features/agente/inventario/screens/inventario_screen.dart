import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/layouts/en_construccion_layout.dart';

/// Inventario del agente: proyectos con unidades disponibles para vender.
/// Pendiente de conectar a la Edge Function `agente-inventario`.
class InventarioScreen extends StatelessWidget {
  const InventarioScreen({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccionLayout(
    titulo: 'Inventario',
    subtitulo: 'Proyectos y unidades disponibles',
  );
}
