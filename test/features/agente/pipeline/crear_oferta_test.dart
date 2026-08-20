import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/pipeline/adapters/pipeline_adapter.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/nueva_oferta_hoja.dart';
import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/features/agente/pipeline/providers/pipeline_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/shared/adapters/edge_function.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import 'fake_pipeline_port.dart';

/// Llamador de Edge Functions que solo se queda con el cuerpo, para probar el
/// adaptador REAL sin backend.
class _FnEspia extends EdgeFunctions {
  Map<String, dynamic>? ultimoCuerpo;
  final Map<String, dynamic> respuesta;

  _FnEspia({this.respuesta = const {}});

  @override
  Future<Map<String, dynamic>> call(
    String fn, {
    Map<String, dynamic>? body,
  }) async {
    ultimoCuerpo = body;
    return respuesta;
  }
}

/// Respuesta mínima de `crear_oferta` que sí trae folio.
const _respuestaOk = {'ok': true, 'id_oferta': 45678, 'id_persona_lead': 8901};

/// Cartera de una sola persona: alcanza para que el selector se pinte y la hoja
/// pueda cambiar al modo de captura.
final _cartera = CarteraProspectos(
  prospectos: const [
    Prospecto(
      idPersona: 8901,
      nombre: 'Ana Ruiz',
      email: 'ana@x.com',
      telefono: '5512345678',
      clavePaisTelefono: 'MX',
    ),
  ],
);

/// Cotizar es la última puerta del embudo y escribe: aquí se fija QUÉ sale del
/// app (nunca la identidad del agente ni montos), qué se le dice al agente
/// cuando el servidor lo rechaza, y sobre todo que la app degrade sola mientras
/// `crear_oferta` no esté desplegada.
void main() {
  group('cuerpo que sale a agente-pipeline', () {
    test('con prospecto de la cartera no viaja identidad ni montos', () async {
      final fn = _FnEspia(respuesta: _respuestaOk);

      await PipelineAdapter.conLlamador(
        fn,
      ).crearOferta(idPropiedad: 1234, idEsquemaPago: 57, idPersonaLead: 8901);

      final cuerpo = fn.ultimoCuerpo!;
      expect(cuerpo['action'], 'crear_oferta');
      expect(cuerpo['id_propiedad'], 1234);
      expect(cuerpo['id_esquema_pago'], 57);
      expect(cuerpo['id_persona_lead'], 8901);
      // El servidor deriva al agente del JWT: mandarlo sería cotizar a nombre
      // de otro y quedarse con su comisión.
      for (final prohibida in const [
        'email_creador',
        'email',
        'id_persona',
        'id_persona_duena_lead',
        'auth_user_id',
        'token',
        'clabe',
        'clabe_stp',
        'clabe_stp_tmp_producto',
        'precio',
        'precio_lista',
        'monto',
        'porcentaje_enganche',
        'id_estatus_aprobacion',
        'activo',
        'fecha_generacion',
      ]) {
        expect(
          cuerpo.containsKey(prohibida),
          isFalse,
          reason: '$prohibida no debe viajar en el cuerpo',
        );
      }
      // Y el cuerpo completo es exactamente el contrato, sin campos de más.
      expect(cuerpo.keys.toSet(), {
        'action',
        'id_propiedad',
        'id_esquema_pago',
        'id_persona_lead',
        'crear_link',
        'enviar_email',
        'adjuntar_pdf',
      });
    });

    test('el prospecto capturado excluye a id_persona_lead', () async {
      final fn = _FnEspia(respuesta: _respuestaOk);

      await PipelineAdapter.conLlamador(fn).crearOferta(
        idPropiedad: 1234,
        // Los dos a la vez: el cuerpo solo puede llevar uno o el servidor
        // responde `lead_conflict`.
        idPersonaLead: 8901,
        prospecto: const ProspectoNuevo(
          nombreCompleto: '  Ana Ruiz  ',
          email: ' ana@x.com ',
          telefono: '5512345678',
        ),
      );

      final cuerpo = fn.ultimoCuerpo!;
      expect(cuerpo.containsKey('id_persona_lead'), isFalse);
      final prospecto = cuerpo['prospecto'] as Map<String, dynamic>;
      expect(prospecto['nombre_completo'], 'Ana Ruiz');
      expect(prospecto['email'], 'ana@x.com');
      expect(prospecto['telefono'], '5512345678');
      expect(prospecto['clave_pais_telefono'], 'MX');
      expect(prospecto['tipo_persona'], 'pf');
      // Sin capturar, RFC y CURP viajan en null y no como cadena vacía: el
      // validador del servidor las rechazaría por formato.
      expect(prospecto['rfc'], isNull);
      expect(prospecto['curp'], isNull);
    });

    test('elegir uno de la cartera excluye al prospecto capturado', () async {
      final fn = _FnEspia(respuesta: _respuestaOk);

      await PipelineAdapter.conLlamador(
        fn,
      ).crearOferta(idPropiedad: 1234, idPersonaLead: 8901);

      expect(fn.ultimoCuerpo!.containsKey('prospecto'), isFalse);
      expect(fn.ultimoCuerpo!['id_persona_lead'], 8901);
    });

    test(
      'sin plan de pago el campo se omite, que es null para el servidor',
      () async {
        final fn = _FnEspia(respuesta: _respuestaOk);
        await PipelineAdapter.conLlamador(
          fn,
        ).crearOferta(idPropiedad: 1234, idPersonaLead: 8901);
        expect(fn.ultimoCuerpo!.containsKey('id_esquema_pago'), isFalse);
      },
    );

    test('las banderas de entrega van como booleanos exactos', () async {
      final fn = _FnEspia(respuesta: _respuestaOk);

      await PipelineAdapter.conLlamador(fn).crearOferta(
        idPropiedad: 1234,
        idPersonaLead: 8901,
        crearLink: false,
        enviarEmail: false,
        // Sin correo el adjunto no aplica: el servidor lo ignoraría y la app no
        // debe insinuar que lo mandó.
        adjuntarPdf: true,
      );

      final cuerpo = fn.ultimoCuerpo!;
      expect(cuerpo['crear_link'], isFalse);
      expect(cuerpo['enviar_email'], isFalse);
      expect(cuerpo['adjuntar_pdf'], isA<bool>());
      expect(cuerpo['adjuntar_pdf'], isFalse);
    });

    test('esquemas_producto viaja con las claves en texto', () async {
      final fn = _FnEspia(respuesta: _respuestaOk);

      await PipelineAdapter.conLlamador(fn).crearOferta(
        idPropiedad: 1234,
        idPersonaLead: 8901,
        esquemasProducto: const {412: 91, 413: null},
      );

      expect(fn.ultimoCuerpo!['esquemas_producto'], {'412': 91, '413': null});
    });

    test('sin selección de extras el mapa no se manda', () async {
      final fn = _FnEspia(respuesta: _respuestaOk);
      await PipelineAdapter.conLlamador(
        fn,
      ).crearOferta(idPropiedad: 1234, idPersonaLead: 8901);
      expect(fn.ultimoCuerpo!.containsKey('esquemas_producto'), isFalse);
    });
  });

  group('respuesta de crear_oferta', () {
    test('se lee completa, con extras, avisos y link', () async {
      final fn = _FnEspia(
        respuesta: const {
          'ok': true,
          'id_oferta': 45678,
          'id_persona_lead': 8901,
          'prospecto_creado': true,
          'id_esquema_pago_seleccionado': 57,
          'ofertas_producto': [
            {
              'id_oferta': 45679,
              'id_producto': 412,
              'nombre': 'Bodega B-12',
              'id_esquema_pago_seleccionado': 91,
              'clabe': true,
            },
          ],
          'avisos': ['No se pudo generar la CLABE de estacionamiento "E-3".'],
          'link_digital': {
            'token': 'tok',
            'url': 'https://admin.sozu.com/oferta/O-045678/tok',
            'url_preview': 'https://admin.sozu.com/oferta/O-045678',
          },
          'email_enviado': false,
          'id_negocio': 3312,
          'es_recotizacion': true,
        },
      );

      final creada = await PipelineAdapter.conLlamador(
        fn,
      ).crearOferta(idPropiedad: 1234, idPersonaLead: 8901);

      expect(creada.idOferta, 45678);
      expect(creada.idPersonaLead, 8901);
      expect(creada.prospectoCreado, isTrue);
      expect(creada.esRecotizacion, isTrue);
      expect(creada.idNegocio, 3312);
      expect(creada.ofertasProducto.single.nombre, 'Bodega B-12');
      expect(creada.ofertasProducto.single.tieneClabe, isTrue);
      expect(creada.avisos.single, contains('CLABE'));
      expect(creada.tieneLink, isTrue);
    });

    test('sin link y sin negocio la oferta sigue siendo válida', () async {
      final fn = _FnEspia(
        respuesta: const {
          'ok': true,
          'id_oferta': 45678,
          'id_persona_lead': 8901,
          'link_digital': null,
          'id_negocio': null,
        },
      );

      final creada = await PipelineAdapter.conLlamador(
        fn,
      ).crearOferta(idPropiedad: 1234, idPersonaLead: 8901);

      expect(creada.link, isNull);
      expect(creada.tieneLink, isFalse);
      // null = no se pudo leer el negocio, NO que la oferta no exista.
      expect(creada.idNegocio, isNull);
      expect(creada.idOferta, 45678);
    });

    test('el folio se arma igual que en el pipeline', () {
      expect(folioDeOferta(45678), 'O-045678');
      expect(folioDeOferta(45679, esProducto: true), 'OP-045679');
    });
  });

  group('degradación cuando la acción no existe', () {
    test('invalid_action se reconoce y manda al portal web', () {
      final error = ApiError(400, 'invalid_action');
      expect(esAccionNoDesplegada(error), isTrue);
      expect(mensajeDeErrorNuevaOferta(error), kOfertaSoloEnPortalWeb);
      expect(mensajeDeErrorNuevaOferta(error), contains('portal web'));
      // No se le habla de un fallo: la acción todavía no existe.
      expect(mensajeDeErrorNuevaOferta(error), isNot(contains('Intenta')));
    });

    test('un 200 sin id_oferta se trata como acción inexistente', () async {
      // Es lo que devolvería un `agente-pipeline` viejo que no tiene la rama de
      // `crear_oferta` y cae en la de `lista`.
      final fn = _FnEspia(
        respuesta: const {'etapas': [], 'negocios': [], 'resumen': {}},
      );

      await expectLater(
        PipelineAdapter.conLlamador(
          fn,
        ).crearOferta(idPropiedad: 1234, idPersonaLead: 8901),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'invalid_action'),
        ),
      );
    });

    test('un fallo de red NO se confunde con la acción ausente', () {
      final error = ApiError(0, 'network_error');
      expect(esAccionNoDesplegada(error), isFalse);
      expect(mensajeDeErrorNuevaOferta(error), contains('Sin conexión'));
    });
  });

  group('traducción de los rechazos del servidor', () {
    test('capacitacion_pendiente manda a agendarla', () {
      final error = ApiError(403, 'capacitacion_pendiente');
      final msg = mensajeDeErrorNuevaOferta(error);
      expect(msg, contains('capacitación'));
      expect(msg, contains('Agéndala'));
      // Es lo que enciende el atajo de la hoja.
      expect(esCapacitacionPendiente(error), isTrue);
    });

    test('unidad_no_disponible dice que se apartó y que refresque', () {
      final msg = mensajeDeErrorNuevaOferta(
        ApiError(409, 'unidad_no_disponible'),
      );
      expect(msg, contains('apartar o vender'));
      expect(msg, contains('Refresca el inventario'));
    });

    test('oferta_duplicada dice que ya la generó', () {
      final msg = mensajeDeErrorNuevaOferta(ApiError(409, 'oferta_duplicada'));
      expect(msg, contains('idéntica'));
      expect(msg, contains('pipeline'));
    });

    test('not_owner habla del PROSPECTO, no de la oferta', () {
      final msg = mensajeDeErrorNuevaOferta(ApiError(403, 'not_owner'));
      expect(msg, contains('otro asesor'));
      expect(msg, contains('traspaso'));
      // El mismo código en el resto del pipeline sigue hablando de la oferta.
      expect(mensajeDeError(ApiError(403, 'not_owner')), contains('oferta'));
    });

    test('los demás códigos del alta tienen su siguiente paso', () {
      for (final codigo in const [
        'missing_id',
        'missing_lead',
        'lead_conflict',
        'scheme_mismatch',
        'nombre_invalido',
        'email_invalido',
        'telefono_invalido',
        'rfc_invalido',
        'curp_invalido',
        'tipo_persona_invalido',
        'not_found',
        'proyecto_no_permitido',
        'digital_offer_unavailable',
        'feature_unavailable',
        'internal_error',
      ]) {
        final msg = mensajeDeErrorNuevaOferta(ApiError(400, codigo));
        expect(msg, isNotEmpty, reason: codigo);
        expect(
          msg,
          isNot('No se pudo completar la acción. Intenta de nuevo.'),
          reason: '$codigo se quedó con el mensaje genérico',
        );
      }
    });
  });

  group('la hoja de configuración', () {
    /// Abre la hoja con el mismo camino que la pantalla de unidades, ya en modo
    /// de captura: así el prospecto viaja como `prospecto` y la prueba no
    /// depende del desplegable de la cartera.
    Future<void> abrirHoja(
      WidgetTester tester,
      FakePipelinePort port, {
      VoidCallback? onAgendar,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(420, 2400);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: clientWidgetOverrides(
            overrides: [
              pipelinePortProvider.overrideWithValue(port),
              carteraProspectosProvider.overrideWith((ref) async => _cartera),
            ],
          ),
          child: MaterialApp(
            theme: sozuLightTheme(),
            builder: (context, child) =>
                SozuAdaptiveTokens(child: child ?? const SizedBox()),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => configurarNuevaOferta(
                    ctx,
                    unidad: const UnidadParaOferta(
                      idPropiedad: 1234,
                      etiqueta: 'A-301',
                      desarrollo: 'Margot',
                      precioTotal: 3200000,
                      idEsquemaPago: 57,
                      esquemaNombre: '20-60-20',
                      extras: [
                        ExtraParaOferta(
                          etiqueta: 'Bodega B-12',
                          esBodega: true,
                          costo: 120000,
                        ),
                      ],
                    ),
                    onAgendarCapacitacion: onAgendar ?? () {},
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    /// Cambia al modo de captura y llena los tres campos obligatorios.
    Future<void> capturarProspecto(WidgetTester tester) async {
      await tester.tap(find.text('Capturar aquí'));
      await tester.pumpAndSettle();
      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), 'Ana Ruiz');
      await tester.enterText(campos.at(1), 'ana@x.com');
      await tester.enterText(campos.at(2), '5512345678');
      await tester.pumpAndSettle();
    }

    Future<void> pulsar(WidgetTester tester, String etiqueta) async {
      final boton = find.text(etiqueta);
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();
    }

    testWidgets('reúne lo que el servidor necesita y avisa de los extras', (
      tester,
    ) async {
      await abrirHoja(tester, FakePipelinePort());

      expect(find.text('Configurar la oferta'), findsOneWidget);
      expect(find.text('A-301 · Margot'), findsOneWidget);
      expect(find.text('20-60-20'), findsOneWidget);
      expect(find.text('Bodega B-12'), findsOneWidget);
      expect(find.textContaining('su propia oferta'), findsOneWidget);
      expect(find.text('Generar el link para el cliente'), findsOneWidget);
      expect(find.text('Mandárselo por correo'), findsOneWidget);
      // El adjunto solo aparece con el correo encendido.
      expect(find.text('Adjuntar el PDF de la oferta'), findsNothing);
      // Sin prospecto elegido el botón dice por qué está apagado.
      expect(find.textContaining('Elige al prospecto'), findsOneWidget);
    });

    testWidgets('la acción ausente NO se muestra como error crudo', (
      tester,
    ) async {
      final port = FakePipelinePort()
        ..proximoFallo = ApiError(400, 'invalid_action');

      await abrirHoja(tester, port);
      await capturarProspecto(tester);
      await pulsar(tester, 'Generar la oferta');

      // La hoja no se cierra y el mensaje es el del portal web, no un código.
      expect(find.text('Configurar la oferta'), findsOneWidget);
      expect(find.textContaining('portal web'), findsOneWidget);
      expect(find.textContaining('invalid_action'), findsNothing);
      expect(find.text('Oferta generada'), findsNothing);
    });

    testWidgets('capacitacion_pendiente ofrece el atajo para agendarla', (
      tester,
    ) async {
      var fueAAgendar = false;
      final port = FakePipelinePort()
        ..proximoFallo = ApiError(403, 'capacitacion_pendiente');

      await abrirHoja(tester, port, onAgendar: () => fueAAgendar = true);
      await capturarProspecto(tester);
      await pulsar(tester, 'Generar la oferta');

      expect(find.textContaining('capacitación'), findsWidgets);
      await pulsar(tester, 'Agendar mi capacitación');
      expect(fueAAgendar, isTrue);
    });

    testWidgets('el prospecto capturado viaja como prospecto, no como id', (
      tester,
    ) async {
      final port = FakePipelinePort();
      await abrirHoja(tester, port);
      await capturarProspecto(tester);
      await pulsar(tester, 'Generar la oferta');

      expect(port.ultimaOferta!.idPersonaLead, isNull);
      expect(port.ultimaOferta!.prospecto!.nombreCompleto, 'Ana Ruiz');
      expect(port.ultimaOferta!.idEsquemaPago, 57);
    });

    testWidgets('ya creada muestra el folio y cómo compartirla', (
      tester,
    ) async {
      final port = FakePipelinePort();
      await abrirHoja(tester, port);
      await capturarProspecto(tester);
      await pulsar(tester, 'Generar la oferta');

      expect(find.text('Oferta generada'), findsOneWidget);
      expect(find.text('O-045678'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Copiar el link del cliente'), findsOneWidget);
    });

    testWidgets('los avisos del servidor se pintan tal cual', (tester) async {
      final port = FakePipelinePort()
        ..respuestaCrearOferta = {
          'ok': true,
          'id_oferta': 45678,
          'id_persona_lead': 8901,
          'avisos': [
            'No se pudo generar la CLABE de estacionamiento "E-3": no se creó '
                'su oferta.',
          ],
          'es_recotizacion': true,
          'id_negocio': 3312,
        };

      await abrirHoja(tester, port);
      await capturarProspecto(tester);
      await pulsar(tester, 'Generar la oferta');

      expect(find.textContaining('CLABE de estacionamiento'), findsOneWidget);
      // Una recotización se dice: no es un negocio nuevo.
      expect(find.textContaining('otra versión'), findsOneWidget);
      // Sin link no se ofrece compartir con un link que no existe.
      expect(find.text('Copiar el link del cliente'), findsNothing);
    });
  });
}
