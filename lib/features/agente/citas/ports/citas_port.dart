import 'package:sozu_agente_app/shared/json.dart';

/// Tipo de cita de la capacitación del agente. Va por su propia agenda: el
/// asistente es el AGENTE y no un prospecto.
const int kTipoCitaCapacitacion = 1;

/// Horario libre del showroom: la hora y de qué agenda sale.
///
/// [idConfiguracion] es lo que identifica el cupo al agendar; la hora sola no
/// basta porque un desarrollo puede tener varias agendas a la misma hora.
class HorarioDisponible {
  final int hora;

  /// `HH:00`, tal como lo manda el servidor. Es también la `hora_inicio` que
  /// espera el agendado.
  final String etiqueta;

  final int idConfiguracion;

  /// Nombre de la agenda ("Showroom Reforma"); null cuando no se le puso.
  final String? configuracion;

  final String? responsable;

  /// 2 (showroom) o 5 (visita). Informativo: el agendado lo deriva el servidor.
  final int? idTipoCita;

  final int? duracionMinutos;

  const HorarioDisponible({
    required this.hora,
    required this.etiqueta,
    required this.idConfiguracion,
    this.configuracion,
    this.responsable,
    this.idTipoCita,
    this.duracionMinutos,
  });

  factory HorarioDisponible.desdeJson(Map<String, dynamic> j) {
    final hora = intDe(j['hora']) ?? 0;
    final etiqueta = j['hora_label'] as String?;
    return HorarioDisponible(
      hora: hora,
      etiqueta: etiqueta == null || etiqueta.isEmpty
          ? '${hora.toString().padLeft(2, '0')}:00'
          : etiqueta,
      idConfiguracion: intDe(j['id_configuracion_cita']) ?? 0,
      configuracion: j['config_nombre'] as String?,
      responsable: j['responsable'] as String?,
      idTipoCita: intDe(j['id_tipo_cita']),
      duracionMinutos: intDe(j['duracion_minutos']),
    );
  }
}

/// Día con al menos un horario libre.
class DiaDisponible {
  /// `YYYY-MM-DD`. Llega como texto y NO como fecha: es un día de calendario en
  /// México, y convertirlo a `DateTime` local lo correría de día para quien
  /// tenga el dispositivo en otra zona.
  final String fecha;

  final List<HorarioDisponible> horarios;

  const DiaDisponible({required this.fecha, this.horarios = const []});

  factory DiaDisponible.desdeJson(Map<String, dynamic> j) => DiaDisponible(
    fecha: (j['fecha'] ?? '') as String,
    horarios: listaDe(
      j['slots'],
    ).map(HorarioDisponible.desdeJson).toList(growable: false),
  );
}

/// Lo que el agente eligió para agendar: a quién, a dónde y cuándo.
///
/// No lleva tipo de cita: el servidor lo lee de la configuración elegida, y un
/// tipo mandado desde el app crearía citas fuera de flujo.
class SolicitudDeCita {
  final int idPersonaProspecto;
  final int idDesarrollo;

  /// `YYYY-MM-DD`.
  final String fecha;

  /// `HH:MM`.
  final String horaInicio;

  final int idConfiguracion;

  final String? notas;

  const SolicitudDeCita({
    required this.idPersonaProspecto,
    required this.idDesarrollo,
    required this.fecha,
    required this.horaInicio,
    required this.idConfiguracion,
    this.notas,
  });
}

/// Cita ya escrita en la agenda, como la devuelve el servidor.
class CitaAgendada {
  final int? idCita;
  final String? fecha;
  final String? horaInicio;

  /// Enlace de la videollamada que creó el calendario; null en citas
  /// presenciales sin Meet.
  final String? enlaceReunion;

  /// Advertencia en lenguaje del usuario cuando la cita quedó pero algo del
  /// calendario no (p. ej. el prospecto no recibió la invitación).
  final String? aviso;

  const CitaAgendada({
    this.idCita,
    this.fecha,
    this.horaInicio,
    this.enlaceReunion,
    this.aviso,
  });

  factory CitaAgendada.desdeJson(Map<String, dynamic> j) {
    final cita = mapaDe(j['cita']);
    return CitaAgendada(
      idCita: intDe(cita['id']),
      fecha: cita['fecha'] as String?,
      horaInicio: cita['hora_inicio'] as String?,
      // La capacitación devuelve la fila cruda de la cita: cuando el enlace no
      // viene en la raíz, está en la propia fila.
      enlaceReunion:
          (j['meet_link'] as String?) ?? (cita['google_meet_link'] as String?),
      aviso: j['aviso'] as String?,
    );
  }
}

/// Lo que el agente eligió para su capacitación: el cupo y el desarrollo del
/// que salió.
///
/// No lleva a quién se capacita: el servidor lo deriva del JWT. Mandar la
/// identidad sería la vía para agendarle a otro agente.
class SolicitudDeCapacitacion {
  /// `YYYY-MM-DD`.
  final String fecha;

  /// `HH:MM`.
  final String hora;

  final int idConfiguracion;

  /// Desarrollo al que cuelga la configuración; opcional para el servidor.
  final int? idDesarrollo;

  const SolicitudDeCapacitacion({
    required this.fecha,
    required this.hora,
    required this.idConfiguracion,
    this.idDesarrollo,
  });
}

/// Resultado del "Ya acudí".
///
/// El servidor tiene DOS formas de éxito y son excluyentes: el reporte nuevo
/// ([idCita] + [pendienteDeConfirmacion]) y el que ya existía de ese día
/// ([yaReportada]). Es idempotente por día.
class AsistenciaReportada {
  /// Id del reporte recién creado; null cuando ya había uno del mismo día.
  final int? idCita;

  /// Ya había un reporte de esa fecha: el servidor no duplicó nada.
  final bool yaReportada;

  /// Falta que un administrador la confirme para que cuente como capacitación.
  final bool pendienteDeConfirmacion;

  const AsistenciaReportada({
    this.idCita,
    this.yaReportada = false,
    this.pendienteDeConfirmacion = false,
  });

  factory AsistenciaReportada.desdeJson(Map<String, dynamic> j) =>
      AsistenciaReportada(
        idCita: intDe(j['id']),
        yaReportada: j['ya_reportada'] == true,
        pendienteDeConfirmacion: j['pendiente_confirmacion'] == true,
      );
}

/// Agenda de citas del Portal del Agente: qué cupos hay libres y el alta o el
/// cambio de una cita, tanto de showroom y visita (el prospecto es el asistente)
/// como de capacitación (el asistente es el propio agente).
///
/// La instancia queda atada al agente que se está viendo (el propio, o el que
/// impersona un administrador), así que ningún método recibe ese destinatario.
/// Todos lanzan `ApiError` con el código de negocio del servidor (`not_owner`,
/// `no_disponible`, `config_not_found`…).
abstract interface class CitasPort {
  /// Días con horarios libres del desarrollo, del día de hoy en adelante.
  Future<List<DiaDisponible>> disponibilidad(int idDesarrollo);

  /// Agenda una cita nueva.
  Future<CitaAgendada> agendar(SolicitudDeCita solicitud);

  /// Mueve la cita activa del prospecto en ese desarrollo al nuevo cupo. El
  /// servidor decide si crea o actualiza, igual que el portal web.
  Future<CitaAgendada> reagendar(SolicitudDeCita solicitud);

  /// Días con cupo de capacitación del desarrollo. [fecha] (`YYYY-MM-DD`)
  /// recorta la respuesta a ese día.
  Future<List<DiaDisponible>> disponibilidadCapacitacion(
    int idDesarrollo, {
    String? fecha,
  });

  /// Agenda la capacitación del agente en el cupo elegido.
  ///
  /// Mueve la cita que ya tenía cuando el cupo nuevo es de la MISMA
  /// configuración; con otra configuración el servidor deja las dos, igual que
  /// el portal web.
  Future<CitaAgendada> agendarCapacitacion(SolicitudDeCapacitacion solicitud);

  /// Reporta que el agente ya acudió a capacitación en [fecha] (`YYYY-MM-DD`).
  Future<AsistenciaReportada> reportarAsistencia(String fecha);
}
