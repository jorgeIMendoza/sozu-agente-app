import 'dart:convert';
import 'dart:typed_data';

import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/shared/adapters/edge_function.dart';

/// Implementación de [ComisionesPort] sobre la Edge Function
/// `agente-comisiones`.
class ComisionesAdapter implements ComisionesPort {
  /// `id_persona` del agente que un administrador está viendo; null = el propio.
  final int? impersonate;

  final EdgeFunctions _fn;

  ComisionesAdapter({this.impersonate})
    : _fn = EdgeFunctions(impersonate: impersonate);

  @override
  Future<ComisionesAgente> cargarComisiones() async => ComisionesAgente
      .desdeJson(await _fn.call('agente-comisiones', body: {'action': 'lista'}));

  @override
  Future<String?> subirFactura({
    required int idCuentaCobranza,
    required String nombreArchivo,
    required Uint8List archivo,
  }) async {
    final res = await _fn.call(
      'agente-comisiones',
      body: {
        'action': 'subir_factura',
        'id_cuenta_cobranza': idCuentaCobranza,
        // El archivo viaja en base64 dentro del JSON: la función no acepta
        // multipart, y el tope de 10 MB del backend deja margen de sobra para
        // una factura.
        'archivo_base64': base64Encode(archivo),
        'nombre_archivo': nombreArchivo,
      },
    );
    return res['factura_url'] as String?;
  }
}
