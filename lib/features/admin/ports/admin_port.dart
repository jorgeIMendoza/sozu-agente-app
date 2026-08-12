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

  /// Proyectos activos comercializados por SOZU.
  Future<List<CatalogoItem>> projectCatalog();

  /// Modelos disponibles dentro de los proyectos indicados.
  Future<List<CatalogoItem>> modelCatalog(List<int> projectIds);

  /// Niveles (numero de piso) existentes en los proyectos indicados, acotados a
  /// `modelIds` cuando se pasa.
  Future<List<CatalogoItem>> levelCatalog(
    List<int> projectIds, {
    List<int> modelIds,
  });

  /// Propiedades de los proyectos indicados, acotadas a modelos y niveles.
  Future<List<CatalogoItem>> propertyCatalog(
    List<int> projectIds, {
    List<int> modelIds,
    List<int> levelIds,
  });

  /// Avisos enviados y programados.
  Future<List<AvisoApp>> announcements();

  /// Crea un aviso, o lo programa si viene `scheduledFor`. Los `*Ids` acotan al
  /// publico destino; sin ninguno va a todos los clientes.
  Future<AvisoApp> createAnnouncement({
    required String title,
    required String message,
    required String type,
    required String category,
    required List<String> channels,
    List<int> projectIds,
    List<int> modelIds,
    List<int> levelIds,
    List<int> propertyIds,
    DateTime? scheduledFor,
  });

  /// Cancela un aviso programado; false si ya no era cancelable.
  Future<bool> cancelAnnouncement(int announcementId);

  /// Animacion de llegada de notificaciones: 'sobre' | 'gol' | 'cohete'.
  Future<String> bellAnimation();

  /// Cambia la animacion de llegada de notificaciones para todos los clientes.
  Future<void> setBellAnimation(String animation);
}
