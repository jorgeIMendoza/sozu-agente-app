import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:sozu_agente_app/features/auth/ports/auth_port.dart';

/// Quién puede entrar al Portal de Agentes.
///
/// Un solo camino: el ROL. Agente Inmobiliario (3, el aliado externo) y Agente
/// Interno (9, el de SOZU). A diferencia del Portal del Cliente (donde además
/// entra cualquiera con una compra activa, porque el rol dice para qué se
/// contrató a la persona y no si compró) aquí la única razón para entrar es que
/// se te contrató para vender. No hay equivalente de `es_comprador`.
///
/// El acceso administrador (impersonación, "ver como agente") es otra cosa y va
/// por permiso del rol ([UserProfile.canManageAgentApp]), no por aquí.
abstract final class PortalAccess {
  /// `roles.id` de los roles de agente en producción, el ambiente contra el que
  /// se compila el release. Estables en dev y prod (`_shared/portales.ts` del
  /// repo de Edge Functions los tiene fijos).
  static const List<int> _defaultAgentRoleIds = <int>[3, 9];

  /// Nombres normalizados aceptados cuando el perfil no trae `rol_id`. Red de
  /// seguridad de transición, no la regla: el id es lo estable.
  static const List<String> _agentRoleNames = <String>[
    'agente inmobiliario',
    'agente interno',
  ];

  /// Ids de rol que entran, con `AGENTE_ROL_IDS` del env como override.
  ///
  /// Getter, no `static final`: una constante perezosa leída antes de
  /// `dotenv.load()` cachearía el default para toda la vida del proceso.
  static List<int> get agentRoleIds {
    final raw = dotenv.isInitialized ? dotenv.env['AGENTE_ROL_IDS'] : null;
    if (raw == null || raw.trim().isEmpty) return _defaultAgentRoleIds;
    final ids = raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList(growable: false);
    return ids.isEmpty ? _defaultAgentRoleIds : ids;
  }

  /// ¿Este perfil puede entrar al portal?
  ///
  /// El mismo criterio lo aplica `authAgente()` en las Edge Functions
  /// (`_shared/agente.ts`). Si los dos dejan de coincidir el usuario entra y
  /// recibe 403 en cada pantalla, así que se cambian juntos.
  static bool allows(UserProfile? p) {
    if (p == null) return false;
    return _hasAgentRole(p);
  }

  /// ¿Es el aliado EXTERNO (rol 3)? Su información fiscal, bancaria y su
  /// comisión las administra su inmobiliaria cuando es dependiente; el portal
  /// le esconde esas secciones. El interno (9) nunca cuelga de una inmobiliaria.
  ///
  /// Quién es dependiente y quién independiente NO se decide aquí: eso sale de
  /// `entidades_relacionadas` y lo resuelve `agente-sesion` en el servidor.
  static bool isExternalAlly(UserProfile? p) => p?.roleId == 3;

  /// Por [UserProfile.roleId]; cae al nombre normalizado solo mientras el
  /// backend no devuelva `rol_id`.
  static bool _hasAgentRole(UserProfile p) {
    final roleId = p.roleId;
    if (roleId != null) return agentRoleIds.contains(roleId);
    return _agentRoleNames.contains((p.roleName ?? '').trim().toLowerCase());
  }
}
