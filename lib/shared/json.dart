/// Lectura tolerante de los JSON que devuelve el backend.
///
/// Vive aparte del llamador (`shared/adapters/edge_function.dart`) a propósito:
/// los modelos de `features/*/ports/` necesitan estos helpers para su `fromJson`
/// y un puerto NO puede importar nada que nombre la tecnología. El puerto habla
/// el lenguaje del negocio; el adaptador es el único que sabe qué hay detrás.
///
/// Todos degradan en vez de lanzar: el backend responde payload vacío bien
/// formado cuando una tabla todavía no existe, y la pantalla debe pintarse igual.
library;

/// Lista de mapas. Clave ausente o de otro tipo ⇒ lista vacía.
List<Map<String, dynamic>> listaDe(Object? valor) {
  if (valor is! List) return const [];
  return valor
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}

/// Mapa anidado. Clave ausente ⇒ mapa vacío.
Map<String, dynamic> mapaDe(Object? valor) =>
    valor is Map ? Map<String, dynamic>.from(valor) : const {};

/// Número tolerante: Postgres manda `numeric` como String y `int` como int.
double numDe(Object? valor) {
  if (valor is num) return valor.toDouble();
  return double.tryParse('${valor ?? ''}') ?? 0;
}

/// Entero tolerante. Devuelve null cuando no hay valor, para distinguir
/// "no vino" de "vino cero": la diferencia entre "sin id" y "id 0".
int? intDe(Object? valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse('${valor ?? ''}');
}
