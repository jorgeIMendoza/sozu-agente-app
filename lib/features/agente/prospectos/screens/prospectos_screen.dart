import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/layouts/en_construccion_layout.dart';

/// Cartera de prospectos del agente.
/// Pendiente de conectar a la Edge Function `agente-prospectos`.
class ProspectosScreen extends StatelessWidget {
  const ProspectosScreen({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccionLayout(
    titulo: 'Prospectos',
    subtitulo: 'Cartera de leads y su seguimiento',
  );
}
