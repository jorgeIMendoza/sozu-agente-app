import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

import 'fake_admin_port.dart';

/// Lo que fija este archivo es que los providers de admin funcionan contra el
/// PUERTO, no contra Supabase: todo corre con [FakeAdminPort] y ni un test
/// inicializa el backend. Antes esto era imposible (ver ADR 0002).
void main() {
  ProviderContainer makeContainer(FakeAdminPort port) {
    final container = ProviderContainer(
      overrides: [adminPortProvider.overrideWithValue(port)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('adminAgentesProvider resuelve la lista del puerto', () async {
    final port = FakeAdminPort();
    final container = makeContainer(port);

    final data = await container.read(adminAgentesProvider.future);

    expect(data.agentes, hasLength(3));
    expect(data.agentes.first.nombre, 'Alex Hernández');
    expect(port.log, ['agentes']);
  });

  test('el rol llega tipado y el desconocido queda en null', () async {
    final port = FakeAdminPort();
    final container = makeContainer(port);

    final agentes = (await container.read(adminAgentesProvider.future)).agentes;

    expect(agentes[0].rol, RolAgente.inmobiliario);
    expect(agentes[1].rol, RolAgente.interno);
    // Un rol que no es 3 ni 9 no se inventa: `rol` es null y la UI cae en el
    // nombre que manda la BD para no dejar la fila sin insignia.
    expect(agentes[2].rol, isNull);
    expect(agentes[2].rolEtiqueta, 'Coordinador');
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakeAdminPort()..nextFailure = ApiError(403, 'forbidden_role');
    final container = makeContainer(port);

    await expectLater(
      container.read(adminAgentesProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'forbidden_role')),
    );
  });
}
