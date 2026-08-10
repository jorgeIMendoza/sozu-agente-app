import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/layouts/en_construccion_layout.dart';

/// Comisiones del agente: devengadas, pagadas y su comprobación fiscal. El
/// agente dependiente no llega aquí: la vista la esconde `tabsVisiblesProvider`.
/// Pendiente de conectar a la Edge Function `agente-comisiones`.
class ComisionesScreen extends StatelessWidget {
  const ComisionesScreen({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccionLayout(
    titulo: 'Comisiones',
    subtitulo: 'Devengadas, pagadas y su facturación',
  );
}
