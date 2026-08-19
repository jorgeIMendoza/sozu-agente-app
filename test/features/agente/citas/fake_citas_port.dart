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

  void _fallarSiToca(String metodo) {
    log.add(metodo);
    final f = proximoFallo;
    proximoFallo = null;
    if (f != null) throw f;
  }

  @override
  Future<List<DiaDisponible>> disponibilidad(int idDesarrollo) async {
    _fallarSiToca('disponibilidad:$idDesarrollo');
    final fechas = payloadDisponibilidad['fechas'];
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
