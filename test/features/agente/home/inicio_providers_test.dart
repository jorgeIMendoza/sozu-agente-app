import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/home/adapters/inicio_adapter.dart';
import 'package:sozu_agente_app/features/agente/home/ports/inicio_port.dart';
import 'package:sozu_agente_app/features/agente/home/providers/inicio_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

import '../agente_test_support.dart';
import 'fake_inicio_port.dart';

/// Tablero de Inicio contra el PUERTO (sin Supabase): el mapeo del contrato, el
/// recorte de citas que hace la pantalla y la reconstrucción del puerto al
/// cambiar de agente impersonado: si esto último se rompe, un administrador ve
/// los números de otro agente.
void main() {
  test('el resumen mapea kpis, citas y último acceso del contrato', () async {
    final port = FakeInicioPort();
    final container = makeClientContainer(
      overrides: [inicioPortProvider.overrideWithValue(port)],
    );

    final resumen = await container.read(resumenInicioProvider.future);

    expect(resumen.kpis.comisionPagada, 125000.5);
    // El backend manda `numeric` como texto: si esto vuelve 0, el parser se rompió.
    expect(resumen.kpis.comisionPendiente, 48250.25);
    expect(resumen.kpis.ventasActivas, 3);
    expect(resumen.kpis.ventasCerradas, 2);
    expect(resumen.propiedadesActivas, 3);
    expect(resumen.ultimoAcceso, isNotNull);
    expect(resumen.citas.length, 4);
    expect(port.log, ['cargarResumen']);
  });

  test('la tarjeta de Inicio recorta la agenda a tres citas', () async {
    final container = makeClientContainer(
      overrides: [inicioPortProvider.overrideWithValue(FakeInicioPort())],
    );

    await container.read(resumenInicioProvider.future);

    final citas = container.read(citasInicioProvider);
    expect(citas.length, kMaxCitasInicio);
    // Conserva el orden del backend (próximas primero).
    expect(citas.map((c) => c.id), [1, 2, 3]);
  });

  test('mientras carga, la lista de citas está vacía y no revienta', () {
    final container = makeClientContainer(
      overrides: [inicioPortProvider.overrideWithValue(FakeInicioPort())],
    );

    expect(container.read(citasInicioProvider), isEmpty);
  });

  group('CitaAgente', () {
    CitaAgente citaDe(int id, List<Map<String, dynamic>> citas) => citas
        .map(CitaAgente.desdeJson)
        .firstWhere((c) => c.id == id);

    late List<Map<String, dynamic>> crudas;

    setUp(() {
      crudas = (FakeInicioPort().payload['citas'] as List)
          .cast<Map<String, dynamic>>();
    });

    test('el título prefiere el nombre de la configuración del showroom', () {
      expect(citaDe(1, crudas).titulo, 'Showroom Reforma');
    });

    test('sin configuración, el título combina tipo y proyecto', () {
      expect(citaDe(2, crudas).titulo, 'Visita · Margot');
    });

    test('el horario junta inicio y fin, y omite el fin cuando no hay', () {
      expect(citaDe(1, crudas).horario, '10:00 - 11:00');
      expect(citaDe(3, crudas).horario, '09:30');
    });

    test('00:00 significa "sin horario", no medianoche', () {
      expect(citaDe(2, crudas).horario, isNull);
    });

    test('solo se cancelan las citas por venir que siguen vivas', () {
      expect(citaDe(1, crudas).puedeCancelarse, isTrue);
      // Pasada.
      expect(citaDe(3, crudas).puedeCancelarse, isFalse);
      // Pasada y con "no asistió".
      expect(citaDe(4, crudas).puedeCancelarse, isFalse);
    });

    test('el tono del distintivo llega traducido del contrato', () {
      expect(citaDe(1, crudas).distintivo.tono, TonoCita.info);
      expect(citaDe(3, crudas).distintivo.tono, TonoCita.exito);
      expect(citaDe(4, crudas).distintivo.tono, TonoCita.alerta);
    });
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakeInicioPort()..proximoFallo = ApiError(0, 'network_error');
    final container = makeClientContainer(
      overrides: [inicioPortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(resumenInicioProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'network_error')),
    );
  });

  test('cancelar una cita llega al puerto con su id', () async {
    final port = FakeInicioPort();
    final container = makeClientContainer(
      overrides: [inicioPortProvider.overrideWithValue(port)],
    );

    await container.read(inicioPortProvider).cancelarCita(42);

    expect(port.log, ['cancelarCita:42']);
  });

  test('cambiar de agente impersonado reconstruye el puerto con su id', () {
    final container = makeClientContainer();

    final antes = container.read(inicioPortProvider) as InicioAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante = container.read(inicioPortProvider) as InicioAdapter;
    expect(durante.impersonate, 7);
    expect(identical(antes, durante), isFalse);

    container.read(impersonationProvider).clear();
    expect((container.read(inicioPortProvider) as InicioAdapter).impersonate,
        isNull);
  });

  test('cambiar de usuario autenticado reconstruye el puerto', () {
    final container = makeClientContainer();

    final antes = container.read(inicioPortProvider);
    container.read(testUserIdProvider.notifier).state = 'user-2';

    expect(identical(container.read(inicioPortProvider), antes), isFalse);
  });
}
