import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/prospectos/services/nota_html.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/network_image.dart';

/// Alto de una imagen pegada a la nota.
const double _altoImagen = 180;

/// Contenido de una nota con su formato: negritas, cursivas, subrayado,
/// viñetas, color e imágenes en línea.
///
/// Es tonta: recibe el HTML y devuelve la intención de abrir una imagen. El
/// parseo vive en `services/nota_html.dart`.
class NotaHtmlVista extends StatelessWidget {
  /// Contenido con formato. Vacío = se pinta [textoPlano].
  final String html;

  /// Respaldo cuando la nota no trae HTML (notas viejas o citas).
  final String textoPlano;

  /// Recorte en líneas para la línea de tiempo; null pinta todo.
  final int? maxLineas;

  /// Abre una imagen de la nota en el visor. Sin él, las imágenes no responden.
  final void Function(String url)? onVerImagen;

  const NotaHtmlVista({
    super.key,
    required this.html,
    this.textoPlano = '',
    this.maxLineas,
    this.onVerImagen,
  });

  /// Versión recortada para la línea de tiempo: solo texto, sin imágenes. Los
  /// archivos ya se listan como insignias debajo del movimiento.
  const NotaHtmlVista.recortada({
    super.key,
    required this.html,
    this.textoPlano = '',
    this.maxLineas = 3,
  }) : onVerImagen = null;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final compacta = maxLineas != null;
    final base = compacta
        ? t.text.caption.copyWith(color: t.color.fgMuted)
        : t.text.bodySmall.copyWith(color: t.color.fg);
    final nota = parsearNotaHtml(html);

    if (nota.vacia) {
      return Text(
        textoPlano,
        style: base,
        maxLines: maxLineas,
        overflow: compacta ? TextOverflow.ellipsis : TextOverflow.clip,
      );
    }

    if (compacta) {
      return Text.rich(
        TextSpan(children: _tramosSeguidos(context, nota, base)),
        style: base,
        maxLines: maxLineas,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in nota.bloques)
          Padding(
            padding: EdgeInsets.only(bottom: t.space.xs),
            child: b.tipo == TipoBloqueNota.imagen
                ? _Imagen(url: b.url!, onVer: onVerImagen)
                : Text.rich(
                    TextSpan(
                      children: [
                        if (b.tipo == TipoBloqueNota.vineta)
                          const TextSpan(text: '•  '),
                        ..._tramos(context, b.tramos, base),
                      ],
                    ),
                    style: base,
                  ),
          ),
      ],
    );
  }

  /// Todos los bloques de texto en un solo párrafo, separados por salto de
  /// línea: es lo que permite recortar el conjunto a [maxLineas].
  List<InlineSpan> _tramosSeguidos(
    BuildContext context,
    NotaHtml nota,
    TextStyle base,
  ) {
    final spans = <InlineSpan>[];
    for (final b in nota.bloques) {
      if (b.tipo == TipoBloqueNota.imagen) continue;
      if (spans.isNotEmpty) spans.add(const TextSpan(text: '\n'));
      if (b.tipo == TipoBloqueNota.vineta) {
        spans.add(const TextSpan(text: '•  '));
      }
      spans.addAll(_tramos(context, b.tramos, base));
    }
    return spans;
  }

  List<InlineSpan> _tramos(
    BuildContext context,
    List<TramoNota> tramos,
    TextStyle base,
  ) => [
    for (final tr in tramos)
      TextSpan(text: tr.texto, style: _estilo(context, tr, base)),
  ];

  /// Estilo de un tramo. El enlace se subraya pero NO se hace tocable: los
  /// archivos de la nota se abren desde sus insignias, y un reconocedor de gesto
  /// por tramo habría que crearlo y liberarlo en cada repintado.
  TextStyle _estilo(BuildContext context, TramoNota tr, TextStyle base) {
    final tone = context.s.color;
    final enlace = tr.url != null && tr.url!.isNotEmpty;
    return base.copyWith(
      fontWeight: tr.negrita ? FontWeight.w700 : null,
      fontStyle: tr.cursiva ? FontStyle.italic : null,
      decoration: tr.subrayado || enlace ? TextDecoration.underline : null,
      color: enlace ? tone.primary : _color(context, tr.colorHex),
    );
  }

  /// Color elegido por quien escribió la nota.
  ///
  /// Solo se respeta en tema claro: los seis colores del editor web son oscuros
  /// por diseño y sobre un fondo oscuro dejarían el texto ilegible. En oscuro
  /// gana el color del tema.
  Color? _color(BuildContext context, String? hex) {
    if (hex == null || Theme.of(context).brightness == Brightness.dark) {
      return null;
    }
    return colorDeNota(hex);
  }
}

/// Convierte un color de nota (`#dc2626`, `#f00`) a [Color]; null si no se
/// entiende. No es un token del sistema de diseño: es dato escrito por el autor.
Color? colorDeNota(String hex) {
  var v = hex.trim().replaceFirst('#', '');
  if (v.length == 3) {
    v = v.split('').map((c) => '$c$c').join();
  }
  if (v.length != 6) return null;
  final n = int.tryParse(v, radix: 16);
  // El hex del autor no trae alfa: se le suma opaco.
  const opaco = 0xFF000000;
  return n == null ? null : Color(opaco | n);
}

/// Imagen pegada a la nota. Se abre en el visor al tocarla.
class _Imagen extends StatelessWidget {
  final String url;
  final void Function(String url)? onVer;

  const _Imagen({required this.url, this.onVer});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final imagen = Container(
      height: _altoImagen,
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.color.surfaceAlt,
        borderRadius: t.radius.mdBorder,
        border: Border.all(color: t.color.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: SozuNetworkImage(
        url: url,
        fit: BoxFit.contain,
        placeholderIcon: Icons.image_outlined,
      ),
    );
    if (onVer == null) return imagen;
    return SPressable(
      onTap: () => onVer!(url),
      borderRadius: t.radius.mdBorder,
      semanticLabel: 'Ver la imagen de la nota',
      child: imagen,
    );
  }
}
