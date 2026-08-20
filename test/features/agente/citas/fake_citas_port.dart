import 'package:sozu_agente_app/features/agente/citas/ports/citas_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Doble de [CitasPort] con datos fijos en memoria: sin red, sin Supabase.
/// Se inyecta con `citasPortProvider.overrideWithValue`.
class FakeCitasPort implements CitasPort {
  /// Fallo forzado de la PRÓXIMA operación; se consume al usarse.
  ApiError? proximoFallo;

  /// Nombres de los métodos llamados, en orden.
  final List<String> log = [];

  /// Última solicitud recibida por [agendar] o [reagendar].
  SolicitudDeCita? ultimaSolicitud;

  /// Payload de disponibilidad en el formato del contrato de `agente-citas`.
  Map<String, dynamic> payloadDisponibilidad = payloadPorDefecto();

  /// Payload de `disponibilidad_capacitacion` por desarrollo. El desarrollo que
  /// no esté aquí responde [payloadCapacitacion].
  final Map<int, Map<String, dynamic>> payloadCapacitacionPorDesarrollo = {};

  /// Payload de capacitación por defecto de cualquier desarrollo.
  Map<String, dynamic> payloadCapacitacion = payloadCapacitacionPorDefecto();

  /// Última solicitud recibida por [agendarCapacitacion].
  SolicitudDeCapacitacion? ultimaCapacitacion;

  /// Última fecha recibida por [reportarAsistencia].
  String? ultimaFechaDeAsistencia;

  /// El servidor ya tenía un reporte de ese día: contesta la OTRA forma de
  /// éxito (`ya_reportada`) en vez de crear uno nuevo.
  bool asistenciaYaReportada = false;

  void _fallarSiToca(String metodo) {
    log.add(metodo);
    final f = proximoFallo;
    proximoFallo = null;
    if (f != null) throw f;
  }

  @override
  Future<List<DiaDisponible>> disponibilidad(int idDesarrollo) async {
    _fallarSiToca('disponibilidad:$idDesarrollo');
    return _dias(payloadDisponibilidad);
  }

  @override
  Future<List<DiaDisponible>> disponibilidadCapacitacion(
    int idDesarrollo, {
    String? fecha,
  }) async {
    _fallarSiToca(
      'disponibilidad_capacitacion:$idDesarrollo'
      '${fecha == null ? '' : '@$fecha'}',
    );
    return _dias(
      payloadCapacitacionPorDesarrollo[idDesarrollo] ?? payloadCapacitacion,
    );
  }

  @override
  Future<CitaAgendada> agendarCapacitacion(
    SolicitudDeCapacitacion solicitud,
  ) async {
    ultimaCapacitacion = solicitud;
    _fallarSiToca('agendar_capacitacion');
    return CitaAgendada.desdeJson(payloadCapacitacionAgendada(solicitud));
  }

  @override
  Future<AsistenciaReportada> reportarAsistencia(String fecha) async {
    ultimaFechaDeAsistencia = fecha;
    _fallarSiToca('reportar_asistencia:$fecha');
    return AsistenciaReportada.desdeJson(
      asistenciaYaReportada
          // Idempotente por día: ya había un reporte de esa fecha.
          ? const {'ok': true, 'ya_reportada': true}
          : const {'ok': true, 'id': 4455, 'pendiente_confirmacion': true},
    );
  }

  List<DiaDisponible> _dias(Map<String, dynamic> payload) {
    final fechas = payload['fechas'];
    if (fechas is! List) return const [];
    return fechas
        .whereType<Map>()
        .map((f) => DiaDisponible.desdeJson(Map<String, dynamic>.from(f)))
        .where((d) => d.fecha.isNotEmpty && d.horarios.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<CitaAgendada> agendar(SolicitudDeCita solicitud) async {
    ultimaSolicitud = solicitud;
    _fallarSiToca('agendar');
    return _resultado(solicitud);
  }

  @override
  Future<CitaAgendada> reagendar(SolicitudDeCita solicitud) async {
    ultimaSolicitud = solicitud;
    _fallarSiToca('reagendar');
    return _resultado(solicitud);
  }

  CitaAgendada _resultado(SolicitudDeCita s) => CitaAgendada(
    idCita: 501,
    fecha: s.fecha,
    horaInicio: '${s.horaInicio}:00',
  );

  /// Respuesta de `agendar_capacitacion`: la fila CRUDA de `reservas_citas`,
  /// con el enlace de Meet dentro de la fila y no en la raíz.
  static Map<String, dynamic> payloadCapacitacionAgendada(
    SolicitudDeCapacitacion s,
  ) => {
    'ok': true,
    'cita': {
      'id': 4321,
      'fecha': s.fecha,
      'hora_inicio': '${s.hora}:00',
      'hora_fin': '${s.hora}:00',
      'ubicacion': 'Presencial',
      'estatus': 'programada',
      'id_estatus_cita': 1,
      'google_meet_link': 'https://meet.google.com/abc-defg-hij',
      'id_configuracion_cita': s.idConfiguracion,
    },
    'meet_link': null,
    'aviso': null,
  };

  /// Un día con dos horarios de la misma agenda de capacitación. `hora` es
  /// entero y la agenda trae responsable, igual que el contrato.
  static Map<String, dynamic> payloadCapacitacionPorDefecto() => {
    'fechas': [
      {
        'fecha': '2026-09-03',
        'slots': [
          {
            'hora': 11,
            'hora_label': '11:00',
            'id_configuracion_cita': 42,
            'config_nombre': 'Capacitación PV',
            'responsable': 'Mora Salas',
            'id_tipo_cita': 1,
            'duracion_minutos': 60,
          },
          {
            'hora': 13,
            'hora_label': '13:00',
            'id_configuracion_cita': 42,
            'config_nombre': 'Capacitación PV',
            'responsable': 'Mora Salas',
            'id_tipo_cita': 1,
            'duracion_minutos': 60,
          },
        ],
      },
    ],
    'slots': null,
  };

  /// Dos días con cupo; el primero con dos agendas distintas a la misma hora,
  /// que es el caso que obliga a mandar `id_configuracion_cita`.
  static Map<String, dynamic> payloadPorDefecto() => {
    'fechas': [
      {
        'fecha': '2026-08-21',
        'slots': [
          {
            'hora': 10,
            'hora_label': '10:00',
            'id_configuracion_cita': 7,
            'config_nombre': 'Showroom Reforma',
            'responsable': 'Ana Torres',
            'id_tipo_cita': 2,
            'duracion_minutos': 60,
          },
          {
            'hora': 10,
            'hora_label': '10:00',
            'id_configuracion_cita': 9,
            'config_nombre': 'Visita en obra',
            'responsable': 'Luis Ríos',
            'id_tipo_cita': 5,
          },
        ],
      },
      {
        'fecha': '2026-08-24',
        'slots': [
          // Sin `hora_label`: el puerto lo arma con la hora.
          {'hora': 9, 'id_configuracion_cita': 7},
        ],
      },
      // Día sin cupos: no debe llegar a la pantalla.
      {'fecha': '2026-08-25', 'slots': <Map<String, dynamic>>[]},
    ],
    'slots': null,
  };
}
