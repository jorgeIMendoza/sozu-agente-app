import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/etapa_badge.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/negocio_acciones.dart';
import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Anchos de columna. La tabla es más ancha que un teléfono a propósito: es la
/// misma cuadrícula de la web y se recorre en horizontal, que es más honesto que
/// esconder columnas y dejar al agente sin el valor o el folio.
const double _wUnidad = 220;
const double _wTipo = 124;
const double _wProspecto = 190;
const double _wEtapa = 196;
const double _wValor = 128;
const double _wOferta = 136;
const double _wAcciones = 184;
const double _anchoTotal =
    _wUnidad + _wTipo + _wProspecto + _wEtapa + _wValor + _wOferta + _wAcciones;

/// Alto de una fila.
const double _altoFila = 56;

/// Negocios en tabla: un renglón por unidad, el estándar de las pantallas de
/// cobranza del portal.
class NegocioTabla extends StatelessWidget {
  final List<Negocio> negocios;
  final Map<String, EtapaPipeline> etapas;
  final bool modoPresentacion;
  final AccionesNegocio acciones;

  const NegocioTabla({
    super.key,
    required this.negocios,
    required this.etapas,
    required this.modoPresentacion,
    required this.acciones,
  });

  @override
  Widget build(BuildContext context) {
    return SCard.outlined(
      padding: EdgeInsets.zero,
      clip: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          // El ancho incluye el gutter de las filas: sin sumarlo, la última
          // columna se desborda por el padding horizontal.
          width: _anchoTotal + context.s.space.sm * 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Encabezado(),
              for (final negocio in negocios)
                _Fila(
                  negocio: negocio,
                  etapa: etapaResuelta(etapas, negocio.etapa),
                  modoPresentacion: modoPresentacion,
                  acciones: acciones,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      color: t.color.surfaceAlt,
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm,
        vertical: t.space.xs,
      ),
      child: Row(
        children: const [
          _Celda(ancho: _wUnidad, child: SSectionLabel.inline(text: 'Desarrollo · Unidad')),
          _Celda(ancho: _wTipo, alinear: Alignment.center, child: SSectionLabel.inline(text: 'Tipo')),
          _Celda(ancho: _wProspecto, child: SSectionLabel.inline(text: 'Prospecto')),
          _Celda(ancho: _wEtapa, alinear: Alignment.center, child: SSectionLabel.inline(text: 'Etapa')),
          _Celda(ancho: _wValor, alinear: Alignment.centerRight, child: SSectionLabel.inline(text: 'Valor')),
          _Celda(ancho: _wOferta, alinear: Alignment.center, child: SSectionLabel.inline(text: 'Oferta')),
          _Celda(ancho: _wAcciones, child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final Negocio negocio;
  final EtapaPipeline etapa;
  final bool modoPresentacion;
  final AccionesNegocio acciones;

  const _Fila({
    required this.negocio,
    required this.etapa,
    required this.modoPresentacion,
    required this.acciones,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return SPressable(
      onTap: () => acciones.verDetalle(negocio),
      pressScale: false,
      borderRadius: BorderRadius.zero,
      child: Container(
        height: _altoFila,
        padding: EdgeInsets.symmetric(horizontal: t.space.sm),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tone.borderSoft)),
        ),
        child: Row(
          children: [
            _Celda(
              ancho: _wUnidad,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    negocio.proyectoNombre.isEmpty
                        ? 'Sin desarrollo'
                        : negocio.proyectoNombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tone.fg,
                    ),
                  ),
                  Text(
                    [
                      negocio.unidad.isEmpty ? '-' : negocio.unidad,
                      if (negocio.cuentaFolio != null) negocio.cuentaFolio!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.overline.copyWith(color: tone.fgSubtle),
                  ),
                ],
              ),
            ),
            _Celda(
              ancho: _wTipo,
              alinear: Alignment.center,
              child: SBadge(
                label: negocio.esProducto ? 'Producto' : 'Propiedad',
                size: SBadgeSize.sm,
              ),
            ),
            _Celda(
              ancho: _wProspecto,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mascara(negocio.lead.nombre, activo: modoPresentacion),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.caption.copyWith(
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
                    style: t.text.overline.copyWith(color: tone.fgSubtle),
                  ),
                ],
              ),
            ),
            _Celda(
              ancho: _wEtapa,
              alinear: Alignment.center,
              child: EtapaBadge(etapa: etapa),
            ),
            _Celda(
              ancho: _wValor,
              alinear: Alignment.centerRight,
              child: Text(
                negocio.precio == null
                    ? '-'
                    : mascara(
                        formatMXN(negocio.precio),
                        activo: modoPresentacion,
                      ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.text.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tone.fg,
                ),
              ),
            ),
            _Celda(
              ancho: _wOferta,
              alinear: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    negocio.folio,
                    style: t.text.overline.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.primary,
                    ),
                  ),
                  Text(
                    [
                      formatDateEsMX(negocio.fechaGeneracion),
                      if (negocio.ofertasCount > 1)
                        '${negocio.ofertasCount} versiones',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.overline.copyWith(color: tone.fgSubtle),
                  ),
                ],
              ),
            ),
            _Celda(
              ancho: _wAcciones,
              alinear: Alignment.centerRight,
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

class _Celda extends StatelessWidget {
  final double ancho;
  final Widget child;
  final Alignment alinear;

  const _Celda({
    required this.ancho,
    required this.child,
    this.alinear = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: ancho, child: Align(alignment: alinear, child: child));
}
