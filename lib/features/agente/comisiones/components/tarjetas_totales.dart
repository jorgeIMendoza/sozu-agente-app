import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Total cobrado y por cobrar, lado a lado.
///
/// Son dos cifras y no una suma: lo que el agente quiere saber al abrir la
/// pantalla es cuánto ya entró y cuánto está esperando, y el total de ambos no
/// contesta ninguna de las dos.
class TarjetasTotales extends StatelessWidget {
  final TotalesComisiones totales;

  /// Aplica el modo presentación. La pantalla lo inyecta para que este
  /// componente no dependa de Riverpod.
  final String Function(String) enmascarar;

  const TarjetasTotales({
    super.key,
    required this.totales,
    required this.enmascarar,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // IntrinsicHeight y no `stretch` a secas: en un ListView la fila no tiene
    // alto acotado, y estirar contra infinito revienta el layout. Las dos
    // tarjetas siguen midiendo lo mismo, que es lo que se buscaba.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Total(
              etiqueta: 'Total cobrado',
              valor: enmascarar(formatMXN(totales.cobrado)),
              detalle: 'MXN · acumulado',
              destacado: true,
            ),
          ),
          SizedBox(width: t.space.sm),
          Expanded(
            child: _Total(
              etiqueta: 'Por cobrar',
              valor: enmascarar(formatMXN(totales.porCobrar)),
              detalle: 'MXN · en proceso',
            ),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String detalle;

  /// El dinero ya cobrado va teñido de marca: es el número que el agente vino a
  /// ver.
  final bool destacado;

  const _Total({
    required this.etiqueta,
    required this.valor,
    required this.detalle,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return SCard(
      borderColor: destacado ? tone.primaryBorder : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.overline.copyWith(
              color: destacado ? tone.primaryHover : tone.fgMuted,
            ),
          ),
          SizedBox(height: t.space.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: t.text.h2.copyWith(
                fontWeight: FontWeight.w700,
                color: destacado ? tone.primaryHover : tone.fg,
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
  }
}
