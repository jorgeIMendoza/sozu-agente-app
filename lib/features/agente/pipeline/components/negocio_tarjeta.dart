import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/etapa_badge.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/negocio_acciones.dart';
import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Negocio en tarjeta, con lectura de producto: la unidad como título, el precio
/// como dato dominante, la etapa en pastilla y las acciones al pie.
class NegocioTarjeta extends StatelessWidget {
  final Negocio negocio;
  final EtapaPipeline etapa;
  final bool modoPresentacion;
  final AccionesNegocio acciones;

  const NegocioTarjeta({
    super.key,
    required this.negocio,
    required this.etapa,
    required this.modoPresentacion,
    required this.acciones,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final faltaRazon = etapa.esPerdido && negocio.razonNoAvance == null;

    return SPressable(
      onTap: () => acciones.verDetalle(negocio),
      borderRadius: t.radius.lgBorder,
      hoverLift: true,
      child: SCard(
        padding: EdgeInsets.zero,
        clip: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: tone.surfaceAlt,
              padding: EdgeInsets.symmetric(
                horizontal: t.space.sm,
                vertical: t.space.xs,
              ),
              child: Row(
                children: [
                  SBadge(
                    label: negocio.esProducto ? 'Producto' : 'Propiedad',
                    size: SBadgeSize.sm,
                  ),
                  const Spacer(),
                  EtapaBadge(etapa: etapa),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(t.space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    negocio.unidad.isEmpty ? '-' : negocio.unidad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                  Text(
                    [
                      negocio.proyectoNombre.isEmpty
                          ? 'Sin desarrollo'
                          : negocio.proyectoNombre,
                      if (negocio.cuentaFolio != null) negocio.cuentaFolio!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.caption.copyWith(color: tone.fgMuted),
                  ),
                  SizedBox(height: t.space.xs),
                  Text(
                    negocio.precio == null
                        ? '-'
                        : mascara(
                            formatMXN(negocio.precio),
                            activo: modoPresentacion,
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                  Divider(color: tone.borderSoft, height: t.space.lg),
                  Text(
                    mascara(negocio.lead.nombre, activo: modoPresentacion),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tone.fg,
                    ),
                  ),
                  Text(
                    mascara(
                      negocio.lead.email ?? 'Sin correo',
                      activo: modoPresentacion,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.caption.copyWith(color: tone.fgSubtle),
                  ),
                  SizedBox(height: t.space.xs),
                  Wrap(
                    spacing: t.space.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        negocio.folio,
                        style: t.text.overline.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tone.primary,
                        ),
                      ),
                      Text(
                        '· ${formatDateEsMX(negocio.fechaGeneracion)}',
                        style: t.text.overline.copyWith(color: tone.fgSubtle),
                      ),
                      if (negocio.ofertasCount > 1)
                        SBadge(
                          label: '${negocio.ofertasCount} versiones',
                          size: SBadgeSize.sm,
                        ),
                    ],
                  ),
                  if (faltaRazon) ...[
                    SizedBox(height: t.space.xs),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: t.space.xs,
                        vertical: t.space.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: tone.warningSoft,
                        borderRadius: t.radius.smBorder,
                      ),
                      child: Text(
                        'Falta registrar por qué no avanzó',
                        style: t.text.overline.copyWith(color: tone.warningFg),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.xs,
                vertical: t.space.xxs,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tone.borderSoft)),
              ),
              child: BarraAccionesNegocio(
                negocio: negocio,
                acciones: acciones,
                esPerdido: etapa.esPerdido,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
