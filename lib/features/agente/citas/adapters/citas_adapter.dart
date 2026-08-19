import 'package:sozu_agente_app/features/agente/citas/ports/citas_port.dart';
import 'package:sozu_agente_app/shared/adapters/edge_function.dart';

/// Implementación de [CitasPort] sobre la Edge Function `agente-citas`
/// (acciones `disponibilidad`, `agendar` y `reagendar`).
///
/// La cuarta acción de esa function, `cancelar`, la sirve `InicioAdapter`: la
/// baja se dispara desde el detalle de cita de Inicio y ahí ya está el puerto.
class CitasAdapter implements CitasPort {
  /// `id_persona` del agente que un admin está viendo; null = su propia sesión.
  final int? impersonate;

  final EdgeFunctions _fn;

  CitasAdapter({this.impersonate})
    : _fn = EdgeFunctions(impersonate: impersonate);

  static const _funcion = 'agente-citas';

  @override
  Future<List<DiaDisponible>> disponibilidad(int idDesarrollo) async {
    final res = await _fn.call(
      _funcion,
      body: {'action': 'disponibilidad', 'id_proyecto': idDesarrollo},
    );
    return listaDe(res['fechas'])
        .map(DiaDisponible.desdeJson)
        .where((d) => d.fecha.isNotEmpty && d.horarios.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<CitaAgendada> agendar(SolicitudDeCita solicitud) =>
      _escribir('agendar', solicitud);

  @override
  Future<CitaAgendada> reagendar(SolicitudDeCita solicitud) =>
      _escribir('reagendar', solicitud);

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
}
