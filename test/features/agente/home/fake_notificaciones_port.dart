import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/features/agente/home/ports/notificaciones_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Doble de [NotificacionesPort] con datos fijos en memoria: sin red, sin
/// Supabase. Se inyecta con `notificacionesPortProvider.overrideWithValue`.
class FakeNotificacionesPort implements NotificacionesPort {
  /// Fallo forzado de la PROXIMA operacion; se consume al usarse.
  ApiError? nextFailure;

  /// Nombres de los metodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  int noLeidas = 2;

  void _throwIfFailing(String method) {
    log.add(method);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  @override
  Future<BandejaDeNotificaciones> notifications() async {
    _throwIfFailing('notifications');
    return BandejaDeNotificaciones.fromJson({
      'notificaciones': [
        {
          'id': 1,
          'tipo': 'informativa',
          'titulo': 'Nueva oferta',
          'descripcion': 'Tu prospecto avanzó de etapa',
        },
      ],
      'no_leidas': noLeidas,
    });
  }

  @override
  Future<void> markNotificationRead(int notificationId) async {
    _throwIfFailing('markNotificationRead:$notificationId');
    noLeidas = noLeidas > 0 ? noLeidas - 1 : 0;
  }

  @override
  Future<void> markNotificationUnread(int notificationId) async {
    _throwIfFailing('markNotificationUnread:$notificationId');
    noLeidas++;
  }

  @override
  Future<void> markAllNotificationsRead() async {
    _throwIfFailing('markAllNotificationsRead');
    noLeidas = 0;
  }

  @override
  Future<void> dismissNotification(int notificationId) async {
    _throwIfFailing('dismissNotification:$notificationId');
  }
}
