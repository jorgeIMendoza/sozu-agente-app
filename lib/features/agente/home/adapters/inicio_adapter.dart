import 'package:sozu_agente_app/features/agente/home/ports/inicio_port.dart';
import 'package:sozu_agente_app/shared/adapters/edge_function.dart';

/// Implementación de [InicioPort] sobre las Edge Functions `agente-inicio`
/// (tablero) y `agente-citas` (cancelación).
///
/// Son dos funciones y no una porque la lectura del tablero es idempotente y la
/// cancelación no: mezclarlas obligaría a `agente-inicio` a aceptar acciones de
/// escritura y a la pantalla a distinguirlas en el mismo payload.
class InicioAdapter implements InicioPort {
  /// `id_persona` del agente que un administrador está viendo; null = el propio.
  final int? impersonate;

  final EdgeFunctions _fn;

  InicioAdapter({this.impersonate})
    : _fn = EdgeFunctions(impersonate: impersonate);

  @override
  Future<ResumenInicio> cargarResumen() async =>
      ResumenInicio.desdeJson(await _fn.call('agente-inicio'));

  @override
  Future<void> cancelarCita(int idCita) async {
    await _fn.call(
      'agente-citas',
      body: {'action': 'cancelar', 'id_cita': idCita},
    );
  }
}
