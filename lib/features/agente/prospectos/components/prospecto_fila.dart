import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/etiquetas_prospecto.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/prospectos_reglas.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Fila de la cartera: el prospecto cerrado y, al abrirlo, un bloque por
/// desarrollo con su estado, la transferencia y sus unidades.
///
/// Es tonta: recibe los datos y devuelve intenciones. Quién guarda el estado o
/// abre la ficha lo decide la pantalla.
class ProspectoFila extends StatelessWidget {
  final Prospecto prospecto;

  /// Catálogo de estados de lead para el selector de cada desarrollo.
  final List<EstadoLead> estados;

  final bool expandido;

  /// Sin permiso de actualizar, el estado y la transferencia se ven pero no se
  /// pueden mover: el servidor los rechazaría igual.
  final bool puedeActualizar;

  /// Relación cuyo estado se está guardando; deshabilita solo ese selector.
  final int? relacionGuardando;

  /// Máscara del modo presentación aplicada a nombre, contacto y montos.
  final String Function(String?) oculta;

  final VoidCallback onAlternar;
  final VoidCallback onVerFicha;
  final void Function(DesarrolloDeProspecto desarrollo, int idEstado)
  onCambiarEstado;
  final void Function(DesarrolloDeProspecto desarrollo) onTransferir;

  const ProspectoFila({
    super.key,
    required this.prospecto,
    required this.estados,
    required this.expandido,
    required this.oculta,
    required this.onAlternar,
    required this.onVerFicha,
    required this.onCambiarEstado,
    required this.onTransferir,
    this.puedeActualizar = false,
    this.relacionGuardando,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final desarrollos = prospecto.desarrollos
        .map((d) => d.desarrollo)
        .where((n) => n.isNotEmpty)
        .join(' · ');

    return SCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SPressable(
            onTap: onAlternar,
            semanticLabel: expandido
                ? 'Cerrar ${prospecto.nombre}'
                : 'Abrir ${prospecto.nombre}',
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.sm,
                vertical: t.space.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    expandido ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: tone.fgMuted,
                  ),
                  SizedBox(width: t.space.xs),
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
                              oculta(prospecto.nombre),
                              style: t.text.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: tone.fg,
                              ),
                            ),
                            if (prospecto.esCliente)
                              const SBadge(
                                label: 'Cliente',
                                tone: SBadgeTone.positive,
                                size: SBadgeSize.sm,
                              ),
                          ],
                        ),
                        SizedBox(height: t.space.xxs),
                        Text(
                          oculta(prospecto.email ?? '-'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.caption.copyWith(color: tone.fgMuted),
                        ),
                        Text(
                          oculta(prospecto.telefono ?? '-'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.caption.copyWith(color: tone.fgSubtle),
                        ),
                        if (desarrollos.isNotEmpty) ...[
                          SizedBox(height: t.space.xxs),
                          Text(
                            desarrollos,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.text.caption.copyWith(color: tone.fgMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: t.space.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SBadge(
                        label: prospecto.totalUnidades == 1
                            ? '1 unidad'
                            : '${prospecto.totalUnidades} unidades',
                        size: SBadgeSize.sm,
                      ),
                      SizedBox(height: t.space.xxs),
                      IconButton(
                        tooltip: 'Ver ficha del prospecto',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        color: tone.fgMuted,
                        onPressed: onVerFicha,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expandido)
            Container(
              width: double.infinity,
              color: tone.surfaceAlt,
              padding: EdgeInsets.all(t.space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in prospecto.desarrollos) ...[
                    _BloqueDesarrollo(
                      desarrollo: d,
                      estados: estados,
                      puedeActualizar: puedeActualizar,
                      guardando: relacionGuardando == d.idRelacion,
                      oculta: oculta,
                      onCambiarEstado: (id) => onCambiarEstado(d, id),
                      onTransferir: () => onTransferir(d),
                    ),
                    if (d != prospecto.desarrollos.last)
                      SizedBox(height: t.space.sm),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Un desarrollo del prospecto: encabezado con estado y transferencia, y la
/// lista de unidades con negocio abierto.
class _BloqueDesarrollo extends StatelessWidget {
  final DesarrolloDeProspecto desarrollo;
  final List<EstadoLead> estados;
  final bool puedeActualizar;
  final bool guardando;
  final String Function(String?) oculta;
  final ValueChanged<int> onCambiarEstado;
  final VoidCallback onTransferir;

  const _BloqueDesarrollo({
    required this.desarrollo,
    required this.estados,
    required this.puedeActualizar,
    required this.guardando,
    required this.oculta,
    required this.onCambiarEstado,
    required this.onTransferir,
  });

  /// Clave del estado actual, para elegir el tono de la insignia.
  String? _claveDelEstado() {
    for (final e in estados) {
      if (e.id == desarrollo.idEstadoLead) return e.clave;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final claveEstado = _claveDelEstado();

    return SCard.outlined(
      padding: EdgeInsets.all(t.space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  desarrollo.desarrollo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone.fg,
                  ),
                ),
              ),
              if (desarrollo.estado != null)
                SBadge(
                  label: desarrollo.estado!,
                  tone: toneDeEstadoLead(claveEstado),
                  size: SBadgeSize.sm,
                ),
              IconButton(
                tooltip: puedeActualizar
                    ? 'Transferir a otro agente. Dejarás de verlo en tu cartera.'
                    : 'No tienes permiso para transferir prospectos',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.swap_horiz, size: 18),
                color: tone.fgMuted,
                onPressed: puedeActualizar ? onTransferir : null,
              ),
            ],
          ),
          SizedBox(height: t.space.xs),
          SSelectField<int>(
            label: 'Estado del lead',
            hint: desarrollo.estado ?? 'Sin estado',
            value: desarrollo.idEstadoLead,
            opciones: [for (final e in estados) (value: e.id, label: e.nombre)],
            onChanged: puedeActualizar && !guardando
                ? (v) {
                    if (v != null && v != desarrollo.idEstadoLead) {
                      onCambiarEstado(v);
                    }
                  }
                : null,
          ),
          SizedBox(height: t.space.sm),
          if (desarrollo.unidades.isEmpty)
            Text(
              'Sin unidades. Genera una oferta para abrir el negocio.',
              style: t.text.caption.copyWith(color: tone.fgSubtle),
            )
          else
            for (final u in desarrollo.unidades)
              Padding(
                padding: EdgeInsets.only(bottom: t.space.xs),
                child: _FilaUnidad(unidad: u, oculta: oculta),
              ),
        ],
      ),
    );
  }
}

/// Unidad con negocio abierto: unidad, tipo, etapa, recotizaciones y valor.
class _FilaUnidad extends StatelessWidget {
  final UnidadDeProspecto unidad;
  final String Function(String?) oculta;

  const _FilaUnidad({required this.unidad, required this.oculta});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.xs,
        vertical: t.space.xs,
      ),
      decoration: BoxDecoration(
        color: tone.surfaceAlt,
        borderRadius: t.radius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unidad.unidad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone.fg,
                  ),
                ),
              ),
              Text(
                unidad.valor == null ? '-' : oculta(formatMXN(unidad.valor)),
                style: t.text.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tone.fg,
                ),
              ),
            ],
          ),
          SizedBox(height: t.space.xxs),
          Wrap(
            spacing: t.space.xxs,
            runSpacing: t.space.xxs,
            children: [
              SBadge(label: unidad.tipo, size: SBadgeSize.sm),
              SBadge(
                label: etiquetaEtapa(unidad.etapa),
                tone: toneDeEtapa(unidad.etapa),
                size: SBadgeSize.sm,
              ),
              if (unidad.ofertas > 1)
                Tooltip(
                  message:
                      '${unidad.ofertas} ofertas sobre esta unidad '
                      '(recotizaciones con distinto esquema de pago). '
                      'Se muestra la más avanzada.',
                  child: SBadge(
                    label: '${unidad.ofertas} ofertas',
                    size: SBadgeSize.sm,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
