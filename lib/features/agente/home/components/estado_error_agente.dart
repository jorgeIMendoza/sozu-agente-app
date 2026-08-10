import 'package:flutter/material.dart';

import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Fallo de carga de una pantalla del portal, traducido a algo accionable.
///
/// Lee el `code` que manda el backend en vez de pintar un "algo salió mal" para
/// todo: sin conexión y rol sin acceso piden cosas distintas del usuario, y
/// ofrecer "Reintentar" ante un 403 solo lo hace tocar el botón tres veces.
///
/// Vive en `home` porque Inicio es la primera pantalla que lo necesita;
/// Comisiones lo reutiliza.
class EstadoErrorAgente extends StatelessWidget {
  final Object? error;
  final VoidCallback onReintentar;

  const EstadoErrorAgente({
    super.key,
    required this.error,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final e = error;
    final codigo = e is ApiError ? e.code : null;
    final estatus = e is ApiError ? e.status : null;

    // Sin permiso no hay nada que reintentar: es un estado estable, no un fallo.
    if (codigo == 'forbidden_role' || estatus == 403) {
      return const SEmptyState.card(
        icon: Icons.lock_outline,
        title: 'Esta sección no está disponible para tu perfil',
        message:
            'Si crees que deberías tener acceso, pídeselo a tu supervisor en '
            'SOZU.',
      );
    }

    final (String titulo, String mensaje) = switch (codigo) {
      'network_error' => (
        'Sin conexión',
        'Revisa tu internet y vuelve a intentarlo.',
      ),
      'unauthorized' => (
        'Tu sesión expiró',
        'Vuelve a entrar para continuar.',
      ),
      _ => (
        'No pudimos cargar tu información',
        'Fue una falla nuestra. Intenta de nuevo en un momento.',
      ),
    };

    return SErrorState(
      title: titulo,
      message: mensaje,
      onRetry: onReintentar,
    );
  }
}

/// Mensaje corto de un fallo, para un `SnackBar` tras una acción (cancelar una
/// cita, subir una factura). Los códigos que no son genéricos los pasa el
/// llamador en [porCodigo], porque solo él sabe qué significan en su flujo.
String mensajeAccionFallida(
  Object? error, {
  Map<String, String> porCodigo = const {},
  String generico = 'No pudimos completar la acción. Intenta de nuevo.',
}) {
  final codigo = error is ApiError ? error.code : null;
  if (codigo == null) return generico;
  final propio = porCodigo[codigo];
  if (propio != null) return propio;
  return switch (codigo) {
    'network_error' => 'Sin conexión. Revisa tu internet e intenta de nuevo.',
    'unauthorized' => 'Tu sesión expiró. Vuelve a entrar.',
    'forbidden_role' || 'not_owner' => 'No tienes permiso para esta acción.',
    _ => generico,
  };
}
