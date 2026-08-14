import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/features/admin/ports/admin_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Doble de [AdminPort] con datos fijos en memoria: sin red, sin Supabase.
/// Se inyecta con `adminPortProvider.overrideWithValue`.
class FakeAdminPort implements AdminPort {
  /// Fallo forzado de la PRÓXIMA operación; se consume al usarse.
  ApiError? nextFailure;

  /// Nombres de los métodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  /// Avisos "existentes"; [createAnnouncement] agrega y [cancelAnnouncement]
  /// marca cancelado.
  final List<AvisoApp> storedAnnouncements = [];

  String storedAnimation = 'gol';
  int _nextId = 1;

  void _throwIfFailing(String method) {
    log.add(method);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  /// Uno de cada rol y uno con rol desconocido: los tres casos que la UI tiene
  /// que saber pintar y filtrar.
  @override
  Future<AdminAgentes> agentes() async {
    _throwIfFailing('agentes');
    return AdminAgentes.fromJson({
      'agentes': [
        {
          'id_persona': 7,
          'nombre': 'Alex Hernández',
          'email': 'alex@x.com',
          'rol_id': 3,
          'rol_nombre': 'Agente Inmobiliario',
        },
        {
          'id_persona': 8,
          'nombre': 'Bruno Pérez',
          'email': 'bruno@x.com',
          'rol_id': 9,
          'rol_nombre': 'Agente Interno',
        },
        {
          'id_persona': 9,
          'nombre': 'Carla Ruiz',
          'email': 'carla@x.com',
          'rol_nombre': 'Coordinador',
        },
      ],
    });
  }

  /// Los dos roles del portal con conteos distintos: si la UI sumara mal, un
  /// total de 5 (3 + 2) lo delata.
  @override
  Future<List<RolDestino>> roleCatalog() async {
    _throwIfFailing('roleCatalog');
    return const [
      RolDestino(id: 3, total: 3, nombre: 'Agente Inmobiliario'),
      RolDestino(id: 9, total: 2, nombre: 'Agente Interno'),
    ];
  }

  @override
  Future<List<AvisoApp>> announcements() async {
    _throwIfFailing('announcements');
    return List.of(storedAnnouncements);
  }

  @override
  Future<AvisoApp> createAnnouncement({
    required String title,
    required String message,
    required String type,
    required String category,
    required List<String> channels,
    List<int> roleIds = const [],
    DateTime? scheduledFor,
  }) async {
    _throwIfFailing('createAnnouncement');
    final announcement = AvisoApp.fromJson({
      'id': _nextId++,
      'titulo': title,
      'mensaje': message,
      'tipo': type,
      'categoria': category,
      'canales': channels,
      'ids_roles': roleIds,
      'programado_para': scheduledFor?.toUtc().toIso8601String(),
      'estado': scheduledFor != null ? 'pendiente' : 'enviado',
    });
    storedAnnouncements.add(announcement);
    return announcement;
  }

  @override
  Future<bool> cancelAnnouncement(int announcementId) async {
    _throwIfFailing('cancelAnnouncement');
    final i = storedAnnouncements.indexWhere(
      (a) => a.id == announcementId && a.estado == 'pendiente',
    );
    if (i < 0) return false;
    storedAnnouncements.removeAt(i);
    return true;
  }

  @override
  Future<String> bellAnimation() async {
    _throwIfFailing('bellAnimation');
    return storedAnimation;
  }

  @override
  Future<void> setBellAnimation(String animation) async {
    _throwIfFailing('setBellAnimation');
    storedAnimation = animation;
  }
}
