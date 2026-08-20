import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Lo que el agente decidió en el pad de firma.
class TrazoDeFirma {
  /// El trazo como `data:image/png;base64,...`, o null si eligió firmar sin él.
  ///
  /// Es data URL y no bytes crudos porque el backend parte la cadena en la coma
  /// y decide PNG o JPG por el mime que lleva dentro.
  final String? pngDataUrl;

  const TrazoDeFirma(this.pngDataUrl);
}

/// Recuadro del trazo. Con llave propia para que la prueba de widget lo alcance
/// sin depender del orden del árbol (la hoja pinta varios `CustomPaint`).
const padDeFirmaKey = Key('pad-de-firma');

/// Captura la firma autógrafa antes de generar la Carta de comercialización.
///
/// Devuelve null si el agente cerró la hoja sin decidir.
Future<TrazoDeFirma?> mostrarHojaDeFirma(BuildContext context) =>
    mostrarHojaDePerfil<TrazoDeFirma>(
      context,
      child: const _HojaDeFirma(),
      anchoMaximo: 520,
    );

class _HojaDeFirma extends StatefulWidget {
  const _HojaDeFirma();

  @override
  State<_HojaDeFirma> createState() => _HojaDeFirmaState();
}

class _HojaDeFirmaState extends State<_HojaDeFirma> {
  /// Trazos terminados; cada uno es la secuencia de puntos de un arrastre.
  final _trazos = <List<Offset>>[];

  Size _lienzo = Size.zero;
  bool _exportando = false;

  bool get _tieneTrazo => _trazos.any((t) => t.length > 1);

  void _empezar(Offset punto) => setState(() => _trazos.add([punto]));

  void _continuar(Offset punto) {
    if (_trazos.isEmpty) return;
    setState(() => _trazos.last.add(punto));
  }

  void _limpiar() => setState(_trazos.clear);

  /// Rasteriza los trazos a PNG. Se pinta al doble de la resolución lógica: el
  /// PNG termina dentro de un PDF y a 1x el trazo sale pixelado al imprimirlo.
  Future<String?> _aPngDataUrl() async {
    if (!_tieneTrazo || _lienzo.isEmpty) return null;
    const escala = 2.0;
    final grabadora = ui.PictureRecorder();
    final lienzo = Canvas(grabadora);
    lienzo.scale(escala);
    _PinturaDeFirma(_trazos).paint(lienzo, _lienzo);
    final imagen = await grabadora.endRecording().toImage(
      (_lienzo.width * escala).round(),
      (_lienzo.height * escala).round(),
    );
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();
    if (datos == null) return null;
    return 'data:image/png;base64,${base64Encode(datos.buffer.asUint8List())}';
  }

  Future<void> _guardar() async {
    setState(() => _exportando = true);
    final png = await _aPngDataUrl();
    if (!mounted) return;
    Navigator.of(context).pop(TrazoDeFirma(png));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;

    return HojaDePerfil(
      titulo: 'Firma autógrafa',
      subtitulo: 'Dibuja tu firma en el recuadro; se incluye en tu carta.',
      acciones: [
        SButton(
          label: 'Firmar sin trazo',
          onPressed: _exportando
              ? null
              : () => Navigator.of(context).pop(const TrazoDeFirma(null)),
          variant: SButtonVariant.ghost,
          fullWidth: false,
        ),
        SButton(
          label: 'Usar esta firma',
          onPressed: _tieneTrazo && !_exportando ? _guardar : null,
          loading: _exportando,
          loadingLabel: 'Preparando…',
          fullWidth: false,
        ),
      ],
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AvisoIlustrativa(),
          SizedBox(height: t.space.sm),
          _Lienzo(
            trazos: _trazos,
            onEmpezar: _empezar,
            onContinuar: _continuar,
            onMedida: (medida) => _lienzo = medida,
          ),
          SizedBox(height: t.space.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: SButton(
              label: 'Limpiar',
              icon: Icons.backspace_outlined,
              onPressed: _tieneTrazo && !_exportando ? _limpiar : null,
              variant: SButtonVariant.secondary,
              size: SButtonSize.sm,
              fullWidth: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// La firma del pad NO tiene validez legal: la que vale es la digital que se
/// hace con el proveedor al final. Decirlo aquí evita que el agente crea que ya
/// terminó al guardar el trazo.
class _AvisoIlustrativa extends StatelessWidget {
  const _AvisoIlustrativa();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      padding: EdgeInsets.all(t.space.sm),
      decoration: BoxDecoration(
        color: t.color.warningSoft,
        border: Border.all(color: t.color.warning),
        borderRadius: t.radius.mdBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: t.color.warningFg),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(
              'Este trazo es solo ilustrativo y aparece impreso en la carta. La '
              'firma con validez legal es la digital, al final del proceso.',
              style: t.text.caption.copyWith(
                color: t.color.warningFg,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recuadro donde se dibuja. El gesto se toma con [GestureDetector] y no con un
/// `Listener` para que el arrastre no lo robe el scroll de la hoja.
class _Lienzo extends StatelessWidget {
  final List<List<Offset>> trazos;
  final ValueChanged<Offset> onEmpezar;
  final ValueChanged<Offset> onContinuar;
  final ValueChanged<Size> onMedida;

  const _Lienzo({
    required this.trazos,
    required this.onEmpezar,
    required this.onContinuar,
    required this.onMedida,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      height: _altoDelLienzo,
      decoration: BoxDecoration(
        // Fondo claro fijo: el trazo es tinta de documento, no pintura de UI, y
        // sobre un fondo oscuro el agente no vería lo que va a imprimirse.
        color: Colors.white,
        border: Border.all(color: t.color.border),
        borderRadius: t.radius.mdBorder,
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, medidas) {
          onMedida(Size(medidas.maxWidth, medidas.maxHeight));
          return GestureDetector(
            key: padDeFirmaKey,
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => onEmpezar(d.localPosition),
            onPanUpdate: (d) => onContinuar(d.localPosition),
            child: CustomPaint(
              painter: _PinturaDeFirma(trazos),
              size: Size(medidas.maxWidth, medidas.maxHeight),
            ),
          );
        },
      ),
    );
  }
}

const _altoDelLienzo = 180.0;
const _grosorDelTrazo = 2.5;

/// Pinta los trazos. El mismo painter dibuja el recuadro en pantalla y el PNG
/// que se manda al backend, así que lo que el agente ve es lo que se imprime.
class _PinturaDeFirma extends CustomPainter {
  final List<List<Offset>> trazos;

  const _PinturaDeFirma(this.trazos);

  @override
  void paint(Canvas canvas, Size size) {
    // Tinta oscura fija, NO un rol del tema: el PNG se incrusta en un PDF de
    // fondo blanco, y en tema oscuro un `fg` claro saldría invisible ahí.
    final pluma = Paint()
      ..color = Colors.black87
      ..strokeWidth = _grosorDelTrazo
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final trazo in trazos) {
      if (trazo.length < 2) continue;
      final camino = Path()..moveTo(trazo.first.dx, trazo.first.dy);
      for (final punto in trazo.skip(1)) {
        camino.lineTo(punto.dx, punto.dy);
      }
      canvas.drawPath(camino, pluma);
    }
  }

  @override
  bool shouldRepaint(_PinturaDeFirma anterior) => true;
}
