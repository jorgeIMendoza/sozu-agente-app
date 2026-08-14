import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Llamada cruda a una Edge Function SIN sesion, para las pantallas de acceso
/// (recuperar contrasena, reenviar confirmacion). Vive en la capa de
/// adaptadores porque conoce el backend (URL del proyecto, llave anonima,
/// forma de la respuesta); los puertos y la UI no la ven.

/// Respuesta cruda de una Edge Function llamada sin sesion.
typedef AnonFunctionResponse = ({int status, Map<String, dynamic> body});

/// Invoca la Edge Function [fn] mandando la llave anonima UNICAMENTE en el
/// header `apikey`.
///
/// No usa `functions.invoke` a proposito, por dos motivos:
///  1. `invoke` manda la llave anonima en `apikey` Y en `Authorization`. El
///     gateway nuevo de Supabase (llaves `sb_`) compara los dos headers y
///     responde 401 "Conflicting API keys" ANTES de ejecutar la funcion.
///  2. Las funciones de acceso solo entran en su "modo publico" (self-service,
///     anti-enumeracion de correos) cuando NO reciben `Authorization`: con ese
///     header intentan resolver un usuario autenticado y rechazan la peticion.
///
/// [conAuthorization] agrega `Authorization: Bearer <llave anonima>`, y es
/// OBLIGATORIO para las funciones que conservan `verify_jwt = true`. Verificado
/// contra produccion (Supabase Cloud): con la llave solo en `apikey`, el gateway
/// responde `401 UNAUTHORIZED_NO_AUTH_HEADER` antes de ejecutar la funcion. Las
/// unicas que pasan sin `Authorization` son las que tienen el verify_jwt
/// apagado (reset-user-password y compania), y esas ADEMAS lo necesitan
/// ausente para entrar en su modo publico. El gateway self-hosted de desarrollo
/// es mas permisivo y acepta las dos formas: por eso la diferencia solo se ve
/// en produccion.
///
/// Nunca lanza por status != 2xx: devuelve status + cuerpo para que decida el
/// llamador (el adaptador traduce a `AuthError`/`ApiError` segun su contrato).
/// Si no hay red, propaga la excepcion de [http.post].
///
/// [client] solo lo usan los tests, para fijar que headers sale cada llamada
/// sin tocar red; en produccion siempre es null.
Future<AnonFunctionResponse> invokeAnonFunction(
  String fn, {
  Map<String, dynamic> body = const {},
  bool conAuthorization = false,
  http.Client? client,
}) async {
  final baseUrl = (dotenv.env['SUPABASE_URL'] ?? '').replaceAll(
    RegExp(r'/+$'),
    '',
  );
  final llave = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  final uri = Uri.parse('$baseUrl/functions/v1/$fn');
  final headers = {
    'Content-Type': 'application/json',
    'apikey': llave,
    // Repetir la llave en Authorization rompe el modo publico de las funciones
    // de acceso, pero es lo unico que satisface al gateway cuando la funcion
    // conserva verify_jwt (ver doc arriba): lo decide cada llamador.
    if (conAuthorization) 'Authorization': 'Bearer $llave',
  };
  final payload = jsonEncode(body);
  final res = client == null
      ? await http.post(uri, headers: headers, body: payload)
      : await client.post(uri, headers: headers, body: payload);
  var parsed = const <String, dynamic>{};
  try {
    final decoded = jsonDecode(res.body);
    if (decoded is Map) parsed = Map<String, dynamic>.from(decoded);
  } catch (_) {
    // Cuerpo no-JSON (p.ej. HTML de error del gateway): se ignora.
  }
  return (status: res.statusCode, body: parsed);
}
