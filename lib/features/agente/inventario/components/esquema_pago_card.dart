import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/features/agente/inventario/services/calculo_esquema.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Tarjeta de un esquema de pago con sus montos ya calculados sobre el precio de
/// lista de la unidad, seleccionable.
///
/// Los montos los calcula [montosDeEsquema], la misma aritmética de la oferta
/// digital: si esta tarjeta y la oferta no coinciden, el agente cotiza una cosa
/// y el sistema emite otra.
class EsquemaPagoCard extends StatelessWidget {
  final EsquemaPago esquema;
  final double precioLista;

  /// Mensualidades que de verdad quedan hasta la entrega del desarrollo.
  final int mesesEfectivos;

  final bool seleccionado;
  final VoidCallback onSeleccionar;

  const EsquemaPagoCard({
    super.key,
    required this.esquema,
    required this.precioLista,
    required this.seleccionado,
    required this.onSeleccionar,
    this.mesesEfectivos = 0,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final e = esquema;
    final m = montosDeEsquema(
      e,
      precioLista,
      mesesEfectivos: mesesEfectivos,
    );
    final ajuste = e.porcentajeDescuentoAumento;

    return SPressable(
      onTap: onSeleccionar,
      borderRadius: t.radius.lgBorder,
      semanticLabel: 'Esquema ${e.nombre}',
      child: SCard.outlined(
        // El borde teñido es la única señal de selección: un check dentro de una
        // tarjeta con seis cifras se pierde.
        borderColor: seleccionado ? tone.primary : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  seleccionado
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: _iconoRadio,
                  color: seleccionado ? tone.primary : tone.fgSubtle,
                ),
                SizedBox(width: t.space.xs),
                Expanded(
                  child: Text(
                    e.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                ),
                if (ajuste != 0)
                  SBadge(
                    // Un descuento viene NEGATIVO en la base: se muestra tal
                    // cual, con su signo, porque así se firma.
                    label: '${ajuste > 0 ? '+' : ''}$ajuste%',
                    size: SBadgeSize.sm,
                    tone: ajuste < 0 ? SBadgeTone.positive : SBadgeTone.negative,
                  ),
              ],
            ),
            SizedBox(height: t.space.xs),
            Wrap(
              spacing: t.space.xxs,
              runSpacing: t.space.xxs,
              children: [
                if (e.porcentajeEnganche > 0)
                  _Pill(
                    valor: '${_pct(e.porcentajeEnganche)}%',
                    etiqueta: 'Enganche',
                  ),
                if (m.porcentajeMensualidades > 0)
                  _Pill(
                    valor: '${_pct(m.porcentajeMensualidades)}%',
                    etiqueta: 'Mensualidades',
                  ),
                if (m.porcentajeEntrega > 0)
                  _Pill(
                    valor: '${_pct(m.porcentajeEntrega)}%',
                    etiqueta: 'Entrega',
                  ),
                if (m.meses > 0)
                  _Pill(valor: '${m.meses}', etiqueta: 'meses', marca: true),
              ],
            ),
            if (precioLista > 0) ...[
              SizedBox(height: t.space.sm),
              Divider(height: 1, color: tone.border),
              SizedBox(height: t.space.xs),
              Wrap(
                spacing: t.space.lg,
                runSpacing: t.space.xs,
                children: [
                  if (m.enganche > 0)
                    _Monto(etiqueta: 'Enganche', valor: formatMXN(m.enganche)),
                  if (m.mensualidadesTotal > 0)
                    _Monto(
                      etiqueta: 'Mensualidad',
                      valor: m.meses > 0
                          ? '${formatMXN(m.mensualidad)} x ${m.meses}'
                          : formatMXN(m.mensualidad),
                    ),
                  if (m.entrega > 0)
                    _Monto(etiqueta: 'Entrega', valor: formatMXN(m.entrega)),
                  _Monto(
                    etiqueta: 'Precio final',
                    valor: formatMXN(m.precioFinal),
                    destacado: true,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Porcentaje con un decimal y sin cola de ceros: "12.5" y "20", no "20.0".
String _pct(double v) {
  final texto = v.toStringAsFixed(1);
  return texto.endsWith('.0') ? texto.substring(0, texto.length - 2) : texto;
}

/// Pill "20% Enganche" del resumen del esquema.
class _Pill extends StatelessWidget {
  final String valor;
  final String etiqueta;

  /// Tiñe con el color de marca; se usa en el plazo, que es el diferenciador.
  final bool marca;

  const _Pill({
    required this.valor,
    required this.etiqueta,
    this.marca = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: marca ? tone.primarySoftStrong : tone.muted,
        borderRadius: t.radius.smBorder,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.xs,
          vertical: t.space.xxs,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: valor,
                style: t.text.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: marca ? tone.primaryHover : tone.fg,
                ),
              ),
              TextSpan(
                text: ' $etiqueta',
                style: t.text.caption.copyWith(
                  color: marca ? tone.primaryHover : tone.fgMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Monto con su etiqueta arriba.
class _Monto extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool destacado;

  const _Monto({
    required this.etiqueta,
    required this.valor,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: t.text.overline.copyWith(
            color: destacado ? tone.primaryHover : tone.fgMuted,
          ),
        ),
        Text(
          valor,
          style: t.text.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: destacado ? tone.primaryHover : tone.fg,
          ),
        ),
      ],
    );
  }
}

const double _iconoRadio = 18;
