import 'package:sozu_agente_app/shared/ports/telemetria_port.dart';

/// Doble de [TelemetriaPort] que solo apunta lo que se le manda: sin red y sin
/// Supabase. Fija los identificadores que comparte con el portal web.
class FakeTelemetriaPort implements TelemetriaPort {
  final List<String> vistas = [];
  final List<
    ({
      String pagina,
      String elementoId,
      String? etiqueta,
      String tipo,
      Map<String, Object?> metadata,
    })
  >
  ctas = [];

  @override
  Future<void> registrarVista(
    String ruta, {
    Map<String, Object?> datos = const {},
  }) async => vistas.add(ruta);

  @override
  Future<void> registrarCta({
    required String pagina,
    required String elementoId,
    String? etiqueta,
    String tipo = 'button',
    Map<String, Object?> metadata = const {},
  }) async => ctas.add((
    pagina: pagina,
    elementoId: elementoId,
    etiqueta: etiqueta,
    tipo: tipo,
    metadata: metadata,
  ));

  @override
  Future<void> registrarExportacion(
    String tipo, {
    Map<String, Object?> datos = const {},
  }) async {}
}
