import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/network_image.dart';

/// Avance de obra del desarrollo: porcentaje global, etapa vigente, el roadmap
/// de etapas y el video más reciente.
///
/// El porcentaje NO se calcula por fechas: sale de la etapa registrada en el
/// desarrollo (`estatus_proyecto.porcentaje_avance`), que es la misma fuente que
/// usan la oferta digital y el panel. Aquí solo se pinta lo que manda el
/// servidor.
class AvanceObraCard extends StatelessWidget {
  final AvanceObra avance;

  /// Fecha de entrega estimada que se le puede mencionar al cliente.
  final String? fechaEntrega;

  /// Abre el video fuera del app. Null = el desarrollo no tiene video.
  final VoidCallback? onVerVideo;

  const AvanceObraCard({
    super.key,
    required this.avance,
    this.fechaEntrega,
    this.onVerVideo,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (avance.porcentaje > 0) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Avance global del desarrollo',
                  style: t.text.bodySmall.copyWith(color: tone.fgMuted),
                ),
              ),
              Text(
                '${avance.porcentaje}%',
                style: t.text.h2.copyWith(color: tone.primaryHover),
              ),
            ],
          ),
          SizedBox(height: t.space.xs),
          SProgressBar(
            percent: avance.porcentaje.toDouble(),
            semanticsLabel: 'Avance de obra',
          ),
          SizedBox(height: t.space.xs),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Etapa actual: ',
                  style: t.text.caption.copyWith(color: tone.fgMuted),
                ),
                TextSpan(
                  text: avance.etapaActual,
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone.fg,
                  ),
                ),
                if (avance.actualizado != null)
                  TextSpan(
                    text:
                        ' · Actualizado: ${formatDateEsMX(avance.actualizado)}',
                    style: t.text.caption.copyWith(color: tone.fgSubtle),
                  ),
              ],
            ),
          ),
        ],
        if (avance.video != null) ...[
          SizedBox(height: t.space.md),
          _VideoAvance(video: avance.video!, onVer: onVerVideo),
        ],
        if (avance.etapas.isNotEmpty) ...[
          SizedBox(height: t.space.md),
          Text(
            'ETAPAS DE OBRA',
            style: t.text.overline.copyWith(color: tone.fgMuted),
          ),
          SizedBox(height: t.space.xs),
          for (var i = 0; i < avance.etapas.length; i++)
            _FilaEtapa(numero: i + 1, etapa: avance.etapas[i]),
        ],
        if (fechaEntrega != null) ...[
          SizedBox(height: t.space.md),
          Divider(height: 1, color: tone.border),
          SizedBox(height: t.space.xs),
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: _iconoFecha,
                color: tone.fgMuted,
              ),
              SizedBox(width: t.space.xxs),
              Expanded(
                child: Text(
                  'Posible fecha de entrega · ${formatDateEsMX(fechaEntrega)}',
                  style: t.text.caption.copyWith(color: tone.fgMuted),
                ),
              ),
            ],
          ),
          Text(
            'Fecha estimada y sujeta a cambios según el avance de obra. No '
            'constituye una fecha de entrega contractual.',
            style: t.text.caption.copyWith(color: tone.fgSubtle),
          ),
        ],
      ],
    );
  }
}

/// Fila del roadmap: número, nombre y porcentaje acumulado de la etapa.
class _FilaEtapa extends StatelessWidget {
  final int numero;
  final EtapaObra etapa;

  const _FilaEtapa({required this.numero, required this.etapa});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    // Tres estados y tres colores: hecha (marca), en curso (ámbar) y pendiente
    // (apagada). Sin el ámbar, la etapa vigente se pierde entre las pendientes.
    final color = etapa.completada
        ? tone.primaryHover
        : etapa.esActual
        ? tone.warningFg
        : tone.fgSubtle;

    return Padding(
      padding: EdgeInsets.only(bottom: t.space.xs),
      child: Row(
        children: [
          Container(
            width: _lado,
            height: _lado,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: etapa.esActual ? tone.warningSoft : null,
              border: Border.all(color: color),
            ),
            child: Text(
              '$numero',
              style: t.text.overline.copyWith(color: color),
            ),
          ),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(
              etapa.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.text.bodySmall.copyWith(
                fontWeight: etapa.esActual ? FontWeight.w700 : FontWeight.w400,
                color: etapa.completada || etapa.esActual
                    ? tone.fg
                    : tone.fgMuted,
              ),
            ),
          ),
          Text(
            '${etapa.porcentaje}%',
            style: t.text.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Miniatura del video con botón de reproducir.
///
/// No se incrusta un reproductor: el app no trae uno y cargar un `WebView` por
/// un video de obra es peso muerto en las tres plataformas. Al tocar, se abre en
/// la app de video del dispositivo.
class _VideoAvance extends StatelessWidget {
  final VideoAvance video;
  final VoidCallback? onVer;

  const _VideoAvance({required this.video, this.onVer});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return SCard.outlined(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SPressable(
            onTap: onVer,
            semanticLabel: 'Reproducir ${video.nombre ?? 'video de avance'}',
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _aspectoVideo,
                  child: SozuNetworkImage(
                    url: video.miniaturaUrl,
                    placeholderIcon: Icons.play_circle_outline,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tone.overlay,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(t.space.xs),
                    child: const Icon(
                      Icons.play_arrow,
                      size: _iconoPlay,
                      // Sobre el velo oscuro del play: blanco fijo, no un rol.
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (video.nombre != null)
            Padding(
              padding: EdgeInsets.all(t.space.sm),
              child: Text(
                video.nombre!,
                style: t.text.bodySmall.copyWith(color: tone.fg),
              ),
            ),
        ],
      ),
    );
  }
}

const double _aspectoVideo = 16 / 9;
const double _iconoPlay = 32;
const double _iconoFecha = 14;
const double _lado = 22;
