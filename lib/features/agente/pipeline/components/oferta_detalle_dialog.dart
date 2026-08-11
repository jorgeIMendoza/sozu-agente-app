import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/compartir_negocio.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/etapa_badge.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/pipeline_modal.dart';
import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/features/agente/pipeline/providers/modo_presentacion_provider.dart';
import 'package:sozu_agente_app/features/agente/pipeline/providers/pipeline_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Lo que la hoja le devuelve a la pantalla al cerrarse.
class ResultadoDetalle {
  /// Mensaje que la pantalla debe mostrar (guardado del plan, link emitido).
  final String? aviso;

  /// La pantalla debe abrir la captura de la razón de no avance.
  final bool abrirRazon;

  const ResultadoDetalle({this.aviso, this.abrirRazon = false});
}

/// Detalle del negocio: la unidad, sus asociados, los esquemas de pago
/// seleccionables y el link digital con su token.
class OfertaDetalleHoja extends ConsumerStatefulWidget {
  final Negocio negocio;
  final EtapaPipeline etapa;

  /// Sin permiso de actualizar, los esquemas quedan en solo lectura.
  final bool puedeActualizar;

  /// El catálogo de razones está habilitado: si no, no se ofrece capturarla.
  final bool razonesDisponibles;

  const OfertaDetalleHoja({
    super.key,
    required this.negocio,
    required this.etapa,
    required this.puedeActualizar,
    required this.razonesDisponibles,
  });

  @override
  ConsumerState<OfertaDetalleHoja> createState() => _OfertaDetalleHojaState();
}

class _OfertaDetalleHojaState extends ConsumerState<OfertaDetalleHoja> {
  int? _esquemaId;
  bool _guardando = false;
  bool _generandoLink = false;
  String? _error;

  Negocio get _negocio => widget.negocio;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final detalle = ref.watch(detalleOfertaProvider(_negocio.idOferta));

    return HojaPipeline(
      icono: Icons.description_outlined,
      titulo: 'Detalle del negocio',
      subtitulo: [
        _negocio.unidad.isEmpty ? '-' : _negocio.unidad,
        if (_negocio.proyectoNombre.isNotEmpty) _negocio.proyectoNombre,
      ].join(' · '),
      cuerpo: [
        _ficha(context),
        SizedBox(height: t.space.sm),
        ...detalle.when(
          loading: () => const [
            SSkeleton(height: 96),
            SizedBox(height: 12),
            SSkeleton(height: 140),
          ],
          error: (e, _) => [
            SErrorState(
              title: tituloDeError(e),
              message: mensajeDeError(e),
              onRetry: () =>
                  ref.invalidate(detalleOfertaProvider(_negocio.idOferta)),
            ),
          ],
          data: (d) => _contenido(context, d),
        ),
        if (_error != null) ...[
          SizedBox(height: t.space.xs),
          Text(
            _error!,
            style: t.text.bodySmall.copyWith(color: t.color.danger),
          ),
        ],
      ],
      nota: detalle.valueOrNull?.yaTieneEsquema == true
          ? 'El plan ya está elegido y no se puede cambiar desde el portal.'
          : null,
      acciones: _acciones(context, detalle.valueOrNull),
    );
  }

  /// Identidad del negocio: folio, etapa, prospecto, inmobiliaria, cuenta y fecha.
  Widget _ficha(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final oculto = ref.watch(modoPresentacionProvider).activo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _negocio.folio,
                style: t.text.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tone.primary,
                ),
              ),
            ),
            EtapaBadge(etapa: widget.etapa, size: SBadgeSize.md),
          ],
        ),
        SizedBox(height: t.space.xs),
        _Dato(
          icono: Icons.person_outline,
          texto: mascara(_negocio.lead.nombre, activo: oculto),
        ),
        if (_negocio.lead.email != null)
          _Dato(
            icono: Icons.mail_outline,
            texto: mascara(_negocio.lead.email, activo: oculto),
          ),
        if (_negocio.inmobiliariaNombre.isNotEmpty)
          _Dato(
            icono: Icons.business_outlined,
            texto: _negocio.inmobiliariaNombre,
          ),
        if (_negocio.cuentaFolio != null)
          _Dato(
            icono: Icons.receipt_long_outlined,
            texto: _negocio.cuentaFolio!,
          ),
        _Dato(
          icono: Icons.event_outlined,
          texto: formatDateEsMX(_negocio.fechaGeneracion),
        ),
        if (_negocio.ofertasCount > 1)
          _Dato(
            icono: Icons.layers_outlined,
            texto:
                '${_negocio.ofertasCount} versiones de oferta sobre esta unidad',
          ),
        if (widget.etapa.esPerdido) ...[
          SizedBox(height: t.space.xs),
          _bloqueRazon(context),
        ],
      ],
    );
  }

  Widget _bloqueRazon(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final razon = _negocio.razonNoAvance;
    final sePuedeCapturar = widget.puedeActualizar && widget.razonesDisponibles;

    if (razon != null) {
      return SCard.outlined(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.sm,
          vertical: t.space.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No avanzó: ${razon.motivoNombre}',
                    style: t.text.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tone.fg,
                    ),
                  ),
                  if (razon.comentario != null)
                    Text(
                      razon.comentario!,
                      style: t.text.caption.copyWith(color: tone.fgMuted),
                    ),
                ],
              ),
            ),
            if (sePuedeCapturar)
              SButton.link(
                label: 'Editar',
                fullWidth: false,
                onPressed: () => Navigator.of(context).pop(
                  const ResultadoDetalle(abrirRazon: true),
                ),
              ),
          ],
        ),
      );
    }

    return SCard.outlined(
      borderColor: tone.warningSoftStrong,
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm,
        vertical: t.space.xs,
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline, size: _icono, color: tone.warningFg),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(
              sePuedeCapturar
                  ? '¿Por qué no avanzó este negocio? Cuéntanos la razón.'
                  : 'Este negocio se cerró sin razón registrada.',
              style: t.text.caption.copyWith(color: tone.warningFg),
            ),
          ),
          if (sePuedeCapturar)
            SButton.secondary(
              label: 'Registrar',
              fullWidth: false,
              size: SButtonSize.sm,
              onPressed: () => Navigator.of(context).pop(
                const ResultadoDetalle(abrirRazon: true),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _contenido(BuildContext context, OfertaDetalle d) {
    final t = context.s;
    final tone = t.color;
    final oculto = ref.watch(modoPresentacionProvider).activo;
    final base = d.propiedad?.precioLista ?? _negocio.precio ?? 0;
    final adicionales = d.totalAdicionales;

    return [
      SCard.outlined(
        padding: EdgeInsets.all(t.space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Renglon(
              etiqueta: 'Precio ${d.esProducto ? 'del producto' : 'de la unidad'}',
              valor: mascara(formatMXN(base), activo: oculto),
            ),
            if (adicionales > 0) ...[
              _Renglon(
                etiqueta: 'Productos adicionales',
                valor: '+ ${mascara(formatMXN(adicionales), activo: oculto)}',
              ),
              Divider(color: tone.borderSoft, height: t.space.md),
              _Renglon(
                etiqueta: 'Total',
                valor: mascara(formatMXN(base + adicionales), activo: oculto),
                fuerte: true,
              ),
            ],
          ],
        ),
      ),
      if (d.asociados.isNotEmpty) ...[
        SizedBox(height: t.space.sm),
        SSectionLabel(
          text: 'Bodegas y estacionamientos',
          icon: Icons.sell_outlined,
        ),
        Wrap(
          spacing: t.space.xxs,
          runSpacing: t.space.xxs,
          children: [
            for (final a in d.asociados)
              SBadge(
                label: a.esIncluido
                    ? '${a.nombre} (incluido)'
                    : '${a.nombre} (${mascara(formatMXN(a.precio), activo: oculto)})',
                tone: a.esIncluido ? SBadgeTone.neutral : SBadgeTone.pending,
                icon: a.tipo == 'bodega'
                    ? Icons.inventory_2_outlined
                    : Icons.local_parking_outlined,
              ),
          ],
        ),
        if (d.adicionales.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: t.space.xxs),
            child: Text(
              'Los no incluidos generan ofertas adicionales.',
              style: t.text.caption.copyWith(color: tone.fgSubtle),
            ),
          ),
      ],
      SizedBox(height: t.space.sm),
      SSectionLabel(
        text: 'Esquemas de pago (${d.esquemas.length})',
        icon: Icons.payments_outlined,
      ),
      if (d.esquemas.isEmpty)
        Text(
          'No hay esquemas disponibles para esta oferta.',
          style: t.text.bodySmall.copyWith(color: tone.fgMuted),
        )
      else
        for (final e in d.esquemas) ...[
          _OpcionEsquema(
            esquema: e,
            base: base,
            oculto: oculto,
            seleccionado: d.yaTieneEsquema
                ? e.id == d.idEsquemaSeleccionado
                : e.id == _esquemaId,
            bloqueado: d.yaTieneEsquema || !widget.puedeActualizar,
            onTap: () =>
                setState(() => _esquemaId = _esquemaId == e.id ? null : e.id),
          ),
          SizedBox(height: t.space.xxs),
        ],
      SizedBox(height: t.space.sm),
      SSectionLabel(text: 'Link del cliente', icon: Icons.link_outlined),
      SCard.outlined(
        padding: EdgeInsets.all(t.space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d.link.vigente
                  ? d.link.url!
                  : 'Esta oferta no tiene link de cliente: la vista previa sirve '
                        'para mostrarla, no para apartar.',
              style: t.text.caption.copyWith(
                color: d.link.vigente ? tone.fg : tone.fgMuted,
              ),
            ),
            SizedBox(height: t.space.xs),
            Wrap(
              spacing: t.space.xs,
              runSpacing: t.space.xxs,
              children: [
                SButton.secondary(
                  label: 'Copiar',
                  icon: Icons.copy_outlined,
                  size: SButtonSize.sm,
                  fullWidth: false,
                  onPressed: () =>
                      copiarLink(context, d.link.urlCompartible),
                ),
                SButton.secondary(
                  label: 'Abrir',
                  icon: Icons.open_in_new,
                  size: SButtonSize.sm,
                  fullWidth: false,
                  onPressed: () =>
                      abrirLinkCliente(context, d.link.urlCompartible),
                ),
                if (!d.link.vigente && widget.puedeActualizar)
                  SButton.secondary(
                    label: 'Generar link',
                    icon: Icons.add_link,
                    size: SButtonSize.sm,
                    fullWidth: false,
                    loading: _generandoLink,
                    onPressed: _generarLink,
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _acciones(BuildContext context, OfertaDetalle? d) {
    final puedeGuardar =
        d != null &&
        !d.yaTieneEsquema &&
        widget.puedeActualizar &&
        _esquemaId != null;

    return [
      SButton.secondary(
        label: 'Cerrar',
        fullWidth: false,
        onPressed: () => Navigator.of(context).pop(),
      ),
      SButton.secondary(
        label: 'Compartir',
        icon: Icons.ios_share_outlined,
        fullWidth: false,
        onPressed: d == null
            ? null
            : () => compartirLinkCliente(
                context,
                url: d.link.urlCompartible,
                titulo: '${_negocio.folio} · ${_negocio.unidad}',
              ),
      ),
      if (puedeGuardar)
        SButton(
          label: 'Guardar plan',
          fullWidth: false,
          loading: _guardando,
          onPressed: _guardarEsquema,
        ),
    ];
  }

  Future<void> _guardarEsquema() async {
    final id = _esquemaId;
    if (id == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final cambio = await ref.read(pipelineAccionesProvider).elegirEsquema(
        idOferta: _negocio.idOferta,
        idEsquema: id,
      );
      if (mounted) {
        Navigator.of(
          context,
        ).pop(ResultadoDetalle(aviso: mensajeDeEsquema(cambio)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeDeError(e);
      });
    }
  }

  Future<void> _generarLink() async {
    setState(() {
      _generandoLink = true;
      _error = null;
    });
    try {
      await ref.read(pipelineAccionesProvider).generarLink(
        idOferta: _negocio.idOferta,
        email: _negocio.lead.email,
      );
      if (!mounted) return;
      setState(() => _generandoLink = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link del cliente generado.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generandoLink = false;
        _error = mensajeDeError(e);
      });
    }
  }
}

/// Un esquema de pago, con sus importes ya calculados sobre el precio base.
class _OpcionEsquema extends StatelessWidget {
  final EsquemaPago esquema;
  final double base;
  final bool oculto;
  final bool seleccionado;
  final bool bloqueado;
  final VoidCallback onTap;

  const _OpcionEsquema({
    required this.esquema,
    required this.base,
    required this.oculto,
    required this.seleccionado,
    required this.bloqueado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final ajuste = esquema.porcentajeDescuentoAumento;

    final partes = <String>[
      if (esquema.porcentajeEnganche > 0)
        '${_pct(esquema.porcentajeEnganche)} enganche',
      if (esquema.porcentajeMensualidades > 0)
        '${_pct(esquema.porcentajeMensualidades)} mensualidades',
      if (esquema.porcentajeEntrega > 0)
        '${_pct(esquema.porcentajeEntrega)} entrega',
    ];

    final contenido = SCard.outlined(
      padding: EdgeInsets.all(t.space.sm),
      borderColor: seleccionado ? tone.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (seleccionado) ...[
                Icon(Icons.check_circle, size: _icono, color: tone.primary),
                SizedBox(width: t.space.xxs),
              ] else if (bloqueado) ...[
                Icon(Icons.lock_outline, size: _icono, color: tone.fgSubtle),
                SizedBox(width: t.space.xxs),
              ],
              Expanded(
                child: Text(
                  esquema.nombre,
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fg,
                  ),
                ),
              ),
              if (ajuste != 0)
                SBadge(
                  label: '${ajuste > 0 ? '+' : ''}${_pct(ajuste)}',
                  tone: ajuste < 0 ? SBadgeTone.positive : SBadgeTone.negative,
                  size: SBadgeSize.sm,
                ),
            ],
          ),
          if (partes.isNotEmpty)
            Text(
              partes.join(' · '),
              style: t.text.caption.copyWith(color: tone.fgMuted),
            ),
          if (esquema.numeroMensualidades > 1)
            Text(
              '${esquema.numeroMensualidades} meses',
              style: t.text.caption.copyWith(color: tone.fgMuted),
            ),
          SizedBox(height: t.space.xxs),
          Wrap(
            spacing: t.space.sm,
            runSpacing: t.space.xxs,
            children: [
              if (esquema.porcentajeEnganche > 0)
                _Importe(
                  etiqueta: 'Enganche',
                  valor: mascara(
                    formatMXN(esquema.enganche(base)),
                    activo: oculto,
                  ),
                ),
              if (esquema.porcentajeMensualidades > 0)
                _Importe(
                  etiqueta: 'Mensualidad',
                  valor: mascara(
                    formatMXN(esquema.mensualidad(base)),
                    activo: oculto,
                  ),
                ),
              if (esquema.porcentajeEntrega > 0)
                _Importe(
                  etiqueta: 'Entrega',
                  valor: mascara(
                    formatMXN(esquema.entrega(base)),
                    activo: oculto,
                  ),
                ),
              _Importe(
                etiqueta: 'Precio final',
                valor: mascara(
                  formatMXN(esquema.precioFinal(base)),
                  activo: oculto,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (bloqueado) {
      return Opacity(opacity: seleccionado ? 1 : 0.6, child: contenido);
    }
    return SPressable(
      onTap: onTap,
      borderRadius: t.radius.lgBorder,
      child: contenido,
    );
  }
}

/// Porcentaje sin decimales cuando es entero: "10%" en vez de "10.0%".
String _pct(double v) {
  final entero = v.truncateToDouble() == v;
  return entero ? '${v.toInt()}%' : '${v.toStringAsFixed(1)}%';
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Dato({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.xxs),
      child: Row(
        children: [
          Icon(icono, size: _icono, color: tone.fgSubtle),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.text.caption.copyWith(color: tone.fgMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool fuerte;

  const _Renglon({
    required this.etiqueta,
    required this.valor,
    this.fuerte = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: t.text.caption.copyWith(color: tone.fgMuted),
          ),
        ),
        Text(
          valor,
          style: (fuerte ? t.text.bodyLarge : t.text.bodySmall).copyWith(
            fontWeight: FontWeight.w700,
            color: tone.fg,
          ),
        ),
      ],
    );
  }
}

class _Importe extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Importe({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Text(
      '$etiqueta: $valor',
      style: t.text.caption.copyWith(color: t.color.fgMuted),
    );
  }
}

const double _icono = 16;
