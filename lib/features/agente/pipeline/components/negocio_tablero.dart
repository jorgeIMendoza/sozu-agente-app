import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/etapa_badge.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/negocio_acciones.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/pipeline_modal.dart';
import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Ancho de una columna del tablero.
const double _anchoColumna = 264;

/// Tablero por etapa, con arrastre.
///
/// **Dos caminos para mover, a propósito.** En teléfono el arrastre corto pelea
/// con el scroll de la columna: la tarjeta se arrastra con un toque SOSTENIDO
/// (`LongPressDraggable`) y en escritorio con arrastre normal (`Draggable`),
/// donde hay puntero y no hay conflicto. Además cada tarjeta lleva un botón que
/// abre un selector de etapa: es el camino que funciona con lector de pantalla,
/// con la columna destino fuera de vista y cuando la mano no acierta el objetivo.
///
/// Las columnas de etapa automática no aceptan nada: esas las mueve un hecho del
/// sistema y se marcan con candado.
class NegocioTablero extends StatefulWidget {
  final List<EtapaPipeline> etapas;

  /// Negocios ya filtrados por el buscador. El tablero NO aplica el filtro de
  /// etapa: pinta todas las columnas.
  final List<Negocio> negocios;

  final bool modoPresentacion;
  final void Function(Negocio, EtapaPipeline) onMover;
  final void Function(Negocio) onDetalle;

  /// Aviso al agente cuando la acción no se puede intentar.
  final void Function(String mensaje) onAviso;

  const NegocioTablero({
    super.key,
    required this.etapas,
    required this.negocios,
    required this.modoPresentacion,
    required this.onMover,
    required this.onDetalle,
    required this.onAviso,
  });

  @override
  State<NegocioTablero> createState() => _NegocioTableroState();
}

class _NegocioTableroState extends State<NegocioTablero> {
  /// Negocio en vuelo; atenúa las columnas que no lo pueden recibir.
  Negocio? _arrastrando;

  /// Columna bajo el dedo o el puntero.
  String? _etapaActiva;

  @override
  Widget build(BuildContext context) {
    final t = context.s;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: t.space.md),
      itemCount: widget.etapas.length,
      separatorBuilder: (_, __) => SizedBox(width: t.space.xs),
      itemBuilder: (context, i) => _columna(context, widget.etapas[i]),
    );
  }

  Widget _columna(BuildContext context, EtapaPipeline etapa) {
    final t = context.s;
    final tone = t.color;
    final items = widget.negocios
        .where((n) => n.etapa == etapa.clave)
        .toList(growable: false);
    final monto = items.fold<double>(0, (s, n) => s + (n.precio ?? 0));
    final activa = _etapaActiva == etapa.clave && !etapa.automatica;
    final apagada = _arrastrando != null && etapa.automatica;

    return DragTarget<Negocio>(
      onWillAcceptWithDetails: (detalles) {
        final negocio = detalles.data;
        final aceptable =
            !etapa.automatica &&
            negocio.sePuedeMover &&
            negocio.etapa != etapa.clave;
        if (aceptable) setState(() => _etapaActiva = etapa.clave);
        return aceptable;
      },
      onLeave: (_) {
        if (_etapaActiva == etapa.clave) setState(() => _etapaActiva = null);
      },
      onAcceptWithDetails: (detalles) {
        setState(() {
          _etapaActiva = null;
          _arrastrando = null;
        });
        widget.onMover(detalles.data, etapa);
      },
      builder: (context, _, __) => Opacity(
        opacity: apagada ? _opacidadApagada : 1,
        child: SizedBox(
          width: _anchoColumna,
          child: SCard.outlined(
            padding: EdgeInsets.zero,
            clip: true,
            borderColor: activa ? tone.primary : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: activa ? tone.primarySoft : tone.surfaceAlt,
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space.xs,
                    vertical: t.space.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: EtapaBadge(etapa: etapa)),
                      Text(
                        '${items.length}',
                        style: t.text.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tone.fgMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space.xs,
                    vertical: t.space.xxs,
                  ),
                  child: Text(
                    mascara(formatMXN(monto), activo: widget.modoPresentacion),
                    style: t.text.overline.copyWith(color: tone.fgSubtle),
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(t.space.sm),
                            child: Text(
                              etapa.automatica
                                  ? 'Sin negocios'
                                  : 'Arrastra aquí',
                              textAlign: TextAlign.center,
                              style: t.text.caption.copyWith(
                                color: tone.fgSubtle,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.all(t.space.xs),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: t.space.xs),
                          itemBuilder: (context, i) => _tarjeta(items[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(Negocio negocio) {
    final tarjeta = _TarjetaTablero(
      negocio: negocio,
      modoPresentacion: widget.modoPresentacion,
      arrastrando: _arrastrando?.idOferta == negocio.idOferta,
      onTap: () => widget.onDetalle(negocio),
      onMover: () => _pedirEtapa(negocio),
    );

    if (!negocio.sePuedeMover) return tarjeta;

    final fantasma = SizedBox(
      width: _anchoColumna - _margenFantasma,
      child: _TarjetaTablero(
        negocio: negocio,
        modoPresentacion: widget.modoPresentacion,
        arrastrando: false,
        elevada: true,
      ),
    );

    void iniciar() => setState(() => _arrastrando = negocio);
    void terminar() => setState(() {
      _arrastrando = null;
      _etapaActiva = null;
    });

    if (context.bp.isMobile) {
      return LongPressDraggable<Negocio>(
        data: negocio,
        feedback: fantasma,
        childWhenDragging: Opacity(opacity: _opacidadApagada, child: tarjeta),
        onDragStarted: iniciar,
        onDraggableCanceled: (_, __) => terminar(),
        onDragEnd: (_) => terminar(),
        child: tarjeta,
      );
    }

    return Draggable<Negocio>(
      data: negocio,
      feedback: fantasma,
      childWhenDragging: Opacity(opacity: _opacidadApagada, child: tarjeta),
      onDragStarted: iniciar,
      onDraggableCanceled: (_, __) => terminar(),
      onDragEnd: (_) => terminar(),
      child: tarjeta,
    );
  }

  /// Selector de etapa: el camino sin arrastre. Solo ofrece etapas manuales.
  Future<void> _pedirEtapa(Negocio negocio) async {
    if (!negocio.sePuedeMover) {
      widget.onAviso(mensajeDeError(AccionNoDisponible('negocio_sin_pipeline')));
      return;
    }
    final manuales = widget.etapas
        .where((e) => !e.automatica && e.clave != negocio.etapa)
        .toList(growable: false);
    if (manuales.isEmpty) {
      widget.onAviso(mensajeDeError(AccionNoDisponible('etapa_automatica')));
      return;
    }

    final destino = await mostrarHojaPipeline<EtapaPipeline>(
      context,
      _HojaMoverEtapa(negocio: negocio, etapas: manuales),
    );
    if (destino != null) widget.onMover(negocio, destino);
  }
}

/// Opacidad de lo que no puede recibir el negocio en vuelo.
const double _opacidadApagada = 0.45;

/// Lo que se le quita al fantasma para que no tape la columna entera.
const double _margenFantasma = 24;

class _TarjetaTablero extends StatelessWidget {
  final Negocio negocio;
  final bool modoPresentacion;
  final bool arrastrando;
  final VoidCallback? onTap;
  final VoidCallback? onMover;

  /// El fantasma que sigue al dedo: lleva sombra y no responde al toque.
  final bool elevada;

  const _TarjetaTablero({
    required this.negocio,
    required this.modoPresentacion,
    required this.arrastrando,
    this.onTap,
    this.onMover,
    this.elevada = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    final contenido = SCard(
      variant: elevada ? SCardVariant.elevated : SCardVariant.outlined,
      padding: EdgeInsets.all(t.space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  negocio.proyectoNombre.isEmpty
                      ? 'Sin desarrollo'
                      : negocio.proyectoNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone.fg,
                  ),
                ),
              ),
              if (onMover != null)
                IconoAccion(
                  icono: negocio.sePuedeMover
                      ? Icons.swap_horiz
                      : Icons.lock_outline,
                  tooltip: negocio.sePuedeMover
                      ? 'Mover a otra etapa'
                      : 'Este negocio todavía no existe en el pipeline: no se '
                            'puede mover de etapa',
                  onTap: onMover,
                ),
            ],
          ),
          Text(
            negocio.unidad.isEmpty ? '-' : negocio.unidad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.overline.copyWith(color: tone.fgSubtle),
          ),
          SizedBox(height: t.space.xxs),
          Text(
            mascara(negocio.lead.nombre, activo: modoPresentacion),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.caption.copyWith(color: tone.fg),
          ),
          Text(
            mascara(negocio.lead.email ?? 'Sin correo', activo: modoPresentacion),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.overline.copyWith(color: tone.fgSubtle),
          ),
          SizedBox(height: t.space.xxs),
          Row(
            children: [
              Expanded(
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
              if (negocio.ofertasCount > 1)
                SBadge(
                  label: '${negocio.ofertasCount} vers.',
                  size: SBadgeSize.sm,
                ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return contenido;

    return Opacity(
      opacity: arrastrando ? _opacidadApagada : 1,
      child: SPressable(
        onTap: onTap,
        borderRadius: t.radius.lgBorder,
        child: contenido,
      ),
    );
  }
}

/// Selector de etapa destino. Es la alternativa al arrastre, no un atajo: mueve
/// exactamente lo mismo y por el mismo camino.
class _HojaMoverEtapa extends StatefulWidget {
  final Negocio negocio;
  final List<EtapaPipeline> etapas;

  const _HojaMoverEtapa({required this.negocio, required this.etapas});

  @override
  State<_HojaMoverEtapa> createState() => _HojaMoverEtapaState();
}

class _HojaMoverEtapaState extends State<_HojaMoverEtapa> {
  EtapaPipeline? _destino;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return HojaPipeline(
      icono: Icons.swap_horiz,
      titulo: 'Mover de etapa',
      subtitulo: '${widget.negocio.folio} · ${widget.negocio.unidad}',
      cuerpo: [
        Text(
          'Solo se listan las etapas que mueves tú. Las automáticas las dispara '
          'un hecho real del negocio.',
          style: t.text.bodySmall.copyWith(color: t.color.fgMuted),
        ),
        SizedBox(height: t.space.sm),
        SSelectField<EtapaPipeline>(
          label: 'Etapa destino',
          hint: 'Elige la etapa',
          value: _destino,
          opciones: [
            for (final e in widget.etapas) (value: e, label: e.nombre),
          ],
          onChanged: (v) => setState(() => _destino = v),
        ),
      ],
      acciones: [
        SButton.secondary(
          label: 'Cancelar',
          fullWidth: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SButton(
          label: 'Mover',
          fullWidth: false,
          onPressed: _destino == null
              ? null
              : () => Navigator.of(context).pop(_destino),
        ),
      ],
    );
  }
}
