/// Telemetria del portal: vista de pantalla, clic de CTA y exportacion. Los
/// mismos eventos que registra el portal web, para que los tableros de CTA y la
/// bitacora no queden partidos entre web y app.
///
/// NINGUN metodo lanza: la telemetria se traga cualquier fallo (red caida, 4xx,
/// tabla ausente) y la pantalla nunca se entera. Por eso no declara [ApiError] y
/// se puede llamar sin `await`.
abstract interface class TelemetriaPort {
  /// Registra la vista de una pantalla. `ruta` es la MISMA que usa la web
  /// (`/admin/agent/inicio`, ...): es la llave con la que se agrupa la bitacora.
  Future<void> registrarVista(String ruta, {Map<String, Object?> datos});

  /// Registra el clic de un CTA. `pagina` y `elementoId` deben ser identicos a
  /// los del portal web (`agent_inicio` / `btn_nuevo_prospecto`), o el mismo
  /// boton cuenta dos veces en el tablero. `tipo`: `button`, `page`, `input`.
  ///
  /// En `metadata` NO va PII ni montos: un folio o un id de proyecto si; un
  /// nombre, un correo, un RFC, una CLABE o un importe no. La identidad la
  /// deriva el backend del JWT, asi que el app tampoco manda email ni
  /// id_persona.
  Future<void> registrarCta({
    required String pagina,
    required String elementoId,
    String? etiqueta,
    String tipo,
    Map<String, Object?> metadata,
  });

  /// Registra una descarga o exportacion (`brochure`, `ficha_tecnica`, ...).
  /// Misma regla que `metadata`: en `datos` no van PII ni montos.
  Future<void> registrarExportacion(String tipo, {Map<String, Object?> datos});
}
