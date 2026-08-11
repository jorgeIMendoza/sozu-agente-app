import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/core/archivo_pdf.dart';

/// El selector de PDF y su validacion los comparten la factura de comision y el
/// expediente. Lo critico: el veredicto sale de los BYTES, no del nombre.
void main() {
  group('archivo PDF', () {
    Uint8List bytes(List<int> b) => Uint8List.fromList(b);
    final pdf = bytes([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37]);

    test('acepta un PDF real', () {
      expect(esPdf(pdf), isTrue);
      expect(motivoArchivoInvalido(pdf), isNull);
    });

    test('rechaza un JPEG aunque el nombre diga .pdf', () {
      // La extension del nombre no interviene: solo los bytes.
      final jpg = bytes([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46]);
      expect(esPdf(jpg), isFalse);
      expect(motivoArchivoInvalido(jpg), contains('no es un PDF'));
    });

    test('rechaza el archivo vacio y el que pasa de 10 MB', () {
      expect(motivoArchivoInvalido(bytes([])), contains('vacío'));
      final grande = Uint8List(kMaxArchivoBytes + 1)
        ..setRange(0, 5, [0x25, 0x50, 0x44, 0x46, 0x2d]);
      expect(motivoArchivoInvalido(grande), contains('10 MB'));
    });
  });
}
