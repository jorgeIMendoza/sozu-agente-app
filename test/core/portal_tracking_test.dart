import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/core/portal_tracking.dart';

/// Lo que fija este archivo son las DOS cadenas de las que depende que el uso
/// del app aparezca donde debe en "Uso por portal" (Alta Direccion).
///
/// Este archivo llego copiado del app del cliente y las dos venian con el valor
/// del cliente: las sesiones del agente se registraban en el portal `clientes` y
/// su user_agent sintetico decia `SozuClienteApp`, asi que el tablero las
/// contaba como "App clientes". Un fallo silencioso: nada truena, solo que los
/// numeros de otro portal salen inflados y los propios no existen.
void main() {
  test('las sesiones se registran en el portal de AGENTES', () {
    expect(PortalTracking.portal, 'agentes');
    // 'clientes' es un valor valido del CHECK de portal_sesiones, asi que la BD
    // aceptaria la fila sin protestar. Por eso lo fija un test y no el esquema.
    expect(PortalTracking.portal, isNot('clientes'));
  });

  test('el token del user_agent es el que el clasificador SQL busca', () {
    // El tablero clasifica con ILIKE '%SozuAgenteApp/%' -> "App agentes".
    // Renombrarlo aqui sin tocar el SQL manda las sesiones a "Otro".
    expect(PortalTracking.appToken, 'SozuAgenteApp');
    expect(PortalTracking.appToken, isNot(contains('Cliente')));
  });
}
