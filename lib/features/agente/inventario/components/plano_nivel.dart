import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/features/agente/inventario/services/resaltado_plano.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/network_image.dart';

/// Plano del nivel con la unidad resaltada encima.
///
/// El polígono se dibuja aquí, no viene dibujado: el servidor manda los vértices
/// en PORCENTAJE de la imagen y el trazo se escala con ella. Por eso hay que
/// conocer la proporción real del plano antes de pintar: sin ella, la imagen se
/// ajusta al hueco y el polígono queda corrido.
class PlanoNivel extends StatefulWidget {
  final String url;
  final List<RegionPlano> regiones;

  /// Número de departamento dentro del nivel.
  final String numeroDepa;

  /// Número completo de la propiedad, para conciliar con el del plano.
  final String? numeroUnidad;

  const PlanoNivel({
    super.key,
    required this.url,
    required this.regiones,
    required this.numeroDepa,
    this.numeroUnidad,
  });

  @override
  State<PlanoNivel> createState() => _PlanoNivelState();
}

class _PlanoNivelState extends State<PlanoNivel> {
  late ImageProvider _proveedor;
  ImageStreamListener? _oyente;
  ImageStream? _flujo;
  double? _aspecto;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    _proveedor = cachedImageProvider(widget.url);
    _medir();
  }

  @override
  void didUpdateWidget(PlanoNivel viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.url != widget.url) {
      _soltar();
      _proveedor = cachedImageProvider(widget.url);
      _aspecto = null;
      _fallo = false;
      _medir();
    }
  }

  /// Resuelve el stream de la imagen solo para leer su ancho y alto reales.
  void _medir() {
    final flujo = _proveedor.resolve(ImageConfiguration.empty);
    final oyente = ImageStreamListener(
      // ImageInfo vive en painting.dart (lo reexporta material), NO en dart:ui.
      (ImageInfo info, bool _) {
        if (!mounted) return;
        setState(
          () => _aspecto = info.image.width / info.image.height,
        );
      },
      onError: (Object error, StackTrace? stack) {
        if (!mounted) return;
        setState(() => _fallo = true);
      },
    );
    _flujo = flujo..addListener(oyente);
    _oyente = oyente;
  }

  void _soltar() {
    final oyente = _oyente;
    if (oyente != null) _flujo?.removeListener(oyente);
    _oyente = null;
    _flujo = null;
  }

  @override
  void dispose() {
    _soltar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    if (_fallo) {
      return SEmptyState.card(
        icon: Icons.broken_image_outlined,
        title: 'No pudimos cargar el plano',
        message: 'Revisa tu conexión e intenta abrirlo de nuevo.',
      );
    }
    final aspecto = _aspecto;
    if (aspecto == null) {
      return const AspectRatio(
        aspectRatio: 4 / 3,
        child: SSkeleton(height: double.infinity),
      );
    }

    final region = regionDeUnidad(
      widget.regiones,
      numeroDepa: widget.numeroDepa,
      numeroUnidad: widget.numeroUnidad,
    );

    return ClipRRect(
      borderRadius: t.radius.mdBorder,
      child: InteractiveViewer(
        maxScale: _zoomMax,
        child: AspectRatio(
          aspectRatio: aspecto,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // `fill` y no `contain`: la caja ya tiene la proporción exacta del
              // plano, así que el porcentaje del polígono cae donde debe.
              Image(image: _proveedor, fit: BoxFit.fill),
              if (region != null)
                CustomPaint(
                  painter: _ResaltadoPainter(
                    region: region,
                    relleno: t.color.primary,
                    trazo: t.color.primaryPressed,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dibuja el polígono de la unidad, con sus curvas cuadráticas cuando el plano
/// las trae.
class _ResaltadoPainter extends CustomPainter {
  final RegionPlano region;

  /// Un `CustomPainter` no tiene `BuildContext`: los colores entran por
  /// constructor como cualquier otro dato.
  final Color relleno;
  final Color trazo;

  const _ResaltadoPainter({
    required this.region,
    required this.relleno,
    required this.trazo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final puntos = <Offset>[];
    for (final p in region.poligono) {
      if (p.length < 2) continue;
      puntos.add(Offset(p[0] / 100 * size.width, p[1] / 100 * size.height));
    }
    if (puntos.length < 3) return;

    // El polígono se expande un 4% desde su centro para que el trazo no tape el
    // muro del departamento (mismo factor que el panel).
    final centro = puntos.reduce((a, b) => a + b) / puntos.length.toDouble();
    Offset expandir(Offset o) => centro + (o - centro) * _expansion;

    final expandidos = puntos.map(expandir).toList(growable: false);
    final path = Path()..moveTo(expandidos.first.dx, expandidos.first.dy);
    for (var i = 0; i < expandidos.length; i++) {
      final siguiente = expandidos[(i + 1) % expandidos.length];
      final control = region.curvas[i];
      if (control != null && control.length >= 2) {
        final c = expandir(
          Offset(
            control[0] / 100 * size.width,
            control[1] / 100 * size.height,
          ),
        );
        path.quadraticBezierTo(c.dx, c.dy, siguiente.dx, siguiente.dy);
      } else {
        path.lineTo(siguiente.dx, siguiente.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = relleno.withValues(alpha: _alphaRelleno),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _grosorTrazo
        ..color = trazo,
    );
  }

  @override
  bool shouldRepaint(covariant _ResaltadoPainter viejo) =>
      viejo.region != region ||
      viejo.relleno != relleno ||
      viejo.trazo != trazo;
}

const double _expansion = 1.04;
const double _alphaRelleno = 0.32;
const double _grosorTrazo = 2.5;
const double _zoomMax = 4;
