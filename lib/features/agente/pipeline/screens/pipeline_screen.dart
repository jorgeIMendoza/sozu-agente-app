import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/layouts/en_construccion_layout.dart';

/// Pipeline del agente: sus ofertas y apartados por etapa.
/// Pendiente de conectar a la Edge Function `agente-pipeline`.
class PipelineScreen extends StatelessWidget {
  const PipelineScreen({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccionLayout(
    titulo: 'Pipeline',
    subtitulo: 'Ofertas y apartados por etapa',
  );
}
