import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Operaciones del acceso administrador del app (rol con `roles.apps` que
/// administra `agentes`): selector "Ver como agente" y avisos.
///
/// Nunca impersona: actua siempre con la identidad del administrador.
/// Todos los metodos lanzan [ApiError].
abstract interface class AdminPort {
  /// Agentes impersonables (roles 3 y 9), con su rol para poder filtrarlos.
  Future<AdminAgentes> agentes();

  /// Roles del portal con cuantos agentes tiene cada uno, para elegir el
  /// publico de un aviso.
  Future<List<RolDestino>> roleCatalog();

  /// Avisos enviados y programados.
  Future<List<AvisoApp>> announcements();

  /// Crea un aviso, o lo programa si viene `scheduledFor`. `roleIds` acota el
  /// publico; vacio va a todos los agentes del portal.
  Future<AvisoApp> createAnnouncement({
    required String title,
    required String message,
    required String type,
    required String category,
    required List<String> channels,
    List<int> roleIds,
    DateTime? scheduledFor,
  });

  /// Cancela un aviso programado; false si ya no era cancelable.
  Future<bool> cancelAnnouncement(int announcementId);

  /// Animacion de llegada de notificaciones: 'sobre' | 'gol' | 'cohete'.
  Future<String> bellAnimation();

  /// Cambia la animacion de llegada de notificaciones para todos los agentes.
  Future<void> setBellAnimation(String animation);
}
