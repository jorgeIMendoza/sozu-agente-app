import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/shared/adapters/edge_function.dart';

/// Implementación de [SesionPort] sobre la Edge Function `agente-sesion`.
class SesionAdapter implements SesionPort {
  final EdgeFunctions _fn;

  SesionAdapter({int? impersonate})
    : _fn = EdgeFunctions(impersonate: impersonate);

  @override
  Future<SesionAgente> cargar() async =>
      SesionAgente.fromJson(await _fn.call('agente-sesion'));
}
