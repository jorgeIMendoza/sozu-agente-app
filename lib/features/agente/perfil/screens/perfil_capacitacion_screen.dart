import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/layouts/en_construccion_layout.dart';

/// Capacitación del agente: sin ella no se puede generar oferta
/// (`Onboarding.capacitacionCompleta`).
/// Pendiente de conectar a la Edge Function `agente-perfil`.
class PerfilCapacitacionScreen extends StatelessWidget {
  const PerfilCapacitacionScreen({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccionLayout(
    titulo: 'Capacitación',
    subtitulo: 'Cursos y constancia de acreditación',
  );
}
