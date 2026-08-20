import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:sozu_agente_app/features/agente/inventario/components/pulsing_pin.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Un lugar del desarrollo en el mapa: el terreno o el showroom de ventas.
///
/// El mapa va SIN interacción a propósito: dentro de una ficha que se recorre
/// con el dedo, un mapa que hace zoom se queda con el gesto y el agente no puede
/// bajar. Es una vista previa y el toque lleva a la pantalla de ruta.
class UbicacionLugar extends StatelessWidget {
  /// "El desarrollo" o "Showroom de ventas".
  final String titulo;

  final String? direccion;
  final String? horarios;
  final double? latitud;
  final double? longitud;

  /// Abre la pantalla de ruta. Null cuando no hay coordenadas que seguir.
  final VoidCallback? onComoLlegar;

  const UbicacionLugar({
    super.key,
    required this.titulo,
    this.direccion,
    this.horarios,
    this.latitud,
    this.longitud,
    this.onComoLlegar,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final lat = latitud;
    final lng = longitud;
    final punto = lat != null && lng != null ? LatLng(lat, lng) : null;

    return SCard.outlined(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EncabezadoCelda(titulo: titulo),
          AspectRatio(
            aspectRatio: _aspectoMapa,
            child: punto == null
                ? ColoredBox(
                    color: tone.muted,
                    child: Icon(
                      Icons.map_outlined,
                      size: _iconoSinMapa,
                      color: tone.fgSubtle,
                    ),
                  )
                : SPressable(
                    onTap: onComoLlegar,
                    semanticLabel: 'Cómo llegar a $titulo',
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: punto,
                        initialZoom: _zoom,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.sozu.sozuAgenteApp',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: punto,
                              width: PulsingPin.lado,
                              height: PulsingPin.lado,
                              child: const PulsingPin(),
                            ),
                          ],
                        ),
                        const SimpleAttributionWidget(
                          source: Text('© OpenStreetMap'),
                        ),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(t.space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if ((direccion ?? '').isNotEmpty)
                  Text(
                    direccion!,
                    style: t.text.bodySmall.copyWith(color: tone.fg),
                  ),
                if ((horarios ?? '').isNotEmpty) ...[
                  SizedBox(height: t.space.xxs),
                  Text(
                    horarios!,
                    style: t.text.caption.copyWith(color: tone.fgMuted),
                  ),
                ],
                if (onComoLlegar != null) ...[
                  SizedBox(height: t.space.xs),
                  SButton.secondary(
                    label: 'Cómo llegar',
                    icon: Icons.directions_outlined,
                    size: SButtonSize.sm,
                    isNavigation: true,
                    onPressed: onComoLlegar,
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

/// Encabezado de una celda de la sección Ubicación ("EL DESARROLLO",
/// "SHOWROOM DE VENTAS", "PUNTOS DE INTERÉS").
class _EncabezadoCelda extends StatelessWidget {
  final String titulo;

  const _EncabezadoCelda({required this.titulo});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      color: t.color.surfaceAlt,
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm,
        vertical: t.space.xs,
      ),
      child: Text(
        titulo.toUpperCase(),
        style: t.text.overline.copyWith(color: t.color.fgMuted),
      ),
    );
  }
}

/// Puntos de interés como celda de la sección Ubicación, al lado del mapa del
/// desarrollo. Se usa cuando el desarrollo NO tiene showroom: ese hueco es el
/// del showroom, y dejarlo vacío parte la sección en dos.
class PuntosInteresCard extends StatelessWidget {
  final List<PuntoInteres> puntos;

  const PuntosInteresCard({super.key, required this.puntos});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return SCard.outlined(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _EncabezadoCelda(titulo: 'Puntos de interés'),
          Padding(
            padding: EdgeInsets.fromLTRB(t.space.sm, t.space.sm, t.space.sm, 0),
            child: PuntosInteresLista(puntos: puntos),
          ),
        ],
      ),
    );
  }
}

/// Lista de puntos de interés cercanos, con su distancia.
class PuntosInteresLista extends StatelessWidget {
  final List<PuntoInteres> puntos;

  const PuntosInteresLista({super.key, required this.puntos});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in puntos)
          Padding(
            padding: EdgeInsets.only(bottom: t.space.xs),
            child: Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: _iconoPunto,
                  color: tone.primaryHover,
                ),
                SizedBox(width: t.space.xs),
                Expanded(
                  child: Text(
                    p.nombre,
                    style: t.text.bodySmall.copyWith(color: tone.fg),
                  ),
                ),
                if (p.distanciaTexto != null)
                  Text(
                    p.distanciaTexto!,
                    style: t.text.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tone.fgMuted,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

const double _aspectoMapa = 16 / 9;
const double _zoom = 15;
const double _iconoSinMapa = 32;
const double _iconoPunto = 16;
