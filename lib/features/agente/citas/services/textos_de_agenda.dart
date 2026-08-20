import 'package:sozu_agente_app/shared/api_error.dart';

/// Días de la semana abreviados, empezando en lunes (`DateTime.monday` = 1).
const _diasCortoEs = <String>['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

const _diasLargoEs = <String>[
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const _mesesCortoEs = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

const _mesesLargoEs = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// `YYYY-MM-DD` a `DateTime` anclado al mediodía: el día de la cita es un día de
/// calendario en México y a medianoche cualquier corrimiento lo cambia de fecha.
DateTime? fechaDeAgenda(String? iso) {
  if (iso == null || iso.length < 10) return null;
  return DateTime.tryParse('${iso.substring(0, 10)}T12:00:00');
}

/// `YYYY-MM-DD` de un [DateTime], para mandarlo al servidor.
String isoDeFecha(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-'
    '${fecha.month.toString().padLeft(2, '0')}-'
    '${fecha.day.toString().padLeft(2, '0')}';

/// `2026-08-22` a "vie 22 ago". Fecha inválida a "-".
String etiquetaDiaCorto(String? iso) {
  final d = fechaDeAgenda(iso);
  if (d == null) return '-';
  return '${_diasCortoEs[d.weekday - 1]} ${d.day} '
      '${_mesesCortoEs[d.month - 1]}';
}

/// `2026-08-22` a "viernes 22 de agosto". Fecha inválida a "-".
String etiquetaDiaLargo(String? iso) {
  final d = fechaDeAgenda(iso);
  if (d == null) return '-';
  return '${_diasLargoEs[d.weekday - 1]} ${d.day} de '
      '${_mesesLargoEs[d.month - 1]}';
}

/// Traducción de los códigos de `agente-citas` a un mensaje accionable.
///
/// Los códigos son snake_case en inglés y nunca se muestran tal cual: el agente
/// no puede hacer nada con `config_not_found`.
String mensajeErrorAgenda(Object? error) {
  if (error is! ApiError) {
    return 'Ocurrió un problema inesperado. Intenta de nuevo.';
  }
  return switch (error.code) {
    'network_error' => 'Revisa tu conexión e intenta de nuevo.',
    'unauthorized' => 'Tu sesión expiró. Vuelve a entrar.',
    'not_owner' => 'Este prospecto no está en tu cartera.',
    'no_disponible' => 'Ese horario acaba de ocuparse. Elige otro.',
    'config_not_found' =>
      'Ese horario ya no existe en este desarrollo. Vuelve a elegir la fecha.',
    'schedule_failed' =>
      'No pudimos crear la cita en el calendario. Intenta de nuevo.',
    'fecha_invalida' || 'hora_invalida' => 'Revisa la fecha y el horario.',
    'missing_id_configuracion' ||
    'missing_id_proyecto' => 'Vuelve a elegir la fecha y el horario.',
    'server_misconfigured' =>
      'El agendado está fuera de servicio. Avisa a tu Asesor SOZU.',
    'tipo_cita_no_soportado' =>
      'Este tipo de cita no se agenda desde el portal.',
    'forbidden_role' || 'forbidden' => 'Tu usuario no puede agendar citas.',
    _ => 'No pudimos agendar la cita. Intenta de nuevo.',
  };
}

/// Traducción de los códigos del "Ya acudí" de capacitación.
///
/// Aparte de [mensajeErrorAgenda] porque su mensaje genérico habla de agendar,
/// y aquí no se agendó nada: se reportó una asistencia.
String mensajeErrorAsistencia(Object? error) => switch (error) {
  ApiError(code: 'fecha_invalida') => 'Revisa la fecha en la que acudiste.',
  ApiError(code: 'network_error') => 'Revisa tu conexión e intenta de nuevo.',
  ApiError(code: 'unauthorized') => 'Tu sesión expiró. Vuelve a entrar.',
  _ => 'No pudimos reportar tu asistencia. Intenta de nuevo.',
};
