import 'package:sozu_agente_app/shared/json.dart';

/// Tipo de cita de la capacitación del agente. `agente-citas` la excluye a
/// propósito: se agenda desde el expediente, no desde la agenda de showroom.
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
      enlaceReunion: j['meet_link'] as String?,
      aviso: j['aviso'] as String?,
    );
  }
}

/// Agenda de citas de showroom y visita del Portal del Agente: qué cupos hay
/// libres y el alta o el cambio de una cita.
///
/// La capacitación (tipo de cita 1) NO pasa por aquí: tiene su propio flujo en
/// el expediente del agente y el servidor la rechaza en esta ruta.
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
}
