import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/features/admin/ports/admin_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Implementacion actual de [AdminPort] sobre Supabase (edge functions
/// admin-agentes y admin-avisos-app): la unica frontera de la feature donde
/// se conocen sus tipos. Si el backend cambia, se reescribe este archivo y
/// nada mas.
class AdminAdapter implements AdminPort {
  /// Getter perezoso a proposito: construir el adaptador no toca el singleton
  /// de Supabase, asi el provider puede crearlo antes de `Supabase.initialize`.
  SupabaseClient get _sb => Supabase.instance.client;

  /// Invoca una edge function con el JWT del usuario y normaliza cualquier
  /// fallo a [ApiError]. Sin cabecera de impersonacion: el admin actua
  /// siempre con su propia identidad.
  Future<Map<String, dynamic>> _invoke(
    String fn, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final res = await _sb.functions.invoke(fn, body: body ?? {});
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw ApiError(500, 'empty_response');
    } on FunctionException catch (e) {
      var code = 'internal_error';
      final details = e.details;
      if (details is Map && details['error'] != null) {
        code = details['error'].toString();
      }
      throw ApiError(e.status, code);
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError(0, 'network_error');
    }
  }

  @override
  Future<AdminAgentes> agentes() async =>
      AdminAgentes.fromJson(await _invoke('admin-agentes'));

  @override
  Future<List<RolDestino>> roleCatalog() async {
    final res = await _invoke(
      'admin-avisos-agentes',
      body: {'action': 'roles'},
    );
    return ((res['roles'] as List?) ?? [])
        .map((e) => RolDestino.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<AvisoApp>> announcements() async {
    final res = await _invoke(
      'admin-avisos-agentes',
      body: {'action': 'listar'},
    );
    return ((res['avisos'] as List?) ?? [])
        .map((e) => AvisoApp.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
    final res = await _invoke(
      'admin-avisos-agentes',
      body: {
        'action': 'crear',
        'titulo': title,
        'mensaje': message,
        'tipo': type,
        'categoria': category,
        'canales': channels,
        if (roleIds.isNotEmpty) 'ids_roles': roleIds,
        if (scheduledFor != null)
          'programado_para': scheduledFor.toUtc().toIso8601String(),
      },
    );
    return AvisoApp.fromJson(Map<String, dynamic>.from(res['aviso'] as Map));
  }

  @override
  Future<bool> cancelAnnouncement(int announcementId) async {
    final res = await _invoke(
      'admin-avisos-agentes',
      body: {'action': 'cancelar', 'id': announcementId},
    );
    return res['cancelado'] == true;
  }

  @override
  Future<String> bellAnimation() async {
    final res = await _invoke(
      'admin-avisos-agentes',
      body: {'action': 'config_get'},
    );
    return (res['animacion_campana'] as String?) ?? 'gol';
  }

  @override
  Future<void> setBellAnimation(String animation) async {
    await _invoke(
      'admin-avisos-agentes',
      body: {'action': 'config_set', 'animacion_campana': animation},
    );
  }
}
