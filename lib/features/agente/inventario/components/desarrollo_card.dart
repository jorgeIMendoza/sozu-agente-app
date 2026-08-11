import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/inventario_seccion.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/network_image.dart';

/// Tarjeta de un desarrollo en el inventario: portada, disponibilidad, precio
/// desde, totales y las tres acciones (ver ficha, ver unidades, compartir).
///
/// La imagen NO navega a propósito: los botones son la única forma de salir de
/// la tarjeta, para que "Compartir" no dispare además la navegación (era el bug
/// del portal web antes de separarlos).
class DesarrolloCard extends StatelessWidget {
  final DesarrolloResumen desarrollo;

  /// Sin permiso de lectura no se pintan las acciones: la tarjeta queda
  /// informativa.
  final bool puedeVer;

  final VoidCallback onVerFicha;
  final VoidCallback onVerUnidades;
  final VoidCallback onCompartir;

  const DesarrolloCard({
    super.key,
    required this.desarrollo,
    required this.onVerFicha,
    required this.onVerUnidades,
    required this.onCompartir,
    this.puedeVer = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final d = desarrollo;

    return SCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: _aspectoPortada,
                child: SozuNetworkImage(url: d.imagenUrl),
              ),
              Positioned(
                top: t.space.xs,
                right: t.space.xs,
                child: d.agotado
                    ? const SBadge(
                        label: 'Agotado',
                        tone: SBadgeTone.negative,
                        size: SBadgeSize.sm,
                      )
                    : SBadge(
                        label: '${d.unidadesDisponibles} disponibles',
                        tone: SBadgeTone.positive,
                        size: SBadgeSize.sm,
                      ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(t.space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.h3.copyWith(color: tone.fg),
                ),
                if (d.ubicacion.isNotEmpty) ...[
                  SizedBox(height: t.space.xxs),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: _iconoUbicacion,
                        color: tone.fgSubtle,
                      ),
                      SizedBox(width: t.space.xxs),
                      Expanded(
                        child: Text(
                          d.ubicacion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.caption.copyWith(color: tone.fgMuted),
                        ),
                      ),
                    ],
                  ),
                ],
                if (!d.agotado && d.precioDesde != null) ...[
                  SizedBox(height: t.space.xs),
                  Text(
                    'Desde ${formatMXN(d.precioDesde)}',
                    style: t.text.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.primaryHover,
                    ),
                  ),
                ],
                SizedBox(height: t.space.sm),
                Row(
                  children: [
                    InventarioDato(
                      etiqueta: 'Total unidades',
                      valor: '${d.totalUnidades}',
                    ),
                    SizedBox(width: t.space.lg),
                    InventarioDato(
                      etiqueta: 'Avance',
                      valor: '${d.avancePct}%',
                    ),
                  ],
                ),
                if (d.estatus != null) ...[
                  SizedBox(height: t.space.xs),
                  SProgressBar(
                    percent: d.avancePct.toDouble(),
                    thickness: SProgressBarThickness.thin,
                    semanticsLabel: 'Avance de obra',
                  ),
                  SizedBox(height: t.space.xxs),
                  Text(
                    d.estatus!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.caption.copyWith(color: tone.fgSubtle),
                  ),
                ],
                if (puedeVer) ...[
                  SizedBox(height: t.space.md),
                  Row(
                    children: [
                      Expanded(
                        child: SButton.secondary(
                          label: 'Ver',
                          icon: Icons.visibility_outlined,
                          size: SButtonSize.sm,
                          isNavigation: true,
                          onPressed: onVerFicha,
                        ),
                      ),
                      if (!d.agotado) ...[
                        SizedBox(width: t.space.xs),
                        Expanded(
                          child: SButton.secondary(
                            label: 'Unidades',
                            icon: Icons.apartment_outlined,
                            size: SButtonSize.sm,
                            isNavigation: true,
                            onPressed: onVerUnidades,
                          ),
                        ),
                      ],
                      SizedBox(width: t.space.xs),
                      IconButton(
                        tooltip: 'Compartir',
                        icon: const Icon(Icons.share_outlined),
                        color: tone.primaryHover,
                        onPressed: onCompartir,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Silueta de [DesarrolloCard] mientras carga la lista. Respeta la misma
/// proporción de portada para que la rejilla no salte al llegar los datos.
class DesarrolloCardSkeleton extends StatelessWidget {
  const DesarrolloCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return SCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AspectRatio(
            aspectRatio: _aspectoPortada,
            child: SSkeleton(height: double.infinity, radius: 0),
          ),
          Padding(
            padding: EdgeInsets.all(t.space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SSkeleton(width: 160, height: 18),
                SizedBox(height: t.space.xs),
                const SSkeleton(width: 120, height: 12),
                SizedBox(height: t.space.sm),
                const SSkeleton(width: 100, height: 14),
                SizedBox(height: t.space.md),
                const SSkeleton(height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Portada 16:9, la proporción con la que se suben las fotos de desarrollo.
const double _aspectoPortada = 16 / 9;
const double _iconoUbicacion = 14;
