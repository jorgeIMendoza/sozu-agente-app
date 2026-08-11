import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/network_image.dart';

/// Carrusel de imágenes con indicadores y contador, del ancho de su padre.
///
/// No abre el visor por su cuenta: quien lo compone decide qué hace el toque
/// (la portada de la ficha abre pantalla completa, la tarjeta de un modelo abre
/// su galería). Así el componente no navega.
class CarruselImagenes extends StatefulWidget {
  final List<String> imagenes;

  /// Relación ancho/alto del área visible.
  final double aspecto;

  /// Se llama con el índice visible al tocar la imagen.
  final ValueChanged<int>? onTocar;

  /// Flechas laterales. En una tarjeta chica estorban; en la portada ayudan.
  final bool conFlechas;

  final BoxFit ajuste;

  const CarruselImagenes({
    super.key,
    required this.imagenes,
    this.aspecto = 4 / 3,
    this.onTocar,
    this.conFlechas = false,
    this.ajuste = BoxFit.cover,
  });

  @override
  State<CarruselImagenes> createState() => _CarruselImagenesState();
}

class _CarruselImagenesState extends State<CarruselImagenes> {
  final _controller = PageController();
  int _indice = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ir(int i) {
    final total = widget.imagenes.length;
    if (total == 0) return;
    // Circular, como el carrusel de la web: de la última se pasa a la primera.
    final destino = (i % total + total) % total;
    _controller.animateToPage(
      destino,
      duration: context.s.motion.normal,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final total = widget.imagenes.length;

    if (total == 0) {
      return AspectRatio(
        aspectRatio: widget.aspecto,
        child: ColoredBox(
          color: tone.surfaceAlt,
          child: Icon(
            Icons.apartment_outlined,
            size: _iconoVacio,
            color: tone.fgSubtle,
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: widget.aspecto,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (i) => setState(() => _indice = i),
            itemBuilder: (context, i) => GestureDetector(
              onTap: widget.onTocar == null
                  ? null
                  : () => widget.onTocar!(_indice),
              child: SozuNetworkImage(
                url: widget.imagenes[i],
                fit: widget.ajuste,
              ),
            ),
          ),
          if (total > 1) ...[
            Positioned(
              top: t.space.xs,
              right: t.space.xs,
              child: _Contador(actual: _indice + 1, total: total),
            ),
            Positioned(
              bottom: t.space.xs,
              left: 0,
              right: 0,
              child: _Puntos(total: total, actual: _indice, onIr: _ir),
            ),
            if (widget.conFlechas) ...[
              Positioned(
                left: t.space.xs,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _FlechaCarrusel(
                    icon: Icons.chevron_left,
                    tooltip: 'Anterior',
                    onPressed: () => _ir(_indice - 1),
                  ),
                ),
              ),
              Positioned(
                right: t.space.xs,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _FlechaCarrusel(
                    icon: Icons.chevron_right,
                    tooltip: 'Siguiente',
                    onPressed: () => _ir(_indice + 1),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Visor a pantalla completa con zoom, deslizamiento y contador.
///
/// Va por `Navigator` y no por `showDialog` para que el botón atrás del teléfono
/// lo cierre en vez de salir de la pantalla.
Future<void> mostrarVisorImagenes(
  BuildContext context,
  List<String> imagenes, {
  int indice = 0,
  String? titulo,
}) {
  if (imagenes.isEmpty) return Future<void>.value();
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          _VisorImagenes(imagenes: imagenes, inicial: indice, titulo: titulo),
    ),
  );
}

class _VisorImagenes extends StatefulWidget {
  final List<String> imagenes;
  final int inicial;
  final String? titulo;

  const _VisorImagenes({
    required this.imagenes,
    required this.inicial,
    this.titulo,
  });

  @override
  State<_VisorImagenes> createState() => _VisorImagenesState();
}

class _VisorImagenesState extends State<_VisorImagenes> {
  late final PageController _controller = PageController(
    initialPage: widget.inicial,
  );
  late int _indice = widget.inicial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final total = widget.imagenes.length;
    return Scaffold(
      // Fondo negro fijo: un visor de fotos no se tiñe con el tema, la foto
      // manda y cualquier superficie clara le compite.
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          total > 1
              ? '${widget.titulo ?? 'Galería'} · ${_indice + 1}/$total'
              : (widget.titulo ?? 'Galería'),
          style: t.text.label.copyWith(color: Colors.white),
        ),
      ),
      body: PhotoViewGallery.builder(
        pageController: _controller,
        itemCount: total,
        onPageChanged: (i) => setState(() => _indice = i),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, __) =>
            const Center(child: CircularProgressIndicator()),
        builder: (context, i) => PhotoViewGalleryPageOptions(
          imageProvider: cachedImageProvider(widget.imagenes[i]),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
        ),
      ),
    );
  }
}

/// Contador "3/8" sobre la imagen.
class _Contador extends StatelessWidget {
  final int actual;
  final int total;

  const _Contador({required this.actual, required this.total});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.color.overlay,
        borderRadius: t.radius.smBorder,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.xs,
          vertical: t.space.xxs,
        ),
        child: Text(
          '$actual/$total',
          // Sobre el velo oscuro del contador el texto es blanco siempre, no un
          // rol: el velo no cambia con el tema.
          style: t.text.overline.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// Puntos de posición del carrusel; tocar uno salta a esa imagen.
class _Puntos extends StatelessWidget {
  final int total;
  final int actual;
  final ValueChanged<int> onIr;

  const _Puntos({required this.total, required this.actual, required this.onIr});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          SPressable(
            onTap: () => onIr(i),
            borderRadius: t.radius.fullBorder,
            semanticLabel: 'Imagen ${i + 1}',
            child: Padding(
              padding: EdgeInsets.all(t.space.xxs),
              child: Container(
                width: i == actual ? _puntoActivo : _punto,
                height: _punto,
                decoration: BoxDecoration(
                  color: i == actual
                      ? Colors.white
                      : Colors.white.withValues(alpha: _puntoInactivoAlpha),
                  borderRadius: t.radius.fullBorder,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Flecha circular sobre la imagen.
class _FlechaCarrusel extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _FlechaCarrusel({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Material(
      color: t.color.overlay,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: _iconoFlecha,
        // Blanco fijo: va sobre el velo oscuro, que no cambia con el tema.
        color: Colors.white,
        icon: Icon(icon),
      ),
    );
  }
}

/// Medidas del carrusel. Son forma del componente, no aire entre cosas, así que
/// no salen de la escala de espaciado (mismo criterio que `SButton`).
const double _punto = 6;
const double _puntoActivo = 18;
const double _puntoInactivoAlpha = 0.45;
const double _iconoFlecha = 20;
const double _iconoVacio = 40;
