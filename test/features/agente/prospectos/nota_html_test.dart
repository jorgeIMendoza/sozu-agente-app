import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/nota_html.dart';

/// El contenido de una nota se escribe en el portal web con un editor
/// enriquecido. Estas pruebas fijan que el app lo LEA sin perder nada: si el
/// parseo se rompe, la nota se muestra en blanco o se guarda aplastada.
void main() {
  group('parseo del contenido', () {
    test('separa párrafos y conserva el formato de cada tramo', () {
      final nota = parsearNotaHtml(
        '<p>Habló el <strong>lunes</strong> y quedó <em>pendiente</em></p>'
        '<p><u>Llamar</u> el martes</p>',
      );

      expect(nota.bloques.length, 2);
      final primero = nota.bloques.first;
      expect(primero.tipo, TipoBloqueNota.parrafo);
      expect(primero.tramos.map((t) => t.texto), [
        'Habló el ',
        'lunes',
        ' y quedó ',
        'pendiente',
      ]);
      expect(primero.tramos[1].negrita, isTrue);
      expect(primero.tramos[1].cursiva, isFalse);
      expect(primero.tramos[3].cursiva, isTrue);
      expect(nota.bloques.last.tramos.first.subrayado, isTrue);
    });

    test('las viñetas salen como bloques de lista', () {
      final nota = parsearNotaHtml('<ul><li>Uno</li><li>Dos</li></ul>');
      expect(nota.bloques.map((b) => b.tipo), [
        TipoBloqueNota.vineta,
        TipoBloqueNota.vineta,
      ]);
      expect(nota.bloques.map((b) => b.tramos.single.texto), ['Uno', 'Dos']);
    });

    test('el color del autor llega como hexadecimal, no como token', () {
      final nota = parsearNotaHtml(
        '<p><span style="color: #dc2626">Urgente</span></p>',
      );
      expect(nota.bloques.single.tramos.single.colorHex, '#dc2626');
    });

    test('la imagen es su propio bloque con su URL firmada', () {
      final nota = parsearNotaHtml(
        '<p>Mira</p><p><img src="https://x/foto.png?t=1" /></p>',
      );
      expect(nota.bloques.length, 2);
      expect(nota.bloques.last.tipo, TipoBloqueNota.imagen);
      expect(nota.bloques.last.url, 'https://x/foto.png?t=1');
    });

    test('el adjunto no-imagen queda como tramo con enlace', () {
      final nota = parsearNotaHtml(
        '<p><a href="https://x/a.pdf" class="crm-attachment">'
        '\u{1F4CE} plano.pdf</a></p>',
      );
      final tramo = nota.bloques.single.tramos.single;
      expect(tramo.url, 'https://x/a.pdf');
      expect(tramo.texto.trim(), '\u{1F4CE} plano.pdf');
    });

    test('una etiqueta desconocida se ignora pero su texto se conserva', () {
      final nota = parsearNotaHtml('<p><mark>Ojo</mark> con esto</p>');
      expect(
        nota.bloques.single.tramos.map((t) => t.texto).join(),
        'Ojo con esto',
      );
      // El salto de línea sí corta el bloque.
      expect(parsearNotaHtml('<p>a<br>b</p>').bloques.length, 2);
    });

    test('deshace el escape que el app aplica al guardar', () {
      // El adaptador escapa & < > y nada más: son los que hay que devolver.
      expect(
        parsearNotaHtml(
          '<p>1 &lt; 2 &amp; 3 &gt; 2</p>',
        ).bloques.single.tramos.single.texto,
        '1 < 2 & 3 > 2',
      );
    });

    test('sin contenido no hay bloques', () {
      expect(parsearNotaHtml('').vacia, isTrue);
      expect(parsearNotaHtml('<p></p>').vacia, isTrue);
    });
  });

  group('cuerpo que se manda al editar', () {
    const conAdjuntos =
        '<p>Pidió cotización a <strong>24 meses</strong></p>'
        '<p><img src="https://x/foto.png" /></p>'
        '<p><a href="https://x/a.pdf" class="crm-attachment">'
        '\u{1F4CE} plano.pdf</a></p>';

    test('quita imágenes y adjuntos: se reescriben aparte', () {
      final cuerpo = cuerpoDeNotaSinAdjuntos(conAdjuntos);
      expect(cuerpo, '<p>Pidió cotización a <strong>24 meses</strong></p>');
    });

    test('una nota que solo era un archivo se queda sin cuerpo', () {
      expect(
        cuerpoDeNotaSinAdjuntos('<p><img src="https://x/foto.png" /></p>'),
        isEmpty,
      );
    });

    test('detecta el formato que se perdería al reescribir en texto plano', () {
      expect(notaTieneFormato(conAdjuntos), isTrue);
      expect(notaTieneFormato('<p>Llamar el lunes</p>'), isFalse);
      // Un archivo NO es formato: quitarlo del cuerpo no pierde nada.
      expect(
        notaTieneFormato('<p><img src="https://x/foto.png" /></p>'),
        isFalse,
      );
    });
  });
}
