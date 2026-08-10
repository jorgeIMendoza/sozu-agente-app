import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/pipeline/adapters/pipeline_adapter.dart';
import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/features/agente/pipeline/providers/pipeline_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

import '../agente_test_support.dart';
import 'fake_pipeline_port.dart';

/// Providers del pipeline contra el PUERTO (sin backend) y las reglas que la
/// pantalla no puede romper: un negocio sin pipeline no se mueve, una etapa
/// automática tampoco, y lo que se pinta sale de los negocios ya agrupados.
void main() {
  test('el pipeline resuelve negocios, etapas, cifras y catálogo', () async {
    final port = FakePipelinePort();
    final container = makeClientContainer(
      overrides: [pipelinePortProvider.overrideWithValue(port)],
    );

    final datos = await container.read(pipelineProvider.future);

    expect(datos.negocios.map((n) => n.folio), [
      'O-000001',
      'O-000002',
      'O-000003',
    ]);
    expect(datos.resumen.negocios, 3);
    expect(datos.resumen.ofertas, 6);
    expect(datos.resumen.montoAbierto, 2000000);
    expect(datos.catalogoRazones.disponible, isTrue);
    expect(datos.etapaDe('oferta_enviada')?.automatica, isTrue);
    expect(port.log, ['negocios']);
  });

  test('la agrupación viene del servidor: el app no reagrupa', () async {
    final container = makeClientContainer(
      overrides: [pipelinePortProvider.overrideWithValue(FakePipelinePort())],
    );
    await container.read(pipelineProvider.future);

    final negocios = container.read(negociosProvider);
    // Tres negocios con seis ofertas detrás: el conteo de versiones lo trae
    // cada negocio, no se deriva de la lista.
    expect(negocios.length, 3);
    expect(negocios.first.ofertasCount, 2);
    expect(negocios.first.ofertasIds, [1, 101]);
  });

  test('buscador y filtro de etapa recortan lo visible', () async {
    final container = makeClientContainer(
      overrides: [pipelinePortProvider.overrideWithValue(FakePipelinePort())],
    );
    await container.read(pipelineProvider.future);

    expect(container.read(negociosVisiblesProvider).length, 3);

    container.read(busquedaProspectoProvider.notifier).state = 'beto';
    expect(container.read(negociosVisiblesProvider).map((n) => n.idOferta), [2]);

    container.read(busquedaProspectoProvider.notifier).state = '';
    container.read(etapaFiltroProvider.notifier).state = 'perdido';
    expect(container.read(negociosVisiblesProvider).map((n) => n.idOferta), [3]);

    // El tablero pinta todas las columnas: no aplica el filtro de etapa.
    expect(container.read(negociosBuscadosProvider).length, 3);
  });

  test('los conteos y el aviso se cuentan por negocio', () async {
    final container = makeClientContainer(
      overrides: [pipelinePortProvider.overrideWithValue(FakePipelinePort())],
    );
    await container.read(pipelineProvider.future);

    expect(container.read(conteoPorEtapaProvider), {
      'negociando': 1,
      'oferta_enviada': 1,
      'perdido': 1,
    });
    expect(container.read(cerradosSinRazonProvider).map((n) => n.idOferta), [3]);
  });

  test('un negocio sin pipeline no se mueve y no llega al servidor', () async {
    final port = FakePipelinePort();
    final container = makeClientContainer(
      overrides: [pipelinePortProvider.overrideWithValue(port)],
    );
    final datos = await container.read(pipelineProvider.future);

    final sinPipeline = datos.negocios.firstWhere((n) => n.idNegocio == null);
    expect(sinPipeline.sePuedeMover, isFalse);

    await expectLater(
      container.read(pipelineAccionesProvider).moverEtapa(
        sinPipeline,
        datos.etapaDe('negociando')!,
      ),
      throwsA(
        isA<AccionNoDisponible>().having(
          (e) => e.motivo,
          'motivo',
          'negocio_sin_pipeline',
        ),
      ),
    );

    // Ni la llamada ni el movimiento optimista: la tarjeta no se mueve de columna.
    expect(port.log, ['negocios']);
    expect(container.read(etapasOptimistasProvider), isEmpty);
    expect(
      mensajeDeError(AccionNoDisponible('negocio_sin_pipeline')),
      contains('no se puede mover de etapa'),
    );
  });

  test('una etapa automática no se asigna a mano', () async {
    final port = FakePipelinePort();
    final container = makeClientContainer(
      overrides: [pipelinePortProvider.overrideWithValue(port)],
    );
    final datos = await container.read(pipelineProvider.future);
    final movible = datos.negocios.firstWhere((n) => n.idNegocio != null);

    await expectLater(
      container.read(pipelineAccionesProvider).moverEtapa(
        movible,
        datos.etapaDe('oferta_enviada')!,
      ),
      throwsA(
        isA<AccionNoDisponible>().having(
          (e) => e.motivo,
          'motivo',
          'etapa_automatica',
        ),
      ),
    );
    expect(port.log, ['negocios']);
  });

  test('mover una etapa manual llega al servidor con el id del negocio', () async {
    final port = FakePipelinePort();
    final container = makeClientContainer(
      overrides: [pipelinePortProvider.overrideWithValue(port)],
    );
    final datos = await container.read(pipelineProvider.future);
    final movible = datos.negocios.firstWhere((n) => n.idNegocio == 77);

    await container.read(pipelineAccionesProvider).moverEtapa(
      movible,
      datos.etapaDe('perdido')!,
    );

    expect(port.log, ['negocios', 'moverEtapa:77:perdido']);
  });

  test('si el servidor rechaza el movimiento, la etapa se revierte', () async {
    final port = FakePipelinePort();
    final container = makeClientContainer(
      overrides: [pipelinePortProvider.overrideWithValue(port)],
    );
    final datos = await container.read(pipelineProvider.future);
    final movible = datos.negocios.firstWhere((n) => n.idNegocio == 77);

    port.proximoFallo = ApiError(503, 'pipeline_unavailable');
    await expectLater(
      container.read(pipelineAccionesProvider).moverEtapa(
        movible,
        datos.etapaDe('perdido')!,
      ),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', 'pipeline_unavailable'),
      ),
    );

    // La etapa optimista vuelve a la de origen: la tarjeta regresa a su columna.
    expect(container.read(etapasOptimistasProvider), {1: 'negociando'});
    expect(
      container.read(negociosProvider).firstWhere((n) => n.idOferta == 1).etapa,
      'negociando',
    );
  });

  test('registrar la razón devuelve el motivo con nombre', () async {
    final port = FakePipelinePort();
    final container = makeClientContainer(
      overrides: [pipelinePortProvider.overrideWithValue(port)],
    );
    await container.read(pipelineProvider.future);

    final razon = await container.read(pipelineAccionesProvider).registrarRazon(
      idOferta: 3,
      idMotivo: 1,
      comentario: 'Pedía 15% menos',
    );

    expect(razon.motivoNombre, 'Está fuera de presupuesto');
    expect(razon.comentario, 'Pedía 15% menos');
    expect(port.log.last, 'registrarRazonNoAvance:3:1');
  });

  test('el esquema comunica el resultado real de los acuerdos', () async {
    final port = FakePipelinePort()..acuerdosRegenerados = false;
    final container = makeClientContainer(
      overrides: [pipelinePortProvider.overrideWithValue(port)],
    );
    await container.read(pipelineProvider.future);

    final cambio = await container.read(pipelineAccionesProvider).elegirEsquema(
      idOferta: 1,
      idEsquema: 40,
    );

    expect(cambio.acuerdosRegenerados, isFalse);
    expect(mensajeDeEsquema(cambio), contains('no se regeneraron'));
    expect(
      mensajeDeEsquema(
        const CambioEsquema(idEsquemaSeleccionado: 40),
      ),
      contains('no había acuerdos que regenerar'),
    );
  });

  test('un fallo del puerto sale como ApiError por el provider', () async {
    final port = FakePipelinePort()..proximoFallo = ApiError(403, 'not_owner');
    final container = makeClientContainer(
      overrides: [pipelinePortProvider.overrideWithValue(port)],
    );

    await expectLater(
      container.read(pipelineProvider.future),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'not_owner')),
    );
    expect(mensajeDeError(ApiError(403, 'not_owner')), contains('otro agente'));
    expect(
      mensajeDeError(ApiError(0, 'network_error')),
      contains('Sin conexión'),
    );
  });

  test('el detalle de la oferta calcula los importes del esquema', () async {
    final container = makeClientContainer(
      overrides: [pipelinePortProvider.overrideWithValue(FakePipelinePort())],
    );

    final detalle = await container.read(detalleOfertaProvider(1).future);
    final esquema = detalle.esquemas.single;
    final base = detalle.propiedad!.precioLista!;

    // 5% de descuento sobre 1,000,000.
    expect(esquema.precioFinal(base), 950000);
    expect(esquema.enganche(base), 190000);
    expect(esquema.mensualidad(base), closeTo(23750, 0.01));
    expect(detalle.totalAdicionales, 250000);
    expect(detalle.adicionales.single.nombre, 'E-3');
  });

  test('el modo presentación enmascara sin tocar el dato', () {
    expect(mascara('Ana Ruiz', activo: true), kMascaraPresentacion);
    expect(mascara(r'$1,000,000.00', activo: true), kMascaraPresentacion);
    expect(mascara('Ana Ruiz', activo: false), 'Ana Ruiz');
    expect(mascara(null, activo: false), '-');
  });

  test('cambiar la impersonación reconstruye el puerto con el id', () {
    final container = makeClientContainer();

    final antes = container.read(pipelinePortProvider) as PipelineAdapter;
    expect(antes.impersonate, isNull);

    container.read(impersonationProvider).select(7, 'Alex', 'alex@x.com');
    final durante = container.read(pipelinePortProvider) as PipelineAdapter;
    expect(durante.impersonate, 7);

    container.read(impersonationProvider).clear();
    expect(
      (container.read(pipelinePortProvider) as PipelineAdapter).impersonate,
      isNull,
    );
  });
}
