import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

import '../agente_test_support.dart';
import 'fake_prospectos_port.dart';

/// Providers de prospectos contra el PUERTO (sin backend) y, lo crítico, la
/// reconstrucción del puerto al cambiar de agente impersonado: si eso se rompe,
/// un administrador ve la cartera del agente anterior.
void main() {
  test('la cartera resuelve contra el puerto y mapea las claves', () async {
    final port = FakeProspectosPort();
    final container = makeClientContainer(
      overrides: [prospectosPortProvider.overrideWithValue(port)],
    );

    final cartera = await container.read(carteraProspectosProvider.future);

    expect(cartera.prospectos.map((p) => p.nombre), [
      'Ana Torres',
      'Bruno Díaz',
    ]);
    expect(cartera.catalogoEstados.map((e) => e.clave), ['nuevo', 'conectado']);
    expect(cartera.modeloDeTransicion, isFalse);

    final ana = cartera.prospectos.first;
    expect(ana.esCliente, isTrue);
    expect(ana.desarrollos.single.idRelacion, 101);
    expect(ana.desarrollos.single.estado, 'Conectado');

    // El servidor manda numeric como texto: tiene que llegar como número.
    final unidad = ana.desarrollos.single.unidades.first;
    expect(unidad.valor, 2500000.50);
    expect(unidad.ofertas, 3);
    expect(unidad.esCliente, isTrue);
    expect(port.log, ['cartera']);
  });

  test('via_rpc false se traduce a modelo de transición', () async {
    final port = FakeProspectosPort()..viaCarteraDeTransicion = true;
    final container = makeClientContainer(
      overrides: [prospectosPortProvider.overrideWithValue(port)],
    );

    final cartera = await container.read(carteraProspectosProvider.future);
    expect(cartera.modeloDeTransicion, isTrue);
  });

  test('el detalle trae persona, ofertas y actividad ordenada', () async {
    final port = FakeProspectosPort();
    final container = makeClientContainer(
      overrides: [prospectosPortProvider.overrideWithValue(port)],
    );

    final ficha = await container.read(detalleProspectoProvider(11).future);

    expect(ficha.persona.nombre, 'Ana Torres');
    expect(ficha.persona.esPersonaMoral, isFalse);
    expect(ficha.desarrollos.single.nombre, 'Margot');

    final oferta = ficha.ofertas.single;
    expect(oferta.tieneCuenta, isTrue);
    expect(oferta.tieneLinkCliente, isTrue);
    expect(oferta.unidad, 'A-101');

    expect(ficha.actividad.map((a) => a.tipo), [
      TipoActividad.nota,
      TipoActividad.cita,
    ]);
    final nota = ficha.actividad.first;
    expect(nota.esNotaPropia, isTrue);
    expect(nota.adjuntos.single.nombre, 'plano.pdf');
    expect(ficha.actividad.last.esNotaPropia, isFalse);
    expect(port.log, ['detalle:11']);
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakeProspectosPort()..nextFailure = ApiError(403, 'not_owner');
    final container = makeClientContainer(
      overrides: [prospectosPortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(detalleProspectoProvider(11).future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'not_owner')),
    );
  });

  test(
    'los catálogos de la transferencia y del alta salen del puerto',
    () async {
      final port = FakeProspectosPort();
      final container = makeClientContainer(
        overrides: [prospectosPortProvider.overrideWithValue(port)],
      );

      final agentes = await container.read(agentesDestinoProvider.future);
      final desarrollos = await container.read(
        desarrollosVinculablesProvider.future,
      );

      expect(agentes.single.id, 'uuid-1');
      expect(agentes.single.etiqueta, 'Carla Ruiz · Agente Inmobiliario');
      expect(desarrollos.map((d) => d.nombre), ['Margot', 'Torre Sur']);
    },
  );

  test('cambiar la impersonación reconstruye el puerto', () {
    final container = makeClientContainer();

    final antes = container.read(prospectosPortProvider);
    container.read(impersonationProvider).select(7, 'Ana', 'ana@x.com');
    final durante = container.read(prospectosPortProvider);

    expect(identical(antes, durante), isFalse);

    container.read(impersonationProvider).clear();
    expect(identical(container.read(prospectosPortProvider), durante), isFalse);
  });

  test('cambiar de usuario autenticado reconstruye el puerto', () {
    final container = makeClientContainer();

    final antes = container.read(prospectosPortProvider);
    container.read(testUserIdProvider.notifier).state = 'user-2';

    expect(identical(container.read(prospectosPortProvider), antes), isFalse);
  });
}
