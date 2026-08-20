import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/perfil/adapters/perfil_agente_adapter.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

import '../agente_test_support.dart';
import 'fake_perfil_agente_port.dart';

/// Providers del Perfil del agente contra el PUERTO (sin Supabase) y la
/// reconstrucción del puerto al cambiar la impersonación: si eso se rompe, un
/// admin ve (y peor, edita) el perfil del agente anterior.
void main() {
  test('perfilAgenteProvider resuelve contra el puerto', () async {
    final port = FakePerfilAgentePort();
    final container = makeClientContainer(
      overrides: [perfilAgentePortProvider.overrideWithValue(port)],
    );

    final perfil = await container.read(perfilAgenteProvider.future);

    expect(perfil.presentacion.nombre, 'Alex Hernández');
    expect(perfil.activacion.porcentaje, 75);
    expect(perfil.activacion.verificado, isFalse);
    expect(perfil.cuentaSozu?.porcentajeComision, 3);
    expect(perfil.cuentas.single.ultimos4, '4321');
    expect(port.log, ['cargar']);
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakePerfilAgentePort()
      ..proximoFallo = ApiError(403, 'forbidden_role');
    final container = makeClientContainer(
      overrides: [perfilAgentePortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(perfilAgenteProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'forbidden_role')),
    );
  });

  test('cambiar la impersonación reconstruye el puerto con el id', () {
    final container = makeClientContainer();

    final antes =
        container.read(perfilAgentePortProvider) as PerfilAgenteAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante =
        container.read(perfilAgentePortProvider) as PerfilAgenteAdapter;
    expect(durante.impersonate, 7);
    expect(identical(antes, durante), isFalse);

    container.read(impersonationProvider).clear();
    expect(
      (container.read(perfilAgentePortProvider) as PerfilAgenteAdapter)
          .impersonate,
      isNull,
    );
  });

  test('los municipios solo llegan cuando se pide un estado', () async {
    final port = FakePerfilAgentePort();
    final container = makeClientContainer(
      overrides: [perfilAgentePortProvider.overrideWithValue(port)],
    );

    final sinEstado = await container.read(
      catalogosDeDomicilioProvider(null).future,
    );
    expect(sinEstado.municipios, isEmpty);
    expect(sinEstado.estados.single.nombre, 'Ciudad de México');

    final conEstado = await container.read(
      catalogosDeDomicilioProvider(9).future,
    );
    expect(conEstado.municipios.single.nombre, 'Benito Juárez');
    expect(port.log, ['catalogosDeDomicilio:null', 'catalogosDeDomicilio:9']);
  });

  test('la firma de la carta se consulta aparte del perfil', () async {
    final port = FakePerfilAgentePort()
      ..firma = const FirmaDeCarta(
        estado: EstadoFirmaCarta.firmadoParcial,
        folio: 'doc-1',
        urlParaFirmar: 'https://ejemplo/widget/abc',
      );
    final container = makeClientContainer(
      overrides: [perfilAgentePortProvider.overrideWithValue(port)],
    );

    // Cargar el perfil NO sincroniza la firma: son dos viajes distintos a
    // propósito, porque el segundo sale a la red con el proveedor.
    await container.read(perfilAgenteProvider.future);
    expect(port.log, ['cargar']);

    final firma = await container.read(firmaDeCartaProvider.future);
    expect(firma.estado, EstadoFirmaCarta.firmadoParcial);
    expect(firma.estado.enCurso, isTrue);
    expect(port.log, ['cargar', 'consultarFirmaDeCarta']);
  });

  test('los datos de la Constancia llegan al puerto al subirla', () async {
    final port = FakePerfilAgentePort();
    final container = makeClientContainer(
      overrides: [perfilAgentePortProvider.overrideWithValue(port)],
    );

    final veredicto = await container
        .read(perfilAgentePortProvider)
        .subirDocumento(
          tipo: TiposDocumento.constanciaFiscal,
          base64: 'JVBERi0=',
          nombre: 'csf.pdf',
          datos: const DatosDeConstancia(
            rfc: 'HEAL850101AB1',
            curp: 'HEAL850101HDFRRL09',
            regimen: '626',
          ),
        );

    // El app ya no propone estatus: el servidor lee el PDF y lo decide él.
    expect(veredicto.estado, EstadoDocumento.revision);
    expect(port.ultimosDatosFiscales?.rfc, 'HEAL850101AB1');
    // El CURP también viaja: está en la whitelist de `persona_updates`, y sin
    // mandarlo la Constancia dejaba ese dato en el documento y no en el perfil.
    expect(port.ultimosDatosFiscales?.curp, 'HEAL850101HDFRRL09');
    expect(port.ultimosDatosFiscales?.vacio, isFalse);
  });
}
