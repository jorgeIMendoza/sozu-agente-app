/// Validaciones locales de los formularios del Perfil: se adelantan al backend,
/// que valida lo mismo, para que el aviso salga en el campo y no tras un viaje.
library;

/// Formato oficial del CURP, el MISMO regex que valida el portal web
/// (`AgentOnboardingStepDialog.tsx`).
final _reCurp = RegExp(r'^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$');

/// ¿El CURP tiene el formato oficial? Recorta y pasa a mayúsculas antes de
/// comparar: es lo que se manda al backend.
bool curpValido(String valor) => _reCurp.hasMatch(valor.trim().toUpperCase());

/// Motivo por el que la Carta de comercialización NO se puede firmar, o null si
/// sí se puede.
///
/// La carta es un documento legal, así que exige identificación VALIDADA: la web
/// lo pide con `identidadVerificada` y `firma_carta_crear` no lo comprueba, o
/// sea que si el frontend no lo exige, nadie lo exige.
///
/// [identidadValidada] sale del estatus AGREGADO del expediente, así que es un
/// proxy del gate de la web, que mira documento por documento. Se cierra cuando
/// `agente-perfil` exponga `identidad_verificada`.
String? motivoParaNoFirmarCarta({
  required bool puedeEditar,
  required String? notaSoloLectura,
  required bool identidadValidada,
}) {
  if (notaSoloLectura != null) return notaSoloLectura;
  if (!puedeEditar) return 'No tienes permiso para firmar tu carta.';
  if (!identidadValidada) {
    return 'Para firmar tu carta necesitas tu identificación validada. En '
        'cuanto verificación la apruebe, este botón se activa.';
  }
  return null;
}
