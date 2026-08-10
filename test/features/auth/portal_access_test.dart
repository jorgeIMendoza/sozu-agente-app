import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_agente_app/features/auth/services/portal_access.dart';

/// Contrato del gate de acceso al Portal de Agentes.
///
/// Este archivo es el espejo del gate del backend (`authAgente()` en
/// `_shared/agente.ts` del repo sozu-edge-functions). Si alguien relaja una de
/// estas pruebas sin tocar el backend, el usuario entra al app y recibe 403 en
/// cada pantalla.
void main() {
  UserProfile perfil({int? roleId, String? roleName}) =>
      UserProfile(roleId: roleId, roleName: roleName);

  group('PortalAccess.allows', () {
    test('Agente Inmobiliario (3) entra', () {
      expect(PortalAccess.allows(perfil(roleId: 3)), isTrue);
    });

    test('Agente Interno (9) entra', () {
      expect(PortalAccess.allows(perfil(roleId: 9)), isTrue);
    });

    test('Cliente (23) NO entra: este portal no es el suyo', () {
      expect(PortalAccess.allows(perfil(roleId: 23)), isFalse);
    });

    test('Inmobiliaria (4) NO entra: tiene su propio portal', () {
      expect(PortalAccess.allows(perfil(roleId: 4)), isFalse);
    });

    test('Super Administrador (1) NO entra por rol', () {
      // Su camino es el acceso administrador (canManageAgentApp), no este gate:
      // un admin sin permiso de la app no debe colarse al portal del agente.
      expect(PortalAccess.allows(perfil(roleId: 1)), isFalse);
    });

    test('sin perfil no hay acceso', () {
      expect(PortalAccess.allows(null), isFalse);
    });

    test('sin rol_id cae al nombre normalizado', () {
      expect(
        PortalAccess.allows(perfil(roleName: '  Agente Inmobiliario ')),
        isTrue,
      );
      expect(PortalAccess.allows(perfil(roleName: 'Agente Interno')), isTrue);
      expect(PortalAccess.allows(perfil(roleName: 'Cliente')), isFalse);
    });

    test('con rol_id el nombre no decide', () {
      // Un rol renombrado en BD no debe abrir ni cerrar el portal: manda el id.
      expect(
        PortalAccess.allows(perfil(roleId: 23, roleName: 'Agente Interno')),
        isFalse,
      );
      expect(
        PortalAccess.allows(perfil(roleId: 3, roleName: 'Lo que sea')),
        isTrue,
      );
    });
  });

  group('PortalAccess.isExternalAlly', () {
    test('el 3 es el aliado externo; el 9 no', () {
      expect(PortalAccess.isExternalAlly(perfil(roleId: 3)), isTrue);
      expect(PortalAccess.isExternalAlly(perfil(roleId: 9)), isFalse);
      expect(PortalAccess.isExternalAlly(null), isFalse);
    });
  });

  group('PortalAccess.agentRoleIds', () {
    test('default 3 y 9 sin env cargado', () {
      expect(PortalAccess.agentRoleIds, <int>[3, 9]);
    });
  });
}
