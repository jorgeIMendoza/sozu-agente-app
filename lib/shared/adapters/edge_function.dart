import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_agente_app/shared/api_error.dart';

/// Llamador único de Edge Functions con el JWT del usuario.
///
/// Existe para que los ocho adaptadores del portal (`sesion`, `inicio`,
/// `inventario`, `prospectos`, `pipeline`, `comisiones`, `perfil`, `citas`) no
/// copien el mismo bloque de `functions.invoke` + traducción de errores: en el
/// app del cliente ese bloque está repetido en cada adapter y ya se
/// desincronizó una vez (un adapter tragaba el código de error y devolvía
/// `internal_error` para todo).
///
/// Nunca manda la anon key en `Authorization`: eso es para las funciones
/// públicas pre-login y va por `invokeAnonFunction` (shared/adapters/anon_function.dart).
class EdgeFunctions {
  /// `id_persona` del agente que un admin está viendo; null = su propia sesión.
  final int? impersonate;

  const EdgeFunctions({this.impersonate});

  /// Getter perezoso a propósito: construir el llamador no toca el singleton de
  /// Supabase, así el provider puede crearlo antes de `Supabase.initialize`.
  SupabaseClient get _sb => Supabase.instance.client;

  Map<String, String>? get _headers =>
      impersonate != null ? {'x-impersonate-id-persona': '$impersonate'} : null;

  /// Invoca `fn` y devuelve su objeto JSON. Cualquier fallo sale como [ApiError]
  /// con el código snake_case que manda el backend (`forbidden_role`,
  /// `not_owner`, …): las pantallas deciden el mensaje, el adapter no inventa.
  Future<Map<String, dynamic>> call(
    String fn, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final res = await _sb.functions.invoke(
        fn,
        body: body ?? const {},
        headers: _headers,
      );
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw ApiError(500, 'empty_response');
    } on FunctionException catch (e) {
      var code = 'internal_error';
      final details = e.details;
      if (details is Map && details['error'] != null) {
        code = details['error'].toString();
      }
      throw ApiError(e.status, code);
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError(0, 'network_error');
    }
  }
}

/// Lee una lista de mapas de una respuesta de Edge Function. Tolera la clave
/// ausente y devuelve lista vacía: el backend degrada a payload vacío cuando una
/// tabla todavía no existe, y la pantalla debe pintarse igual.
List<Map<String, dynamic>> listaDe(Object? valor) {
  if (valor is! List) return const [];
  return valor
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}

/// Lee un mapa anidado. Devuelve mapa vacío si falta, por la misma razón.
Map<String, dynamic> mapaDe(Object? valor) =>
    valor is Map ? Map<String, dynamic>.from(valor) : const {};

/// Número tolerante: el backend manda `numeric` de Postgres como String.
double numDe(Object? valor) {
  if (valor is num) return valor.toDouble();
  return double.tryParse('${valor ?? ''}') ?? 0;
}

int? intDe(Object? valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse('${valor ?? ''}');
}
