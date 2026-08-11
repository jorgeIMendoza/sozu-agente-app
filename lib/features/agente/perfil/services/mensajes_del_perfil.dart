import 'package:sozu_agente_app/shared/api_error.dart';

/// Traducción de los códigos de error del perfil a algo que el agente pueda
/// resolver.
///
/// Los códigos van SIEMPRE en el texto cuando no se reconocen: un "intenta de
/// nuevo" pelón deja al agente atorado y a quien depura sin nada que buscar en
/// los logs.

/// Campo del formulario al que pertenece un error de validación, o null si el
/// error es de toda la operación.
///
/// Sirve para pintar el mensaje JUNTO al campo en vez de en un toast genérico: un
/// "curp_invalido" en un aviso flotante no le dice al agente cuál de los seis
/// campos tiene que corregir.
String? campoDelError(String codigo) => switch (codigo) {
  'nombre_requerido' => 'nombre',
  'telefono_invalido' => 'telefono',
  'curp_requerido' || 'curp_invalido' || 'curp_duplicado' => 'curp',
  'rfc_duplicado' => 'rfc',
  'banco_o_cuenta_requeridos' ||
  'cuenta_solo_digitos' ||
  'cuenta_longitud_invalida' => 'numero_cuenta',
  'clabe_invalida' || 'clabe_igual_a_cuenta' => 'clabe',
  'titular_requerido' => 'titular',
  'evidencia_requerida' ||
  'evidencia_invalida' ||
  'evidencia_demasiado_grande' => 'evidencia',
  'frase_demasiado_larga' => 'frase',
  _ => null,
};

/// Qué se le dice al agente por cada código del backend.
String mensajeDeError(ApiError e) => switch (e.code) {
  // ── Identidad ──────────────────────────────────────────────────────────
  'nombre_requerido' => 'Escribe tu nombre completo.',
  'telefono_invalido' => 'El teléfono debe tener 10 dígitos.',
  'curp_requerido' => 'Captura tu CURP.',
  'curp_invalido' =>
    'El CURP no tiene el formato oficial: 18 caracteres, como '
        'GARC850101HDFRRL09.',
  'curp_duplicado' =>
    'Ese CURP ya está registrado en otra cuenta. Revísalo; si es tuyo, '
        'avísale a tu contacto en SOZU.',
  'rfc_duplicado' =>
    'Ese RFC ya está registrado en otra cuenta. Revísalo; si es tuyo, '
        'avísale a tu contacto en SOZU.',

  // ── Presentación y foto ────────────────────────────────────────────────
  'frase_demasiado_larga' => 'Tu presentación no puede pasar de 280 caracteres.',
  'mime_no_soportado' => 'Solo se aceptan imágenes JPG, PNG o WebP.',
  'imagen_requerida' => 'No llegó la imagen. Vuelve a elegirla.',
  'imagen_invalida' => 'No pudimos leer la imagen. Elige otra.',
  'imagen_demasiado_grande' =>
    'La imagen pesa más de 10 MB. Elige una más ligera.',

  // ── Documentos ─────────────────────────────────────────────────────────
  'tipo_invalido' =>
    'Ese tipo de documento no va en tu expediente. Recarga la pantalla e '
        'intenta de nuevo.',
  'archivo_requerido' => 'No llegó el archivo. Vuelve a elegirlo.',
  'archivo_invalido' => 'No pudimos leer el archivo. Elige otro.',
  'archivo_demasiado_grande' =>
    'El archivo pesa más de 10 MB. Vuelve a exportarlo más ligero.',
  'extension_no_soportada' => 'Solo se aceptan archivos PDF, JPG, PNG o WebP.',
  'upload_failed' =>
    'No pudimos guardar el archivo. Revisa tu conexión e intenta de nuevo.',

  // ── Cuenta de dispersión ───────────────────────────────────────────────
  'banco_o_cuenta_requeridos' => 'Elige tu banco y captura el número de cuenta.',
  'titular_requerido' => 'Escribe el nombre del titular de la cuenta.',
  'cuenta_solo_digitos' => 'El número de cuenta solo puede tener dígitos.',
  'cuenta_longitud_invalida' =>
    'El número de cuenta debe tener entre 8 y 34 dígitos.',
  'clabe_invalida' => 'La CLABE debe tener exactamente 18 dígitos.',
  'clabe_igual_a_cuenta' => 'La CLABE y el número de cuenta no pueden ser iguales.',
  'evidencia_requerida' =>
    'Adjunta la carátula de tu estado de cuenta: sin ella no podemos validarla.',
  'evidencia_invalida' => 'No pudimos leer la carátula. Elige otro archivo.',
  'evidencia_demasiado_grande' =>
    'La carátula pesa más de 10 MB. Vuelve a exportarla más ligera.',
  'cuenta_validada' =>
    'Esta cuenta ya está validada y es la que recibe tus comisiones. Para '
        'darla de baja, avísale a tu contacto en SOZU.',
  'not_owner' =>
    'Esa cuenta no está en tu perfil. Recarga la pantalla e intenta de nuevo.',

  // ── Firma de la carta ──────────────────────────────────────────────────
  'datos_incompletos' =>
    'Completa tu nombre y tu correo antes de firmar la carta.',
  'carta_no_configurada' =>
    'Tu carta todavía no está configurada. Avísale a tu contacto en SOZU.',
  'firma_creacion_failed' =>
    'No pudimos preparar tu carta en este momento. Intenta más tarde.',

  // ── Permisos y transversales ───────────────────────────────────────────
  'forbidden_field' =>
    'Esta información la administra tu inmobiliaria, por eso no se puede '
        'editar aquí.',
  'forbidden_role' => 'Tu cuenta no tiene acceso a esta información.',
  'not_found' =>
    'No encontramos tu perfil. Cierra sesión y vuelve a entrar; si sigue, '
        'avísale a tu contacto en SOZU.',
  'network_error' =>
    'No pudimos conectar. Revisa tu conexión e intenta de nuevo.',
  'invalid_action' =>
    'Esta función todavía no está disponible en tu versión de la app. '
        'Actualízala e intenta de nuevo.',
  _ => 'No se pudo completar la operación (${e.code}). Intenta de nuevo.',
};

/// Título del estado de error de una pantalla completa, según qué falló.
String tituloDeErrorDeCarga(Object error) {
  if (error is ApiError && error.code == 'forbidden_role') {
    return 'Tu cuenta no tiene acceso a tu perfil';
  }
  return 'No pudimos cargar tu perfil';
}

/// Detalle accionable del estado de error de una pantalla completa.
String mensajeDeErrorDeCarga(Object error) {
  if (error is ApiError) return mensajeDeError(error);
  return 'Algo se rompió de nuestro lado. Intenta de nuevo.';
}
