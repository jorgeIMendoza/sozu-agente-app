import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Fila de la lista "Secciones de tu perfil": título, insignia de avance,
/// descripción y chevron.
///
/// Vive en `components/` de la feature y no en `lib/ui/`: es la fila del Perfil,
/// con su semántica de avance, no un renglón de lista genérico.
class PerfilFilaSeccion extends StatelessWidget {
  final String titulo;
  final String descripcion;

  /// Avance de la sección; null la deja sin insignia (Seguridad).
  final EstadoPaso? estado;

  /// La administra la inmobiliaria: la insignia dice "Solo lectura" y sustituye
  /// al avance, porque para el agente no hay nada que completar.
  final bool soloLectura;

  final VoidCallback onTap;

  const PerfilFilaSeccion({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
    this.estado,
    this.soloLectura = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return SPressable(
      onTap: onTap,
      isNavigation: true,
      borderRadius: t.radius.mdBorder,
      semanticLabel: titulo,
      child: SCard.outlined(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: t.space.xs,
                    runSpacing: t.space.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        titulo,
                        style: t.text.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tone.fg,
                        ),
                      ),
                      if (soloLectura)
                        const SBadge(
                          label: 'Solo lectura',
                          tone: SBadgeTone.neutral,
                          size: SBadgeSize.sm,
                        )
                      else if (estado != null)
                        SBadge(
                          label: estado!.etiqueta,
                          tone: tonoDeAvance(estado!),
                          size: SBadgeSize.sm,
                        ),
                    ],
                  ),
                  SizedBox(height: t.space.xxs),
                  Text(
                    descripcion,
                    style: t.text.overline.copyWith(
                      fontWeight: FontWeight.w500,
                      color: tone.fgSubtle,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: t.space.xs),
            Icon(Icons.chevron_right, size: 18, color: tone.fgSubtle),
          ],
        ),
      ),
    );
  }
}

/// Tono de la insignia de avance de una sección o de un paso de activación.
SBadgeTone tonoDeAvance(EstadoPaso estado) => switch (estado) {
  EstadoPaso.completo => SBadgeTone.positive,
  EstadoPaso.parcial => SBadgeTone.pending,
  EstadoPaso.pendiente => SBadgeTone.neutral,
};

/// Tono de la insignia de estatus de un documento del expediente.
SBadgeTone tonoDeDocumento(EstadoDocumento estado) => switch (estado) {
  EstadoDocumento.validado => SBadgeTone.positive,
  EstadoDocumento.revision => SBadgeTone.pending,
  EstadoDocumento.rechazado => SBadgeTone.negative,
  EstadoDocumento.expirado || EstadoDocumento.pendiente => SBadgeTone.neutral,
};

/// Tono de la insignia de una cita de capacitación.
SBadgeTone tonoDeCita(TonoCita tono) => switch (tono) {
  TonoCita.exito => SBadgeTone.positive,
  TonoCita.advertencia => SBadgeTone.pending,
  TonoCita.peligro => SBadgeTone.negative,
  // "Agendada" es informativo, no un logro: el design system no tiene tono
  // informativo para insignias, y el neutro es más honesto que pintarla verde.
  TonoCita.info || TonoCita.neutral => SBadgeTone.neutral,
};
