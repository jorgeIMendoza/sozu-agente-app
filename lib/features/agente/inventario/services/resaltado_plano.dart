/// Elección de la región del plano de nivel que corresponde a una unidad.
///
/// El número con el que se capturó el plano y el de la propiedad casi nunca son
/// el mismo texto: el plano dice "3", la propiedad "1203", el nivel es 12 y el
/// departamento "03". Este archivo concentra esa conciliación (espejo del
/// resaltado de `PropertyFloorPlanButton` en el panel) para poder probarla sin
/// pintar nada: si falla, se resalta el departamento del vecino.
library;

import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';

/// Región que hay que resaltar, o null si ninguna corresponde a la unidad
/// (plano capturado sin ella).
///
/// [numeroDepa] es el número dentro del nivel y [numeroUnidad] el completo de la
/// propiedad. Se prueban las dos formas, sus dígitos y sus versiones sin ceros a
/// la izquierda; a igual coincidencia gana el polígono de mayor área, que es el
/// departamento y no una marca chica encima de él.
RegionPlano? regionDeUnidad(
  List<RegionPlano> regiones, {
  required String numeroDepa,
  String? numeroUnidad,
}) {
  if (regiones.isEmpty) return null;

  final depa = numeroDepa.trim();
  final depaDigitos = _digitos(depa);
  final unidad = (numeroUnidad ?? '').trim();
  final unidadDigitos = _digitos(unidad);

  // Número inferido del completo: si termina con el del departamento, ese; si
  // no, sus dos últimos dígitos ("1203" -> "03").
  final inferido = unidadDigitos.isEmpty
      ? ''
      : (depaDigitos.isNotEmpty && unidadDigitos.endsWith(depaDigitos)
            ? depaDigitos
            : (unidadDigitos.length > 2
                  ? unidadDigitos.substring(unidadDigitos.length - 2)
                  : unidadDigitos));

  final exactos = <String>{
    depa,
    depaDigitos,
    inferido,
    unidad,
    unidadDigitos,
    _aDosDigitos(depa),
    _aDosDigitos(depaDigitos),
    _aDosDigitos(inferido),
  }..removeWhere((s) => s.isEmpty);
  if (exactos.isEmpty) return null;

  final normalizados = exactos.map(_sinCeros).toSet();

  RegionPlano? mejor;
  var mejorPuntaje = 0;
  var mejorArea = 0.0;

  for (final r in regiones) {
    final crudo = r.unidad.trim();
    final digitos = _digitos(crudo);
    var puntaje = 0;
    if (exactos.contains(crudo)) puntaje = 300;
    if (digitos.isNotEmpty && exactos.contains(digitos) && puntaje < 285) {
      puntaje = 285;
    }
    if (normalizados.contains(_sinCeros(crudo)) && puntaje < 270) puntaje = 270;
    if (puntaje == 0) continue;

    final area = areaPoligono(r.poligono);
    if (puntaje > mejorPuntaje || (puntaje == mejorPuntaje && area > mejorArea)) {
      mejor = r;
      mejorPuntaje = puntaje;
      mejorArea = area;
    }
  }
  return mejor;
}

/// Área del polígono por la fórmula del cordón (shoelace), en las unidades de
/// las coordenadas. Solo se usa para comparar tamaños entre regiones.
double areaPoligono(List<List<double>> poligono) {
  if (poligono.length < 3) return 0;
  var acumulado = 0.0;
  for (var i = 0; i < poligono.length; i++) {
    final a = poligono[i];
    final b = poligono[(i + 1) % poligono.length];
    if (a.length < 2 || b.length < 2) continue;
    acumulado += a[0] * b[1] - b[0] * a[1];
  }
  return (acumulado / 2).abs();
}

String _digitos(String v) => v.replaceAll(RegExp(r'\D'), '');

/// Sin ceros a la izquierda ("03" -> "3"); "000" -> "0".
String _sinCeros(String v) {
  final s = v.trim().replaceFirst(RegExp(r'^0+'), '');
  return s.isEmpty ? '0' : s;
}

/// Un dígito suelto a dos posiciones ("3" -> "03"); vacío si no aplica, para no
/// meter ruido en el conjunto de coincidencias.
String _aDosDigitos(String v) {
  final d = _digitos(v);
  return d.length == 1 ? d.padLeft(2, '0') : '';
}
