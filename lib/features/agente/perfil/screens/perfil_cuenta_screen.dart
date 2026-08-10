import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/layouts/en_construccion_layout.dart';

/// Datos de la cuenta del agente: correo, teléfono y preferencias de acceso.
/// Pendiente de conectar a la Edge Function `agente-perfil`.
class PerfilCuentaScreen extends StatelessWidget {
  const PerfilCuentaScreen({super.key});

  @override
  Widget build(BuildContext context) => const EnConstruccionLayout(
    titulo: 'Mi cuenta',
    subtitulo: 'Correo, teléfono y acceso',
  );
}
