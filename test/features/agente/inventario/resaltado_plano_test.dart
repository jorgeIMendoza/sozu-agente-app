import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/features/agente/inventario/services/resaltado_plano.dart';

/// Conciliación del número de unidad con el del plano. Es lo que decide qué
/// departamento se resalta: si falla, al cliente se le señala el del vecino.
void main() {
  RegionPlano region(String unidad, List<List<double>> poligono) =>
      RegionPlano(unidad: unidad, poligono: poligono);

  final cuadradoChico = [
    [0.0, 0.0],
    [10.0, 0.0],
    [10.0, 10.0],
    [0.0, 10.0],
  ];
  final cuadradoGrande = [
    [0.0, 0.0],
    [40.0, 0.0],
    [40.0, 40.0],
    [0.0, 40.0],
  ];

  test('coincidencia exacta del número de departamento', () {
    final elegida = regionDeUnidad(
      [region('01', cuadradoChico), region('03', cuadradoGrande)],
      numeroDepa: '03',
      numeroUnidad: '1203',
    );
    expect(elegida?.unidad, '03');
  });

  test('el plano sin ceros a la izquierda también casa', () {
    final elegida = regionDeUnidad(
      [region('3', cuadradoChico)],
      numeroDepa: '03',
      numeroUnidad: '1203',
    );
    expect(elegida?.unidad, '3');
  });

  test('el plano capturado con el número completo casa', () {
    final elegida = regionDeUnidad(
      [region('1203', cuadradoChico), region('1204', cuadradoGrande)],
      numeroDepa: '03',
      numeroUnidad: '1203',
    );
    expect(elegida?.unidad, '1203');
  });

  test('a igual coincidencia gana el polígono más grande', () {
    final elegida = regionDeUnidad(
      [region('03', cuadradoChico), region('03', cuadradoGrande)],
      numeroDepa: '03',
    );
    expect(areaPoligono(elegida!.poligono), areaPoligono(cuadradoGrande));
  });

  test('una unidad que el plano no lista no resalta nada', () {
    final elegida = regionDeUnidad(
      [region('01', cuadradoChico), region('02', cuadradoGrande)],
      numeroDepa: '07',
      numeroUnidad: '1207',
    );
    expect(elegida, isNull);
  });

  test('sin regiones ni número no revienta', () {
    expect(regionDeUnidad(const [], numeroDepa: '03'), isNull);
    expect(
      regionDeUnidad([region('03', cuadradoChico)], numeroDepa: ''),
      isNull,
    );
  });

  test('el área de un polígono degenerado es cero', () {
    expect(areaPoligono(const []), 0);
    expect(
      areaPoligono(const [
        [0, 0],
        [1, 1],
      ]),
      0,
    );
  });
}
