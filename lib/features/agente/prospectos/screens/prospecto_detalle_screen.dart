import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/layouts/en_construccion_layout.dart';

/// Detalle de un prospecto: contacto, actividad y ofertas ligadas.
/// Pendiente de conectar a la Edge Function `agente-prospectos`.
class ProspectoDetalleScreen extends StatelessWidget {
  final int idPersona;

  const ProspectoDetalleScreen({super.key, required this.idPersona});

  @override
  Widget build(BuildContext context) => EnConstruccionLayout(
    titulo: 'Prospecto',
    subtitulo: 'Contacto, actividad y ofertas',
    detalle: 'Persona #$idPersona',
  );
}
