/// Validaciones locales de los formularios del Perfil: se adelantan al backend,
/// que valida lo mismo, para que el aviso salga en el campo y no tras un viaje.
library;

/// Formato oficial del CURP, el MISMO regex que valida el portal web
/// (`AgentOnboardingStepDialog.tsx`).
final _reCurp = RegExp(r'^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$');

/// ¿El CURP tiene el formato oficial? Recorta y pasa a mayúsculas antes de
/// comparar: es lo que se manda al backend.
bool curpValido(String valor) => _reCurp.hasMatch(valor.trim().toUpperCase());
