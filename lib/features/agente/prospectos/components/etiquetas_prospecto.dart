import 'package:sozu_agente_app/ui/ui.dart';

/// Tonos de las insignias del CRM.
///
/// El catálogo de estados trae un color hexadecimal propio y NO se usa: la
/// insignia del sistema de diseño resuelve fondo y texto como un par con
/// contraste garantizado en claro y en oscuro, y un hex del catálogo pintado a
/// mano rompe ese par (texto oscuro sobre fondo oscuro). Aquí se traduce el
/// SIGNIFICADO del estado a un tono, que es lo que la insignia entiende.

/// Estados que significan avance real del lead.
const _estadosAvance = {
  'negocio_abierto',
  'conectado',
  'programo_cita',
  'asistio_cita',
};

/// Estados que significan trabajo en curso.
const _estadosEnCurso = {
  'nuevo',
  'en_curso',
  'sin_calificar',
  'intento_contacto',
  'compra_futura',
  'tiempo_entrega',
};

/// Estados que cierran o descartan el lead.
const _estadosDescarte = {
  'fuera_presupuesto',
  'sin_respuesta_7',
  'registro_error',
  'proveedor',
  'fuera_area',
  'asesor_inmobiliario',
};

/// Tono de la insignia de un estado de lead, por su clave del catálogo.
SBadgeTone toneDeEstadoLead(String? clave) {
  if (clave == null) return SBadgeTone.neutral;
  if (_estadosAvance.contains(clave)) return SBadgeTone.positive;
  if (_estadosEnCurso.contains(clave)) return SBadgeTone.pending;
  if (_estadosDescarte.contains(clave)) return SBadgeTone.negative;
  return SBadgeTone.neutral;
}

/// Tono de la insignia de una etapa del pipeline. A partir del apartado pagado
/// la unidad ya es una compra, así que se pinta como algo logrado.
SBadgeTone toneDeEtapa(String clave) => switch (clave) {
  'apartado_pagado' || 'enganche_contrato' || 'ganado' => SBadgeTone.positive,
  'perdido' => SBadgeTone.negative,
  'oferta_enviada' ||
  'negociando' ||
  'cita_programada' ||
  'cita_asistida' => SBadgeTone.pending,
  _ => SBadgeTone.neutral,
};
