import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/home/adapters/notificaciones_adapter.dart';
import 'package:sozu_agente_app/features/agente/home/providers/notificaciones_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

import '../agente_test_support.dart';
import 'fake_notificaciones_port.dart';

/// Providers de notificaciones contra el PUERTO (sin Supabase) y, lo critico de
/// la tanda, la reconstruccion del puerto al cambiar la impersonacion o la
/// sesion: si esto se rompe, un admin ve notificaciones de otro agente.
void main() {
  test('la bandeja resuelve contra el puerto', () async {
    final port = FakeNotificacionesPort();
    final container = makeClientContainer(
      overrides: [notificacionesPortProvider.overrideWithValue(port)],
    );

    final notif = await container.read(notificacionesProvider.future);

    expect(notif.noLeidas, 2);
    expect(notif.notificaciones.single.titulo, 'Nueva oferta');
    expect(port.log, ['notifications']);
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakeNotificacionesPort()
      ..nextFailure = ApiError(403, 'forbidden_role');
    final container = makeClientContainer(
      overrides: [notificacionesPortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(notificacionesProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'forbidden_role')),
    );
  });

  test('cambiar la impersonacion reconstruye el puerto con el id', () {
    final container = makeClientContainer();

    final antes =
        container.read(notificacionesPortProvider) as NotificacionesAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante =
        container.read(notificacionesPortProvider) as NotificacionesAdapter;
    expect(durante.impersonate, 7);
    expect(identical(antes, durante), isFalse);

    container.read(impersonationProvider).clear();
    final despues =
        container.read(notificacionesPortProvider) as NotificacionesAdapter;
    expect(despues.impersonate, isNull);
  });

  test('cambiar de usuario autenticado reconstruye el puerto', () {
    final container = makeClientContainer();

    final antes = container.read(notificacionesPortProvider);
    container.read(testUserIdProvider.notifier).state = 'user-2';

    expect(identical(container.read(notificacionesPortProvider), antes), isFalse);
  });
}
