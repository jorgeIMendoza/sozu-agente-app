import 'package:sozu_agente_app/shared/ports/telemetria_port.dart';

/// Un CTA registrado, con lo que el tablero usa para agrupar.
class CtaRegistrado {
  final String pagina;
  final String elementoId;
  final String? etiqueta;
  final String tipo;
  final Map<String, Object?> metadata;

  const CtaRegistrado({
    required this.pagina,
    required this.elementoId,
    required this.etiqueta,
    required this.tipo,
    required this.metadata,
  });

  @override
  String toString() => '$pagina/$elementoId($tipo) $metadata';
}

/// Doble de [TelemetriaPort] que solo apunta lo que se le pide registrar. No
/// falla nunca: el contrato del puerto es tragarse cualquier error.
class FakeTelemetriaPort implements TelemetriaPort {
  final List<String> vistas = [];
  final List<Map<String, Object?>> datosDeVista = [];
  final List<CtaRegistrado> ctas = [];
  final List<String> exportaciones = [];
  final List<Map<String, Object?>> datosDeExportacion = [];

  @override
  Future<void> registrarVista(
    String ruta, {
    Map<String, Object?> datos = const {},
  }) async {
    vistas.add(ruta);
    datosDeVista.add(datos);
  }

  @override
  Future<void> registrarCta({
    required String pagina,
    required String elementoId,
    String? etiqueta,
    String tipo = 'button',
    Map<String, Object?> metadata = const {},
  }) async {
    ctas.add(
      CtaRegistrado(
        pagina: pagina,
        elementoId: elementoId,
        etiqueta: etiqueta,
        tipo: tipo,
        metadata: metadata,
      ),
    );
  }

  @override
  Future<void> registrarExportacion(
    String tipo, {
    Map<String, Object?> datos = const {},
  }) async {
    exportaciones.add(tipo);
    datosDeExportacion.add(datos);
  }

  /// Ids de elemento registrados en `pagina`, en orden.
  List<String> elementosDe(String pagina) => ctas
      .where((c) => c.pagina == pagina)
      .map((c) => c.elementoId)
      .toList(growable: false);

  /// El primer CTA con ese id, o null si no se registró.
  CtaRegistrado? primero(String elementoId) =>
      ctas.where((c) => c.elementoId == elementoId).firstOrNull;
}
