import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/home/ports/inicio_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Distintivo de la cita como insignia del sistema.
///
/// `TonoCita.info` ("Agendada") cae en el tono neutro porque el design system no
/// tiene un tono informativo: para que no se confunda con "Sin confirmar", que
/// también es neutro, cada estado lleva su icono.
({SBadgeTone tono, IconData icono}) insigniaDeCita(TonoCita tono) =>
    switch (tono) {
      TonoCita.exito => (
        tono: SBadgeTone.positive,
        icono: Icons.check_circle_outline,
      ),
      TonoCita.alerta => (
        tono: SBadgeTone.negative,
        icono: Icons.cancel_outlined,
      ),
      TonoCita.info => (
        tono: SBadgeTone.neutral,
        icono: Icons.event_available_outlined,
      ),
      TonoCita.neutro => (
        tono: SBadgeTone.neutral,
        icono: Icons.help_outline,
      ),
    };

/// Fecha y hora de la cita en una línea: "15 ago 2026 · 10:00 - 11:00".
String cuandoEsLaCita(CitaAgente cita) {
  final fecha = formatDateEsMX(cita.fecha);
  final horario = cita.horario;
  return horario == null ? fecha : '$fecha · $horario';
}

/// Una cita de la agenda en la lista de Inicio. Al tocarla se abre su detalle.
class TarjetaCita extends StatelessWidget {
  final CitaAgente cita;

  /// Nombre del prospecto ya enmascarado por la pantalla cuando el modo
  /// presentación está activo.
  final String? nombreProspecto;

  final VoidCallback onTap;

  const TarjetaCita({
    super.key,
    required this.cita,
    required this.onTap,
    this.nombreProspecto,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final insignia = insigniaDeCita(cita.distintivo.tono);

    // El icono se tiñe por lo que ya pasó, no por el tipo de cita: verde si
    // asistió, gris si no, ámbar mientras sigue pendiente de suceder.
    final (Color fondoIcono, Color colorIcono) = switch (cita.estatus) {
      'asistio' => (tone.primarySoftStrong, tone.primaryHover),
      'no_asistio' => (tone.muted, tone.fgSubtle),
      _ => (tone.warningSoft, tone.warningFg),
    };

    final prospecto = nombreProspecto;

    return SPressable(
      onTap: onTap,
      borderRadius: t.radius.lgBorder,
      hoverLift: true,
      semanticLabel:
          '${cita.titulo}. ${cita.distintivo.etiqueta}. '
          '${cuandoEsLaCita(cita)}',
      child: SCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fondoIcono,
                borderRadius: t.radius.mdBorder,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: colorIcono,
              ),
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          cita.titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tone.fg,
                          ),
                        ),
                      ),
                      SizedBox(width: t.space.xs),
                      SBadge(
                        label: cita.distintivo.etiqueta,
                        tone: insignia.tono,
                        icon: insignia.icono,
                        size: SBadgeSize.sm,
                      ),
                    ],
                  ),
                  if (prospecto != null && prospecto.isNotEmpty) ...[
                    SizedBox(height: t.space.xxs),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: tone.fgSubtle,
                        ),
                        SizedBox(width: t.space.xxs),
                        Expanded(
                          child: Text(
                            prospecto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.text.caption.copyWith(color: tone.fgMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: t.space.xxs),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 14,
                        color: tone.fgSubtle,
                      ),
                      SizedBox(width: t.space.xxs),
                      Expanded(
                        child: Text(
                          cuandoEsLaCita(cita),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.caption.copyWith(color: tone.fgMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
