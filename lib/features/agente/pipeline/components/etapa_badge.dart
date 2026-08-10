import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Etapa de un negocio como insignia del sistema, con candado cuando la mueve
/// el sistema.
///
/// Los colores por etapa de la web (10 pastillas distintas) se traducen a los
/// cuatro tonos semánticos del design system: lo que importa es si el negocio
/// va bien, está en curso o se cerró perdido.
class EtapaBadge extends StatelessWidget {
  final EtapaPipeline etapa;
  final SBadgeSize size;

  const EtapaBadge({super.key, required this.etapa, this.size = SBadgeSize.sm});

  @override
  Widget build(BuildContext context) {
    final badge = SBadge(
      label: etapa.nombre,
      tone: tonoDeEtapa(etapa),
      size: size,
      icon: etapa.automatica ? Icons.lock_outline : null,
    );
    if (!etapa.automatica) return badge;
    return Tooltip(
      message:
          'La mueve el sistema con un hecho real: la oferta, el apartado '
          'aplicado o el estatus de la propiedad.',
      child: badge,
    );
  }
}

/// Tono de la etapa por lo que significa para el negocio.
SBadgeTone tonoDeEtapa(EtapaPipeline etapa) => switch (etapa.clave) {
  'ganado' => SBadgeTone.positive,
  'perdido' => SBadgeTone.negative,
  'oferta_enviada' ||
  'apartado_pagado' ||
  'enganche_contrato' => SBadgeTone.pending,
  _ => SBadgeTone.neutral,
};

/// Etapa del catálogo por su clave. Si el ambiente no la trae, se pinta la
/// clave tal cual en vez de dejar la celda vacía: un negocio sin etapa visible
/// se reporta como dato perdido.
EtapaPipeline etapaResuelta(Map<String, EtapaPipeline> etapas, String clave) =>
    etapas[clave] ?? EtapaPipeline(clave: clave, nombre: clave);
