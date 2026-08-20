import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/mensajes_del_perfil.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// El estatus de la Constancia lo decide EL SERVIDOR, que lee el PDF: la app ya
/// no manda `estatus` y solo transmite el veredicto. Estas pruebas fijan las dos
/// trampas del contrato: las claves `csf_*` DESAPARECEN del JSON cuando no
/// aplican, y el motivo viene redactado para el agente, así que se muestra tal
/// cual.
void main() {
  group('ResultadoDeCarga.desde', () {
    test('un documento que no es la Constancia no trae veredicto', () {
      // Las tres claves viajan como `undefined` y por eso no llegan: null es el
      // dato ("no aplica"), no un hueco que haya que rellenar.
      final r = ResultadoDeCarga.desde({
        'id': 9876,
        'estatus': 'pendiente',
        'url_firmada': 'https://ejemplo/doc.pdf',
      });

      expect(r.estado, EstadoDocumento.pendiente);
      expect(r.constanciaValidada, isNull);
      expect(r.motivo, isNull);
      expect(r.campos, isNull);
    });

    test('la Constancia validada trae los campos que extrajo el servidor', () {
      final r = ResultadoDeCarga.desde({
        'id': 9876,
        'estatus': 'validado',
        'csf_validada': true,
        'csf_campos': {
          'rfc': 'HEAL850101AB1',
          'curp': 'HEAL850101HDFRRL09',
          'nombre': 'Alex Hernández',
          'regimen': '612',
          'regimen_resuelto': true,
          'codigo_postal': '48300',
          'calle': 'Av. Insurgentes Sur',
          'num_ext': '123',
          'num_int': null,
          'colonia': 'Del Valle',
        },
      });

      expect(r.estado, EstadoDocumento.validado);
      expect(r.constanciaValidada, isTrue);
      expect(r.campos?.regimen, '612');
      expect(r.campos?.regimenResuelto, isTrue);
      expect(r.campos?.numInt, isNull);
      expect(r.campos?.vacio, isFalse);
    });

    test('la Constancia rechazada trae el motivo y ningún campo', () {
      final r = ResultadoDeCarga.desde({
        'estatus': 'pendiente',
        'csf_validada': false,
        'csf_motivo':
            'La Constancia de Situación Fiscal es del 01/01/2026 y tiene más '
            'de 3 meses. Descárgala actualizada en el portal del SAT.',
      });

      expect(r.constanciaValidada, isFalse);
      expect(r.motivo, contains('más de 3 meses'));
      expect(r.campos, isNull);
    });
  });

  group('mensajeDeCarga', () {
    test('la Constancia validada dice qué se tomó del documento', () {
      final mensaje = mensajeDeCarga(
        ResultadoDeCarga.desde({
          'estatus': 'validado',
          'csf_validada': true,
          'csf_campos': {
            'rfc': 'HEAL850101AB1',
            'curp': 'HEAL850101HDFRRL09',
            'regimen': '612',
            'regimen_resuelto': true,
            'codigo_postal': '48300',
          },
        }),
      );

      expect(mensaje, contains('validada'));
      expect(mensaje, contains('RFC'));
      expect(mensaje, contains('CURP'));
      expect(mensaje, contains('régimen'));
      expect(mensaje, contains('domicilio fiscal'));
    });

    test('sin campos extraídos no inventa una lista vacía', () {
      final mensaje = mensajeDeCarga(
        const ResultadoDeCarga(
          estado: EstadoDocumento.validado,
          constanciaValidada: true,
        ),
      );

      expect(
        mensaje,
        'Constancia validada. Tu información fiscal quedó registrada.',
      );
    });

    test('el motivo del servidor se muestra TAL CUAL', () {
      const motivo =
          'El PDF no contiene texto: sube la Constancia original del SAT, no '
          'un escaneo.';
      final mensaje = mensajeDeCarga(
        const ResultadoDeCarga(
          estado: EstadoDocumento.pendiente,
          constanciaValidada: false,
          motivo: motivo,
        ),
      );

      expect(mensaje, startsWith(motivo));
      expect(mensaje, contains('revisión manual'));
    });

    test('un documento cualquiera solo dice en qué estado quedó', () {
      expect(
        mensajeDeCarga(
          const ResultadoDeCarga(estado: EstadoDocumento.revision),
        ),
        'Documento enviado. Queda pendiente de validación.',
      );
      expect(
        mensajeDeCarga(
          const ResultadoDeCarga(estado: EstadoDocumento.validado),
        ),
        'Documento validado.',
      );
    });
  });

  group('errores de guardar_fiscal', () {
    test('el RFC inválido y el duplicado apuntan al campo del RFC', () {
      expect(campoDelError('rfc_invalido'), 'rfc');
      expect(campoDelError('rfc_duplicado'), 'rfc');
      expect(campoDelError('regimen_invalido'), 'regimen');
    });

    test('el RFC inválido explica el formato, no solo que está mal', () {
      final mensaje = mensajeDeError(ApiError(400, 'rfc_invalido'));

      expect(mensaje, contains('13 caracteres'));
      expect(mensaje, contains('12'));
    });

    test('el RFC duplicado dice a quién acudir si es el suyo', () {
      final mensaje = mensajeDeError(ApiError(409, 'rfc_duplicado'));

      expect(mensaje, contains('ya está registrado'));
      expect(mensaje, contains('contacto en SOZU'));
    });

    test('campos_incompletos enumera lo que exige el backend', () {
      final mensaje = mensajeDeError(ApiError(400, 'campos_incompletos'));

      expect(mensaje, contains('municipio'));
      expect(mensaje, contains('interior es opcional'));
    });

    test('al dependiente se le explica el recorte, no se le disculpa', () {
      expect(
        mensajeDeError(ApiError(403, 'forbidden_field')),
        contains('la administra tu inmobiliaria'),
      );
    });
  });
}
