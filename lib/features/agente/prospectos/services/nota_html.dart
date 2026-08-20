/// Lectura del contenido de una nota del CRM, que la plataforma guarda como
/// HTML acotado (`<p>`, `<strong>`, `<em>`, `<u>`, `<ul>/<li>`,
/// `<span style="color">`, `<img>` y el enlace `crm-attachment`).
///
/// Es Dart puro: no arma widgets. Quien pinta es
/// `components/nota_html_vista.dart`. Así se prueba el parseo sin montar UI y no
/// entra ninguna dependencia de HTML al proyecto.
library;

/// Tipo de bloque del contenido de una nota.
enum TipoBloqueNota {
  /// Párrafo suelto.
  parrafo,

  /// Elemento de una lista con viñetas.
  vineta,

  /// Imagen pegada a la nota.
  imagen,
}

/// Tramo de texto de un bloque con el formato que traía.
class TramoNota {
  final String texto;
  final bool negrita;
  final bool cursiva;
  final bool subrayado;

  /// Color en hexadecimal (`#dc2626`) tal como lo eligió quien escribió la nota;
  /// null cuando no se le puso color.
  final String? colorHex;

  /// Enlace del tramo (un archivo no-imagen se guarda como enlace).
  final String? url;

  const TramoNota(
    this.texto, {
    this.negrita = false,
    this.cursiva = false,
    this.subrayado = false,
    this.colorHex,
    this.url,
  });
}

/// Bloque del contenido: un párrafo, una viñeta o una imagen.
class BloqueNota {
  final TipoBloqueNota tipo;
  final List<TramoNota> tramos;

  /// URL de la imagen; solo en [TipoBloqueNota.imagen].
  final String? url;

  const BloqueNota({required this.tipo, this.tramos = const [], this.url});
}

/// Contenido de una nota ya interpretado.
class NotaHtml {
  final List<BloqueNota> bloques;

  const NotaHtml(this.bloques);

  bool get vacia => bloques.isEmpty;
}

/// Interpreta el contenido de una nota. Una etiqueta desconocida se ignora y su
/// texto se conserva: nunca se pierde lo escrito.
NotaHtml parsearNotaHtml(String html) {
  final bloques = <BloqueNota>[];
  final abiertos = <_Marca>[];
  var tramos = <TramoNota>[];
  var tipo = TipoBloqueNota.parrafo;

  void cerrarBloque() {
    if (tramos.isNotEmpty) {
      bloques.add(BloqueNota(tipo: tipo, tramos: List.of(tramos)));
    }
    tramos = [];
    tipo = TipoBloqueNota.parrafo;
  }

  for (final m in _reToken.allMatches(html)) {
    final token = m.group(0)!;
    if (!token.startsWith('<')) {
      final texto = _desescapar(token).replaceAll(_reEspacios, ' ');
      if (texto.trim().isEmpty && tramos.isEmpty) continue;
      tramos.add(_tramo(texto, abiertos));
      continue;
    }

    final tag = _reNombreTag.firstMatch(token);
    if (tag == null) continue;
    final cierra = tag.group(1) == '/';
    final nombre = tag.group(2)!.toLowerCase();

    switch (nombre) {
      case 'p' || 'div' || 'br' || 'ul' || 'ol':
        cerrarBloque();
      case 'li':
        cerrarBloque();
        if (!cierra) tipo = TipoBloqueNota.vineta;
      case 'img':
        final url = _atributo(token, 'src');
        if (url != null && url.isNotEmpty) {
          cerrarBloque();
          bloques.add(BloqueNota(tipo: TipoBloqueNota.imagen, url: url));
        }
      case 'strong' || 'b' || 'em' || 'i' || 'u' || 'span' || 'a':
        if (cierra) {
          final i = abiertos.lastIndexWhere((x) => x.tag == nombre);
          if (i >= 0) abiertos.removeAt(i);
        } else {
          abiertos.add(
            _Marca(
              nombre,
              colorHex: nombre == 'span'
                  ? _colorDeEstilo(_atributo(token, 'style'))
                  : null,
              url: nombre == 'a' ? _atributo(token, 'href') : null,
            ),
          );
        }
    }
  }
  cerrarBloque();
  return NotaHtml(bloques);
}

/// Contenido de la nota SIN sus archivos: es lo que se vuelve a mandar al editar
/// para conservar el formato, porque los archivos se reescriben aparte.
String cuerpoDeNotaSinAdjuntos(String html) => html
    .replaceAll(_reAdjunto, '')
    .replaceAll(_reImagen, '')
    .replaceAll(_reParrafoVacio, '')
    .trim();

/// La nota trae formato que se perdería al reescribirla como texto plano.
bool notaTieneFormato(String html) =>
    _reFormato.hasMatch(cuerpoDeNotaSinAdjuntos(html));

/// Formato abierto en el punto que se está leyendo.
class _Marca {
  final String tag;
  final String? colorHex;
  final String? url;

  const _Marca(this.tag, {this.colorHex, this.url});
}

const _sinMarca = _Marca('');

TramoNota _tramo(String texto, List<_Marca> abiertos) => TramoNota(
  texto,
  negrita: abiertos.any((m) => m.tag == 'strong' || m.tag == 'b'),
  cursiva: abiertos.any((m) => m.tag == 'em' || m.tag == 'i'),
  subrayado: abiertos.any((m) => m.tag == 'u'),
  colorHex: abiertos
      .lastWhere((m) => m.colorHex != null, orElse: () => _sinMarca)
      .colorHex,
  url: abiertos.lastWhere((m) => m.url != null, orElse: () => _sinMarca).url,
);

String? _atributo(String tag, String nombre) {
  for (final m in _reAtributo.allMatches(tag)) {
    if (m.group(1)!.toLowerCase() != nombre) continue;
    return _desescapar(m.group(3) ?? m.group(4) ?? '');
  }
  return null;
}

String? _colorDeEstilo(String? estilo) {
  if (estilo == null) return null;
  final valor = _reColor.firstMatch(estilo)?.group(1)?.trim();
  return valor == null || valor.isEmpty ? null : valor;
}

String _desescapar(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

final _reToken = RegExp(r'<[^>]*>|[^<]+', dotAll: true);
final _reNombreTag = RegExp(r'^<\s*(/?)\s*([a-zA-Z0-9]+)');
final _reAtributo = RegExp(
  '''(src|href|style)\\s*=\\s*("([^"]*)"|'([^']*)')''',
  caseSensitive: false,
);
final _reColor = RegExp(r'color\s*:\s*([^;]+)');
final _reImagen = RegExp(r'<img[^>]*>', caseSensitive: false);
final _reAdjunto = RegExp(
  r'<a\b[^>]*crm-attachment[^>]*>.*?</a\s*>',
  caseSensitive: false,
  dotAll: true,
);
final _reParrafoVacio = RegExp(
  r'<p\s*>(\s|&nbsp;)*</p\s*>',
  caseSensitive: false,
);
final _reFormato = RegExp(
  r'<\s*(strong|b|em|i|u|ul|ol|li|span|a)\b',
  caseSensitive: false,
);
final _reEspacios = RegExp(r'\s+');
