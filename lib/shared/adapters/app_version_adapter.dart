import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/shared/adapters/anon_function.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/shared/ports/app_version_port.dart';

/// Implementacion actual de [AppVersionPort] sobre la edge function
/// `agente-app-version`: la unica frontera donde se conocen sus tipos.
class AppVersionAdapter implements AppVersionPort {
  /// Version minima/sugerida y URLs de tienda.
  ///
  /// Va por [invokeAnonFunction] y NO por `functions.invoke`: esta llamada corre
  /// sin sesion (el gate decide antes del login).
  ///
  /// `conAuthorization: true` NO es opcional aqui. Esta funcion conserva
  /// `verify_jwt = true` —solo se apaga en las de acceso— y el gateway de
  /// PRODUCCION responde `401 UNAUTHORIZED_NO_AUTH_HEADER` cuando la llave viaja
  /// unicamente en `apikey`. Como el gate traga cualquier error y degrada a "no
  /// gatear", el sintoma no seria una pantalla roja sino que el aviso de version
  /// nueva NUNCA aparece. Verificado con curl contra el proyecto de produccion.
  @override
  Future<AppVersionInfo> version() async {
    final AnonFunctionResponse res;
    try {
      res = await invokeAnonFunction(
        'agente-app-version',
        conAuthorization: true,
      );
    } catch (_) {
      throw ApiError(0, 'network_error');
    }
    if (res.status < 200 || res.status >= 300) {
      throw ApiError(res.status, '${res.body['error'] ?? 'internal_error'}');
    }
    return AppVersionInfo.fromJson(res.body);
  }
}
