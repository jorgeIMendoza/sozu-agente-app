import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ignore: always_use_package_imports -- import condicional: la resolucion por plataforma exige ruta relativa.
import 'user_agent/user_agent_stub.dart'
    if (dart.library.js_interop) 'user_agent/user_agent_web.dart';
import 'package:sozu_agente_app/core/version.dart';

/// Mediciones de uso ("Uso por portal" en Alta Dirección): registra la sesión
/// del agente en portal_sesiones (portal `agentes`) vía los mismos RPCs
/// SECURITY DEFINER que usan los portales web (register/touch/close). Las
/// donas del tablero clasifican el user_agent: en web se manda el real del
/// navegador; en móvil uno sintético con marca/modelo reales del dispositivo.
class PortalTracking {
  PortalTracking._();

  /// Portal con el que se registra la sesión en `portal_sesiones`.
  ///
  /// `agentes`, NO `clientes`: este archivo llegó copiado del app del cliente y
  /// registraba las sesiones del agente dentro del portal de clientes,
  /// inflando sus donas con usuarios que no eran suyos. Público para que el
  /// test lo fije.
  static const portal = 'agentes';

  /// Token del user_agent sintético que el clasificador SQL del tablero mira
  /// para contar el acceso como "App agentes". Si cambia aquí, cambia allá.
  static const appToken = 'SozuAgenteApp';
  static const _heartbeatCada = Duration(minutes: 5);

  static String? _sessionId;
  static Timer? _heartbeat;
  static bool _iniciando = false;

  static SupabaseClient get _sb => Supabase.instance.client;

  /// Abre (o reutiliza) la sesión de medición. Llamar cuando hay sesión de un
  /// agente real: un admin no pasa `PortalAccess.allows`, así que su
  /// impersonación no cuenta como uso del portal.
  static Future<void> iniciar() async {
    if (_sessionId != null || _iniciando) return;
    _iniciando = true;
    try {
      final ua = await _userAgent();
      final res = await _sb.rpc(
        'register_portal_session',
        params: {'p_portal': portal, 'p_user_agent': ua},
      );
      _sessionId = res as String?;
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(_heartbeatCada, (_) => _touch());
    } catch (e) {
      debugPrint('PortalTracking: no se pudo registrar la sesión: $e');
    } finally {
      _iniciando = false;
    }
  }

  static Future<void> _touch() async {
    final id = _sessionId;
    if (id == null) return;
    try {
      await _sb.rpc('touch_portal_session', params: {'p_session_id': id});
    } catch (_) {
      /* siguiente heartbeat reintenta */
    }
  }

  /// Cierra la sesión de medición. Llamar ANTES de signOut (necesita JWT).
  static Future<void> cerrar() async {
    final id = _sessionId;
    _heartbeat?.cancel();
    _heartbeat = null;
    _sessionId = null;
    if (id == null) return;
    try {
      await _sb.rpc('close_portal_session', params: {'p_session_id': id});
    } catch (_) {
      /* la sesión expira sola por inactividad */
    }
  }

  /// UA para clasificar en las donas: real en web; sintético (pero con los
  /// tokens que el clasificador espera: Android/Mobile/modelo, iPhone) en app.
  ///
  /// El token [appToken] es lo que el clasificador SQL del tablero mira para
  /// contar el acceso como "App agentes"; sin él las sesiones caen en "Otro".
  static Future<String> _userAgent() async {
    final delNavegador = userAgentDelNavegador();
    if (delNavegador != null && delNavegador.isNotEmpty) return delNavegador;

    try {
      final plugin = DeviceInfoPlugin();
      if (!kIsWeb && Platform.isAndroid) {
        final a = await plugin.androidInfo;
        return 'Mozilla/5.0 (Linux; Android ${a.version.release}; '
            '${a.model}) Mobile $appToken/$appVersionBase';
      }
      if (!kIsWeb && Platform.isIOS) {
        final i = await plugin.iosInfo;
        return 'Mozilla/5.0 (iPhone; CPU iPhone OS '
            '${i.systemVersion.replaceAll('.', '_')} like Mac OS X) '
            'Mobile $appToken/$appVersionBase (${i.utsname.machine})';
      }
    } catch (_) {
      /* fallback genérico */
    }
    return '$appToken/$appVersionBase Mobile';
  }
}
