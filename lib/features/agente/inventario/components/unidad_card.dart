import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/inventario_seccion.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/network_image.dart';

/// Tarjeta de una unidad disponible: foto, número, modelo, desarrollo y nivel,
/// precio total y sus especificaciones.
class UnidadCard extends StatelessWidget {
  final Unidad unidad;
  final VoidCallback onTocar;

  const UnidadCard({super.key, required this.unidad, required this.onTocar});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final u = unidad;

    return SPressable(
      onTap: onTocar,
      borderRadius: t.radius.lgBorder,
      semanticLabel: 'Unidad ${u.etiqueta}',
      child: SCard(
        padding: EdgeInsets.zero,
        clip: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: _aspectoFoto,
                  child: SozuNetworkImage(
                    url: u.imagenes.isEmpty ? null : u.imagenes.first,
                    placeholderIcon: Icons.inventory_2_outlined,
                  ),
                ),
                Positioned(
                  top: t.space.xs,
                  right: t.space.xs,
                  child: SBadge(
                    label: 'Depto. ${u.etiqueta}',
                    size: SBadgeSize.sm,
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(t.space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.modeloNombre ?? 'Depto. ${u.etiqueta}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                  Text(
                    [
                      if ((u.desarrolloNombre ?? '').isNotEmpty)
                        u.desarrolloNombre!,
                      if ((u.nivel ?? '').isNotEmpty) 'Nivel ${u.nivel}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.caption.copyWith(color: tone.fgMuted),
                  ),
                  // El total (lista + bodegas + estacionamientos) es el número
                  // que el agente le dice al cliente; el de lista se cotizaba
                  // de menos.
                  if (u.precioAlCliente > 0) ...[
                    SizedBox(height: t.space.xs),
                    Text(
                      formatMXN(u.precioAlCliente),
                      style: t.text.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tone.primaryHover,
                      ),
                    ),
                  ],
                  SizedBox(height: t.space.xs),
                  Divider(height: 1, color: tone.border),
                  SizedBox(height: t.space.xs),
                  Wrap(
                    spacing: t.space.sm,
                    runSpacing: t.space.xxs,
                    children: especificacionesDeUnidad(u, breves: true),
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

/// Especificaciones de una unidad como lista de chips.
///
/// Con [breves] solo va el número (la tarjeta ya está cargada de texto); sin él
/// se escribe la unidad completa, para el detalle.
List<Widget> especificacionesDeUnidad(Unidad u, {bool breves = false}) => [
  if (u.m2Total > 0)
    InventarioEspec(
      icon: Icons.straighten_outlined,
      texto: '${u.m2Total.toStringAsFixed(breves ? 1 : 2)} m²',
    ),
  if (u.recamaras > 0)
    InventarioEspec(
      icon: Icons.bed_outlined,
      texto: breves ? '${u.recamaras}' : '${u.recamaras} rec.',
    ),
  if (u.banos > 0)
    InventarioEspec(
      icon: Icons.bathtub_outlined,
      texto: breves ? '${u.banos}' : '${u.banos} baño${u.banos > 1 ? 's' : ''}',
    ),
  if (!breves && u.medioBanos > 0)
    InventarioEspec(
      icon: Icons.shower_outlined,
      texto: '${u.medioBanos} ½ baño',
    ),
  if (u.bodegas > 0)
    InventarioEspec(
      icon: Icons.warehouse_outlined,
      texto: breves
          ? '${u.bodegas}'
          : '${u.bodegas} bodega${u.bodegas > 1 ? 's' : ''}',
    ),
  if (u.estacionamientos > 0)
    InventarioEspec(
      icon: Icons.directions_car_outlined,
      texto: breves
          ? '${u.estacionamientos}'
          : '${u.estacionamientos} estac.'
                '${u.tiposEstacionamiento.isEmpty ? '' : ' (${u.tiposEstacionamiento.toSet().join(', ')})'}',
    ),
];

/// Silueta de [UnidadCard] mientras carga la página.
class UnidadCardSkeleton extends StatelessWidget {
  const UnidadCardSkeleton({super.key});

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
            aspectRatio: _aspectoFoto,
            child: SSkeleton(height: double.infinity, radius: 0),
          ),
          Padding(
            padding: EdgeInsets.all(t.space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SSkeleton(width: 140, height: 16),
                SizedBox(height: t.space.xs),
                const SSkeleton(width: 100, height: 12),
                SizedBox(height: t.space.sm),
                const SSkeleton(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto 16:9, la proporción de los renders de unidad.
const double _aspectoFoto = 16 / 9;
