import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/galeria_imagenes.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/inventario_seccion.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Tarjeta de un modelo del desarrollo: galería, metraje, recámaras, baños,
/// precio desde, plano y el atajo a sus unidades disponibles.
class ModeloCard extends StatelessWidget {
  final ModeloDesarrollo modelo;

  /// Abre la galería del modelo a pantalla completa en la imagen `i`.
  final ValueChanged<int> onVerGaleria;

  /// Abre el plano arquitectónico del modelo. Null = el modelo no tiene plano.
  final VoidCallback? onVerPlano;

  /// Filtra el inventario por este modelo. Null = el modelo no tiene unidades
  /// disponibles, así que el atajo llevaría a una lista vacía.
  final VoidCallback? onVerUnidades;

  const ModeloCard({
    super.key,
    required this.modelo,
    required this.onVerGaleria,
    this.onVerPlano,
    this.onVerUnidades,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final m = modelo;

    return SCard.outlined(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CarruselImagenes(
            imagenes: m.multimedia,
            onTocar: onVerGaleria,
          ),
          Padding(
            padding: EdgeInsets.all(t.space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone.fg,
                  ),
                ),
                SizedBox(height: t.space.xxs),
                Wrap(
                  spacing: t.space.sm,
                  runSpacing: t.space.xxs,
                  children: [
                    if (m.m2 != null && m.m2! > 0)
                      InventarioEspec(
                        icon: Icons.straighten_outlined,
                        texto: '${m.m2!.toStringAsFixed(0)} m²',
                      ),
                    if (m.recamaras > 0)
                      InventarioEspec(
                        icon: Icons.bed_outlined,
                        texto: '${m.recamaras} rec',
                      ),
                    if (m.banos > 0)
                      InventarioEspec(
                        icon: Icons.bathtub_outlined,
                        texto: '${m.banos} baños',
                      ),
                  ],
                ),
                if (m.precioDesde != null) ...[
                  SizedBox(height: t.space.xs),
                  Text(
                    'Desde',
                    style: t.text.caption.copyWith(color: tone.fgMuted),
                  ),
                  Text(
                    formatMXN(m.precioDesde),
                    style: t.text.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                ],
                if (onVerPlano != null) ...[
                  SizedBox(height: t.space.xs),
                  SButton.ghost(
                    label: 'Ver plano',
                    icon: Icons.architecture_outlined,
                    size: SButtonSize.sm,
                    onPressed: onVerPlano,
                  ),
                ],
                if (onVerUnidades != null) ...[
                  SizedBox(height: t.space.xs),
                  SButton.secondary(
                    label: 'Ver ${m.disponibles} disponibles',
                    size: SButtonSize.sm,
                    isNavigation: true,
                    onPressed: onVerUnidades,
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
