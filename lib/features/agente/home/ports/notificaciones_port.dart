import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Bandeja de notificaciones del agente: listarlas y mover su estado de lectura.
///
/// La instancia queda atada al agente que se esta viendo (el propio, o el
/// impersonado por un super admin), asi que ningun metodo recibe ese target.
/// Todos los metodos lanzan [ApiError].
abstract interface class NotificacionesPort {
  /// Notificaciones del agente y su conteo de no leidas.
  Future<BandejaDeNotificaciones> notifications();

  /// Marca una notificacion como leida.
  Future<void> markNotificationRead(int notificationId);

  /// Revierte el "leido" de una notificacion.
  Future<void> markNotificationUnread(int notificationId);

  /// Marca como leidas todas las notificaciones del agente.
  Future<void> markAllNotificationsRead();

  /// Descarta una notificacion: deja de listarse y de contar.
  Future<void> dismissNotification(int notificationId);
}
