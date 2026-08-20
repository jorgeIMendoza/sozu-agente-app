import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/nota_html_vista.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Actividad del prospecto: notas, citas y ofertas en una sola línea de tiempo.
///
/// El punto de color dice de qué es cada movimiento; los archivos de una nota
/// se abren en el visor de la app, no en el navegador.
class ActividadProspectoLista extends StatelessWidget {
  final List<ActividadProspecto> actividad;

  /// Abre una nota propia para editarla o borrarla.
  final void Function(ActividadProspecto nota) onAbrirNota;

  /// Abre una nota larga completa, en solo lectura.
  final void Function(ActividadProspecto nota) onVerNota;

  final void Function(AdjuntoNota adjunto) onVerAdjunto;

  const ActividadProspectoLista({
    super.key,
    required this.actividad,
    required this.onAbrirNota,
    required this.onVerNota,
    required this.onVerAdjunto,
  });

  @override
  Widget build(BuildContext context) {
    if (actividad.isEmpty) {
      return const SEmptyState(
        icon: Icons.history_outlined,
        title: 'Aún no hay actividad',
        message:
            'Las notas que escribas, sus citas y sus ofertas aparecen aquí.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < actividad.length; i++)
          _Movimiento(
            item: actividad[i],
            ultimo: i == actividad.length - 1,
            onAbrirNota: () => onAbrirNota(actividad[i]),
            onVerNota: () => onVerNota(actividad[i]),
            onVerAdjunto: onVerAdjunto,
          ),
      ],
    );
  }
}

class _Movimiento extends StatelessWidget {
  final ActividadProspecto item;
  final bool ultimo;
  final VoidCallback onAbrirNota;
  final VoidCallback onVerNota;
  final void Function(AdjuntoNota adjunto) onVerAdjunto;

  const _Movimiento({
    required this.item,
    required this.ultimo,
    required this.onAbrirNota,
    required this.onVerNota,
    required this.onVerAdjunto,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final color = switch (item.tipo) {
      TipoActividad.cita => tone.info,
      TipoActividad.nota => tone.warning,
      TipoActividad.oferta => tone.primary,
    };
    final icono = switch (item.tipo) {
      TipoActividad.cita => Icons.event_outlined,
      TipoActividad.nota => Icons.sticky_note_2_outlined,
      TipoActividad.oferta => Icons.description_outlined,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color),
              ),
              child: Icon(icono, size: 14, color: color),
            ),
            if (!ultimo)
              Container(width: 2, height: t.space.xl, color: tone.border),
          ],
        ),
        SizedBox(width: t.space.sm),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: ultimo ? 0 : t.space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.titulo,
                        style: t.text.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tone.fg,
                        ),
                      ),
                    ),
                    if (item.esNotaPropia) ...[
                      // Solo cuando la nota no cabe recortada: en una nota de
                      // una línea, "Ver detalle" no muestra nada nuevo.
                      if (item.notaLarga)
                        TextButton(
                          onPressed: onVerNota,
                          child: Text(
                            'Ver detalle',
                            style: t.text.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: tone.primaryHover,
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: onAbrirNota,
                        child: Text(
                          'Editar',
                          style: t.text.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: tone.warningFg,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  _fechaYHora(context, item.fecha),
                  style: t.text.caption.copyWith(color: tone.fgSubtle),
                ),
                if (item.detalle.isNotEmpty || item.html.isNotEmpty) ...[
                  SizedBox(height: t.space.xxs),
                  // Recortado a 3 líneas como en la web: la nota completa se ve
                  // con "Ver detalle".
                  NotaHtmlVista.recortada(
                    html: item.html,
                    textoPlano: item.detalle,
                  ),
                ],
                if (item.adjuntos.isNotEmpty) ...[
                  SizedBox(height: t.space.xs),
                  Wrap(
                    spacing: t.space.xs,
                    runSpacing: t.space.xs,
                    children: [
                      for (final a in item.adjuntos)
                        SPressable(
                          onTap: () => onVerAdjunto(a),
                          borderRadius: t.radius.fullBorder,
                          semanticLabel: 'Ver ${a.nombre}',
                          child: SBadge(
                            label: a.esImagen ? 'Imagen' : a.nombre,
                            icon: a.esImagen
                                ? Icons.image_outlined
                                : Icons.attach_file_outlined,
                            size: SBadgeSize.sm,
                          ),
                        ),
                    ],
                  ),
                ],
                if (item.autor != null && item.autor!.isNotEmpty) ...[
                  SizedBox(height: t.space.xxs),
                  Text(
                    item.autor!,
                    style: t.text.caption.copyWith(color: tone.fgSubtle),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// "11 feb 2026 · 9:30 a.m." con la hora en el formato del sistema.
  String _fechaYHora(BuildContext context, DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    final local = fecha.toLocal();
    final hora = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '${formatDateEsMX(local)} · $hora';
  }
}
