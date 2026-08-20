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

/// Mensaje con el que se comparte la oferta (WhatsApp, hoja del sistema).
/// Mismo armado que el portal web: saludo con el primer nombre del prospecto, la
/// unidad y el link en su propio renglón.
String mensajeDeOferta({
  required String url,
  String? nombreLead,
  String unidad = '',
  String proyecto = '',
}) {
  final primer = (nombreLead ?? '').trim().split(' ').first;
  final donde = [unidad, proyecto].where((s) => s.isNotEmpty).join(' de ');
  final cuerpo = primer.isEmpty
      ? 'Aquí está tu oferta digital'
      : 'Hola $primer, aquí está tu oferta digital';
  return '$cuerpo${donde.isEmpty ? '' : ' - $donde'}:\n$url';
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
      'email_invalido' =>
        'Ese correo no es válido: revisa que esté completo y vuelve a '
            'enviarlo.',
      'email_failed' =>
        'El correo no salió. Intenta de nuevo o mándale el link por WhatsApp.',
      'pdf_failed' =>
        'No se pudo generar el PDF de la oferta. Intenta de nuevo; si vuelve a '
            'fallar, comparte el link del cliente.',
      'server_misconfigured' =>
        'Falta configuración en el servidor para esta acción. Avísale al '
            'administrador.',
      'missing_id' =>
        'No pudimos identificar la oferta. Cierra la hoja y vuelve a abrirla.',
      'missing_email' =>
        'El prospecto no tiene correo registrado, y el link del cliente se '
            'emite a un correo. Captúralo en Prospectos.',
      'digital_offer_unavailable' =>
        'La oferta digital no está habilitada en este ambiente. Sin el link no '
            'hay oferta que compartir, así que no se creó nada.',
      'capacitacion_pendiente' =>
        'Para cotizar necesitas haber tomado tu capacitación. Agéndala en tu '
            'perfil y vuelve a intentarlo.',
      'unidad_no_disponible' =>
        'Esa unidad se acaba de apartar o vender. Refresca el inventario y '
            'elige otra.',
      'oferta_duplicada' =>
        'Ya generaste una oferta idéntica hace un momento: búscala en tu '
            'pipeline en vez de crear otra.',
      'proyecto_no_permitido' =>
        'Ese desarrollo no está entre los que puedes vender. Pídele a tu '
            'supervisor que te lo asigne.',
      'lead_conflict' =>
        'Llegaron dos prospectos a la vez. Elige uno de tu cartera o captura '
            'uno nuevo, no los dos.',
      'missing_lead' =>
        'Falta el prospecto: elige uno de tu cartera o captura uno nuevo.',
      'nombre_invalido' => 'Captura el nombre completo del prospecto.',
      'telefono_invalido' =>
        'El teléfono del prospecto debe traer 10 dígitos, sin lada ni '
            'espacios.',
      'rfc_invalido' =>
        'El RFC no tiene el formato que pide el SAT (12 o 13 caracteres). '
            'Corrígelo o déjalo vacío.',
      'curp_invalido' =>
        'La CURP no tiene el formato oficial (18 caracteres). Corrígela o '
            'déjala vacía.',
      'tipo_persona_invalido' =>
        'Elige si el prospecto es persona física o moral.',
      'invalid_action' => kOfertaSoloEnPortalWeb,
      'feature_unavailable' =>
        'Esta parte del pipeline todavía no está habilitada en el ambiente.',
      'forbidden_role' => 'Tu rol no tiene acceso al pipeline.',
      'internal_error' =>
        'Algo se rompió de nuestro lado y la acción no se completó. Intenta de '
            'nuevo; si sigue, avísale a tu contacto en SOZU.',
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
String mensajeDeEsquema(
  CambioEsquema cambio,
) => switch (cambio.acuerdosRegenerados) {
  true => 'Plan guardado y acuerdos de la cuenta regenerados.',
  false =>
    'Plan guardado, pero los acuerdos de la cuenta no se regeneraron: '
        'pídele a cobranza que los regenere.',
  null =>
    'Plan guardado. Esta oferta todavía no tiene cuenta de cobranza, así que '
        'no había acuerdos que regenerar.',
};

// ── Alta de oferta desde el inventario ──────────────────────────────────────

/// Lo que se le dice al agente cuando `crear_oferta` todavía no está desplegada.
/// Es el mismo mensaje que daba el aviso anterior del botón, para que no cambie
/// de historia entre versiones.
const String kOfertaSoloEnPortalWeb =
    'Generar la oferta desde el app todavía no está habilitado: por ahora se '
    'configura desde el portal web.';

/// El `agente-pipeline` desplegado no conoce la acción que se le pidió.
///
/// Es el caso de degradación honesta: la app puede publicarse antes que la Edge
/// Function, y un error crudo aquí se leería como una falla del agente.
bool esAccionNoDesplegada(Object error) =>
    error is ApiError && error.code == 'invalid_action';

/// El servidor bloqueó la oferta porque falta la capacitación del agente. La
/// pantalla lo usa para ofrecer el atajo a agendarla.
bool esCapacitacionPendiente(Object error) =>
    error is ApiError && error.code == 'capacitacion_pendiente';

/// Mensaje del alta de oferta. Reescribe los códigos cuyo significado cambia en
/// este camino (aquí `not_owner` habla del PROSPECTO, no de la oferta) y delega
/// el resto en [mensajeDeError].
String mensajeDeErrorNuevaOferta(Object error) {
  if (error is! ApiError) return mensajeDeError(error);
  return switch (error.code) {
    'not_owner' =>
      'Ese prospecto lo trabaja otro asesor, así que no puedes cotizarle. '
          'Pide el traspaso a tu supervisor.',
    'not_found' =>
      'La unidad o el prospecto ya no existe. Refresca el inventario y vuelve '
          'a intentarlo.',
    'missing_id' =>
      'No pudimos identificar la unidad. Cierra la hoja y vuelve a abrirla '
          'desde el inventario.',
    'email_invalido' =>
      'Hace falta un correo válido del prospecto: el link de la oferta se '
          'emite a un correo. Captúralo y vuelve a intentarlo.',
    'scheme_mismatch' =>
      'El plan de pago elegido no aplica a esta unidad. Elige otro o déjalo '
          'sin plan.',
    _ => mensajeDeError(error),
  };
}

/// Folio de una oferta, con el mismo formato que el pipeline: `O-000123` para la
/// unidad y `OP-000123` para una bodega o un estacionamiento.
String folioDeOferta(int idOferta, {bool esProducto = false}) =>
    '${esProducto ? 'OP' : 'O'}-${idOferta.toString().padLeft(6, '0')}';
