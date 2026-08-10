import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/archivos_del_perfil.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/mensajes_del_perfil.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'dart:typed_data';

/// Los códigos de validación del backend tienen que llegar al CAMPO que los
/// causó, no a un aviso genérico: un "clabe_invalida" flotando no le dice al
/// agente cuál de los cinco campos del formulario tiene que corregir.
void main() {
  group('campoDelError', () {
    test('cada código de validación apunta a su campo', () {
      expect(campoDelError('curp_invalido'), 'curp');
      expect(campoDelError('curp_duplicado'), 'curp');
      expect(campoDelError('telefono_invalido'), 'telefono');
      expect(campoDelError('clabe_invalida'), 'clabe');
      expect(campoDelError('clabe_igual_a_cuenta'), 'clabe');
      expect(campoDelError('cuenta_solo_digitos'), 'numero_cuenta');
      expect(campoDelError('cuenta_longitud_invalida'), 'numero_cuenta');
      expect(campoDelError('titular_requerido'), 'titular');
      expect(campoDelError('evidencia_requerida'), 'evidencia');
    });

    test('un error de toda la operación no apunta a ningún campo', () {
      expect(campoDelError('forbidden_field'), isNull);
      expect(campoDelError('network_error'), isNull);
      expect(campoDelError('internal_error'), isNull);
    });
  });

  group('mensajeDeError', () {
    test('el recorte del dependiente se explica, no se disculpa', () {
      expect(
        mensajeDeError(ApiError(403, 'forbidden_field')),
        contains('la administra tu inmobiliaria'),
      );
    });

    test('una cuenta validada dice a quién acudir', () {
      final mensaje = mensajeDeError(ApiError(403, 'cuenta_validada'));
      expect(mensaje, contains('contacto en SOZU'));
    });

    test('un código desconocido se muestra para poder depurarlo', () {
      // Un "intenta de nuevo" pelón deja al agente atorado y a quien depura sin
      // nada que buscar en los logs.
      expect(
        mensajeDeError(ApiError(500, 'algo_nuevo')),
        contains('algo_nuevo'),
      );
    });

    test('el límite de 10 MB se nombra en el mensaje', () {
      expect(
        mensajeDeError(ApiError(413, 'archivo_demasiado_grande')),
        contains('10 MB'),
      );
    });
  });

  group('validación local de archivos', () {
    Uint8List bytes(int n) => Uint8List.fromList(List.filled(n, 0x41));

    test('un archivo vacío se rechaza sin gastar el viaje', () {
      expect(motivoArchivoInvalido('csf.pdf', Uint8List(0)), isNotNull);
    });

    test('el límite local es el mismo que el del backend', () {
      expect(kMaxBytesArchivo, 10 * 1024 * 1024);
      expect(
        motivoArchivoInvalido('csf.pdf', bytes(kMaxBytesArchivo + 1)),
        contains('10 MB'),
      );
      expect(motivoArchivoInvalido('csf.pdf', bytes(1024)), isNull);
    });

    test('una extensión que el backend no acepta se rechaza aquí', () {
      expect(motivoArchivoInvalido('csf.docx', bytes(1024)), isNotNull);
      expect(motivoArchivoInvalido('ine.jpg', bytes(1024)), isNull);
    });

    test('la foto de perfil no admite PDF', () {
      expect(motivoFotoInvalida('yo.pdf', bytes(1024)), isNotNull);
      expect(motivoFotoInvalida('yo.png', bytes(1024)), isNull);
      expect(mimeDeFoto('yo.JPG'), 'image/jpeg');
      expect(mimeDeFoto('yo.pdf'), isNull);
    });

    test('el PDF se reconoce por sus bytes, no por su nombre', () {
      // Un .jpg renombrado a .pdf pasa cualquier filtro por extensión.
      final pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31]);
      expect(esPdf(pdf), isTrue);
      expect(esPdf(bytes(16)), isFalse);
    });

    test('el content type sale de la extensión real', () {
      expect(contentTypeDe('csf.pdf'), 'application/pdf');
      expect(contentTypeDe('ine.png'), 'image/png');
      expect(contentTypeDe('ine.webp'), 'image/webp');
      expect(contentTypeDe('ine.jpeg'), 'image/jpeg');
    });
  });
}
