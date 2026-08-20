import 'package:sozu_agente_app/features/agente/citas/ports/citas_port.dart';
import 'package:sozu_agente_app/shared/adapters/edge_function.dart';

/// Implementación de [CitasPort] sobre la Edge Function `agente-citas`
/// (`disponibilidad`, `agendar`, `reagendar`, y las tres de capacitación:
/// `disponibilidad_capacitacion`, `agendar_capacitacion` y
/// `reportar_asistencia`).
///
/// La otra acción de esa function, `cancelar`, la sirve `InicioAdapter`: la
/// baja se dispara desde el detalle de cita de Inicio y ahí ya está el puerto.
class CitasAdapter implements CitasPort {
  /// `id_persona` del agente que un admin está viendo; null = su propia sesión.
  final int? impersonate;

  final EdgeFunctions _fn;

  CitasAdapter({this.impersonate})
    : _fn = EdgeFunctions(impersonate: impersonate);

  static const _funcion = 'agente-citas';

  @override
  Future<List<DiaDisponible>> disponibilidad(int idDesarrollo) async => _dias(
    await _fn.call(
      _funcion,
      body: {'action': 'disponibilidad', 'id_proyecto': idDesarrollo},
    ),
  );

  @override
  Future<CitaAgendada> agendar(SolicitudDeCita solicitud) =>
      _escribir('agendar', solicitud);

  @override
  Future<CitaAgendada> reagendar(SolicitudDeCita solicitud) =>
      _escribir('reagendar', solicitud);

  @override
  Future<List<DiaDisponible>> disponibilidadCapacitacion(
    int idDesarrollo, {
    String? fecha,
  }) async => _dias(
    await _fn.call(
      _funcion,
      body: {
        'action': 'disponibilidad_capacitacion',
        'id_proyecto': idDesarrollo,
        'id_tipo_cita': kTipoCitaCapacitacion,
        if (fecha != null) 'fecha': fecha,
      },
    ),
  );

  @override
  Future<CitaAgendada> agendarCapacitacion(
    SolicitudDeCapacitacion solicitud,
  ) async => CitaAgendada.desdeJson(
    await _fn.call(_funcion, body: cuerpoAgendarCapacitacion(solicitud)),
  );

  @override
  Future<AsistenciaReportada> reportarAsistencia(String fecha) async =>
      AsistenciaReportada.desdeJson(
        await _fn.call(
          _funcion,
          body: {'action': 'reportar_asistencia', 'fecha': fecha},
        ),
      );

  Future<CitaAgendada> _escribir(String accion, SolicitudDeCita s) async =>
      CitaAgendada.desdeJson(
        await _fn.call(
          _funcion,
          body: {
            'action': accion,
            'id_persona_prospecto': s.idPersonaProspecto,
            'id_proyecto': s.idDesarrollo,
            'fecha': s.fecha,
            'hora_inicio': s.horaInicio,
            'id_configuracion_cita': s.idConfiguracion,
            if (s.notas != null && s.notas!.trim().isNotEmpty)
              'notas': s.notas!.trim(),
          },
        ),
      );

  /// Los días con cupo de una respuesta de disponibilidad. Un día sin cupos no
  /// llega a la pantalla: no hay nada que elegir en él.
  List<DiaDisponible> _dias(Map<String, dynamic> res) => listaDe(res['fechas'])
      .map(DiaDisponible.desdeJson)
      .where((d) => d.fecha.isNotEmpty && d.horarios.isNotEmpty)
      .toList(growable: false);
}

/// Cuerpo de `agendar_capacitacion`.
///
/// Público a propósito: la prueba fija aquí que NO viaja la identidad del
/// agente (`id_persona`, `email`, `auth_user_id`), que el servidor deriva del
/// JWT.
Map<String, dynamic> cuerpoAgendarCapacitacion(SolicitudDeCapacitacion s) => {
  'action': 'agendar_capacitacion',
  'fecha': s.fecha,
  'hora': s.hora,
  'id_configuracion': s.idConfiguracion,
  if (s.idDesarrollo != null) 'id_proyecto': s.idDesarrollo,
};
