import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/validaciones_del_perfil.dart';

/// El CURP se valida con el MISMO regex que el portal web: el backend lo revisa
/// igual, así que lo único que cambia es cuándo se avisa. Los casos de abajo son
/// los que antes pasaban con solo contar 18 caracteres.
void main() {
  _gateDeLaCarta();
  group('rfcValido', () {
    test('acepta el RFC de una persona física (13) y de una moral (12)', () {
      expect(rfcValido('HEAL850101AB1'), isTrue);
      expect(rfcValido('SOZ850101AB1'), isTrue);
    });

    test('normaliza minúsculas y espacios antes de comparar', () {
      expect(rfcValido('  heal850101ab1 '), isTrue);
    });

    test('rechaza longitudes fuera de 12 y 13', () {
      expect(rfcValido('HEAL850101A'), isFalse);
      expect(rfcValido('HEAL850101AB12'), isFalse);
    });

    test('rechaza los rellenos genéricos que el SAT usa de comodín', () {
      // El backend los rechaza con `rfc_invalido`: avisarlo aquí ahorra el viaje.
      expect(rfcValido('XXXX850101AB1'), isFalse);
      expect(rfcValido('AAAA850101AB1'), isFalse);
      expect(rfcValido('HEAL000000AB1'), isFalse);
    });
  });

  group('curpValido', () {
    test('acepta un CURP con el formato oficial', () {
      expect(curpValido('HEGA850312HDFRNL09'), isTrue);
    });

    test('acepta minúsculas y espacios: se normaliza antes de comparar', () {
      expect(curpValido('  hega850312hdfrnl09 '), isTrue);
    });

    test('rechaza 18 caracteres con el formato equivocado', () {
      // Longitud correcta, estructura no: es exactamente lo que la app dejaba
      // pasar cuando solo medía el largo.
      expect(curpValido('123456789012345678'), isFalse);
    });

    test('rechaza un sexo que no es H ni M', () {
      expect(curpValido('HEGA850312XDFRNL09'), isFalse);
    });

    test('rechaza una fecha que no son 6 dígitos', () {
      expect(curpValido('HEGA85O312HDFRNL09'), isFalse);
    });

    test('rechaza longitudes distintas de 18', () {
      expect(curpValido('HEGA850312HDFRNL0'), isFalse);
      expect(curpValido('HEGA850312HDFRNL099'), isFalse);
      expect(curpValido(''), isFalse);
    });
  });
}

/// La Carta de comercialización es un documento LEGAL y `firma_carta_crear` no
/// comprueba la identidad, así que este gate es el único que existe: si se
/// afloja, se puede firmar sin haber acreditado quién eres.
void _gateDeLaCarta() {
  group('motivoParaNoFirmarCarta', () {
    test('con todo en orden no hay motivo: se puede firmar', () {
      expect(
        motivoParaNoFirmarCarta(
          puedeEditar: true,
          notaSoloLectura: null,
          identidadValidada: true,
        ),
        isNull,
      );
    });

    test('sin identificación validada NO se firma, y se dice por qué', () {
      final motivo = motivoParaNoFirmarCarta(
        puedeEditar: true,
        notaSoloLectura: null,
        identidadValidada: false,
      );
      expect(motivo, isNotNull);
      expect(motivo, contains('identificación validada'));
    });

    test('la nota del dependiente gana: la carta no le aplica', () {
      expect(
        motivoParaNoFirmarCarta(
          puedeEditar: true,
          notaSoloLectura: 'Solo aplica al agente independiente',
          identidadValidada: true,
        ),
        'Solo aplica al agente independiente',
      );
    });

    test(
      'sin permiso de edición tampoco, aunque la identidad esté validada',
      () {
        expect(
          motivoParaNoFirmarCarta(
            puedeEditar: false,
            notaSoloLectura: null,
            identidadValidada: true,
          ),
          isNotNull,
        );
      },
    );
  });
}
