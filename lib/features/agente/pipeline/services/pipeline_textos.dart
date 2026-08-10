import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Textos de la pantalla de Pipeline que no son UI: enmascarado del modo
/// presentación y traducción de los códigos de error a algo accionable.
///
/// Vive fuera de los widgets para poder fijarlo con pruebas: el mensaje que ve
/// el agente cuando algo falla es parte del contrato de la pantalla.

/// Relleno del modo presentación. Longitud fija a propósito: si dependiera del
/// texto original, el ancho del bloque revelaría el monto.
const String kMascaraPresentacion = '••••••';

/// Oculta montos, nombres y correos cuando el modo presentación está activo.
/// No cambia lo que se envía al servidor: es solo lo que se pinta.
String mascara(String? texto, {required bool activo}) {
  if (activo) return kMascaraPresentacion;
  final t = texto ?? '';
  return t.isEmpty ? '-' : t;
}

/// Mensaje para el agente a partir del error. Se lee el CÓDIGO, nunca el status
/// suelto: el backend responde 503 tanto por pipeline ausente como por catálogo
/// ausente y la salida para el agente es distinta.
String mensajeDeError(Object error) {
  if (error is AccionNoDisponible) {
    return switch (error.motivo) {
      'negocio_sin_pipeline' =>
        'Este negocio todavía no existe en el pipeline, así que no se puede '
            'mover de etapa. Avísale al administrador.',
      'etapa_automatica' =>
        'Esa etapa la mueve el sistema con un hecho real: la oferta, el '
            'apartado aplicado o el estatus de la propiedad.',
      'catalogo_no_disponible' =>
        'El catálogo de razones todavía no está habilitado en este ambiente.',
      'sin_permiso' => 'No tienes permiso para modificar el pipeline.',
      _ => 'No se pudo completar la acción.',
    };
  }

  if (error is ApiError) {
    return switch (error.code) {
      'network_error' =>
        'Sin conexión con el servidor. Revisa tu internet e intenta de nuevo.',
      'not_owner' => 'Esta oferta la creó otro agente: no puedes modificarla.',
      'not_found' => 'La oferta ya no existe o dejó de estar activa.',
      'pipeline_unavailable' =>
        'Mover etapas a mano todavía no está habilitado en este ambiente. Las '
            'etapas automáticas se siguen moviendo solas.',
      'stage_not_manual' =>
        'Esa etapa la mueve el sistema, no se puede asignar a mano.',
      'invalid_stage' => 'Esa etapa no existe en el pipeline.',
      'catalog_unavailable' =>
        'El catálogo de razones todavía no está habilitado en este ambiente.',
      'invalid_motivo' =>
        'Ese motivo no está dado de alta: pide al administrador que configure '
            'el catálogo.',
      'scheme_mismatch' =>
        'El plan elegido no corresponde a esta oferta. Elige otro.',
      'missing_email' =>
        'El prospecto no tiene correo registrado, y el link del cliente se '
            'emite a un correo. Captúralo en Prospectos.',
      'digital_offer_unavailable' =>
        'La oferta digital no está habilitada en este ambiente.',
      'feature_unavailable' =>
        'Esta parte del pipeline todavía no está habilitada en el ambiente.',
      'forbidden_role' => 'Tu rol no tiene acceso al pipeline.',
      _ => 'No se pudo completar la acción. Intenta de nuevo.',
    };
  }

  return 'No se pudo completar la acción. Intenta de nuevo.';
}

/// Título corto del estado de error de la pantalla completa.
String tituloDeError(Object error) {
  if (error is ApiError && error.code == 'network_error') {
    return 'Sin conexión';
  }
  return 'No pudimos cargar tu pipeline';
}

/// Resultado de fijar el esquema, dicho como pasó de verdad. Un "listo"
/// genérico esconde el caso en que el plan se guardó pero los acuerdos de la
/// cuenta quedaron con el esquema anterior.
String mensajeDeEsquema(CambioEsquema cambio) => switch (cambio
    .acuerdosRegenerados) {
  true => 'Plan guardado y acuerdos de la cuenta regenerados.',
  false =>
    'Plan guardado, pero los acuerdos de la cuenta no se regeneraron: '
        'pídele a cobranza que los regenere.',
  null =>
    'Plan guardado. Esta oferta todavía no tiene cuenta de cobranza, así que '
        'no había acuerdos que regenerar.',
};
