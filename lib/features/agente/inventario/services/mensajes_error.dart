import 'package:sozu_agente_app/shared/api_error.dart';

/// Traducción de los códigos de error del inventario a un mensaje accionable.
///
/// Los códigos del backend son snake_case en inglés (`not_owner`,
/// `network_error`) y NUNCA se muestran tal cual: el agente no puede hacer nada
/// con ellos. Vive en un solo lugar porque las tres pantallas de la sección
/// tienen que decir lo mismo ante el mismo fallo.
String mensajeErrorInventario(Object error) {
  if (error is! ApiError) {
    return 'Ocurrió un problema inesperado. Intenta de nuevo.';
  }
  return switch (error.code) {
    'network_error' => 'Revisa tu conexión e intenta de nuevo.',
    'not_owner' => 'Este desarrollo no está entre los que tienes asignados.',
    'not_found' => 'El desarrollo ya no está publicado.',
    'missing_id' => 'No pudimos identificar el desarrollo. Vuelve al inventario.',
    'forbidden_role' || 'forbidden' =>
      'Tu usuario no tiene acceso al inventario.',
    'invalid_vista' => 'Actualiza el app: esta vista ya no está disponible.',
    _ => 'Intenta de nuevo en un momento.',
  };
}
