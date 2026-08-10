import 'package:flutter/material.dart';

import 'package:sozu_agente_app/ui/ui.dart';

/// Lectura del número: [logro] para dinero ya cobrado o ventas cerradas,
/// [pendiente] para lo que todavía está en proceso, [neutro] para conteos que no
/// son ni buenos ni malos.
enum TonoKpi { logro, pendiente, neutro }

/// Uno de los cuatro números del tablero del agente.
///
/// El valor llega YA formateado y ya enmascarado: la tarjeta no sabe de moneda ni
/// de modo presentación, solo de jerarquía visual.
class TarjetaKpi extends StatelessWidget {
  final String etiqueta;
  final String valor;

  /// Aclara la unidad del número ("cobrado", "en proceso"). Sin esto,
  /// "Comisión pendiente $12,000" no dice si son por cobrar o ya cobradas.
  final String detalle;

  final TonoKpi tono;

  /// Los cuatro números llevan a Comisiones: es donde está el desglose que
  /// contesta la pregunta que dispara el número.
  final VoidCallback? onTap;

  const TarjetaKpi({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.detalle,
    this.tono = TonoKpi.neutro,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    final colorValor = switch (tono) {
      TonoKpi.logro => tone.positive,
      TonoKpi.pendiente => tone.warningFg,
      TonoKpi.neutro => tone.fg,
    };

    final contenido = SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.overline.copyWith(color: tone.fgMuted),
          ),
          SizedBox(height: t.space.xs),
          // Un monto de siete cifras no cabe en media pantalla de teléfono:
          // encoger es preferible a truncar, porque un monto cortado se lee mal
          // y engaña.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: t.text.h3.copyWith(
                fontWeight: FontWeight.w700,
                color: colorValor,
                fontFeatures: SozuType.tabular,
              ),
            ),
          ),
          SizedBox(height: t.space.xxs),
          Text(
            detalle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.caption.copyWith(color: tone.fgSubtle),
          ),
        ],
      ),
    );

    if (onTap == null) return contenido;
    return SPressable(
      onTap: onTap,
      borderRadius: t.radius.lgBorder,
      hoverLift: true,
      semanticLabel: '$etiqueta: $valor, $detalle',
      child: contenido,
    );
  }
}
