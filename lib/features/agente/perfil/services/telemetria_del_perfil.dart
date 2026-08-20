/// Identificadores de telemetría del menú Perfil.
///
/// Son los MISMOS que emite el portal web (`AgentPerfil.tsx`): si el app inventa
/// otro nombre, el tablero de CTA cuenta el mismo botón en dos series y ninguna
/// de las dos es el total.
library;

/// Ruta de vista, página de CTA e ids de elemento del Perfil.
abstract final class TelemetriaPerfil {
  static const ruta = '/admin/agent/perfil';
  static const pagina = 'agent_perfil';

  // ── Elementos ──
  static const pageView = 'page_view';
  static const seccionDatosCuenta = 'btn_seccion_datos_cuenta';
  static const seccionDocumentos = 'btn_seccion_documentos';

  /// Etapa de la activación. La etiqueta es el título del bloque y en la
  /// metadata va `step_id` (`basic`, `fiscal`, `bank-accounts`, `training`).
  static const etapaOnboarding = 'btn_etapa_onboarding';

  // ── Tipos de elemento de `registrarCta` ──
  static const tipoPagina = 'page';
}
