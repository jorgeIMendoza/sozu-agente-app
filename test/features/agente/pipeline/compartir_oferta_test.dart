import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/pipeline/adapters/pipeline_adapter.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/compartir_negocio.dart';
import 'package:sozu_agente_app/features/agente/pipeline/providers/pipeline_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/shared/adapters/edge_function.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import 'fake_pipeline_port.dart';

/// Llamador de Edge Functions que solo se queda con el cuerpo. Deja probar el
/// adaptador REAL sin backend: `EdgeFunctions` toca el singleton de Supabase
/// dentro de `call`, y aquí `call` se reemplaza completo.
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

/// Compartir la oferta es el camino principal de venta: el correo desde la
/// plataforma y el PDF viajan a `agente-pipeline`, así que lo que se fija aquí
/// es el contrato del cuerpo, la traducción de sus errores y que la hoja no se
/// cierre dejando al agente sin saber qué pasó.
void main() {
  group('cuerpo que sale a agente-pipeline', () {
    test('adjuntar_pdf viaja como booleano exacto, no como texto', () async {
      final fn = _FnEspia(
        respuesta: const {
          'enviado': true,
          'email': 'ana@x.com',
          'con_pdf': true,
        },
      );
      final adapter = PipelineAdapter.conLlamador(fn);

      final envio = await adapter.enviarOfertaPorCorreo(
        idOferta: 91,
        email: '  ana@x.com  ',
        adjuntarPdf: true,
      );

      expect(fn.ultimoCuerpo, isNotNull);
      expect(fn.ultimoCuerpo!['action'], 'enviar_oferta_email');
      expect(fn.ultimoCuerpo!['id_oferta'], 91);
      // El servidor compara con `=== true`: un "true" de texto o un 1 se leen
      // como "sin adjunto" y el agente nunca sabría por qué no llegó el PDF.
      expect(fn.ultimoCuerpo!['adjuntar_pdf'], isA<bool>());
      expect(fn.ultimoCuerpo!['adjuntar_pdf'], isTrue);
      // El correo se recorta antes de salir: el servidor exige que traiga `@`.
      expect(fn.ultimoCuerpo!['email'], 'ana@x.com');
      expect(envio.conPdf, isTrue);
    });

    test('sin adjunto el booleano sigue siendo booleano', () async {
      final fn = _FnEspia(respuesta: const {'enviado': true});
      await PipelineAdapter.conLlamador(
        fn,
      ).enviarOfertaPorCorreo(idOferta: 91, email: 'ana@x.com');

      expect(fn.ultimoCuerpo!['adjuntar_pdf'], isA<bool>());
      expect(fn.ultimoCuerpo!['adjuntar_pdf'], isFalse);
    });

    test(
      'el PDF se pide por id y llega con su nombre y su caducidad',
      () async {
        final fn = _FnEspia(
          respuesta: const {
            'url': 'https://cdn/ofertas_temp/O_91.pdf',
            'nombre_archivo': 'O_91_V-503.pdf',
            'expira_en_segundos': 60,
          },
        );

        final pdf = await PipelineAdapter.conLlamador(fn).pdfDeOferta(91);

        expect(fn.ultimoCuerpo, {'action': 'pdf_oferta', 'id_oferta': 91});
        expect(pdf.url, 'https://cdn/ofertas_temp/O_91.pdf');
        expect(pdf.nombreArchivo, 'O_91_V-503.pdf');
        expect(pdf.expiraEnSegundos, 60);
      },
    );

    test('sin nombre de archivo queda un nombre usable', () async {
      final fn = _FnEspia(respuesta: const {'url': 'https://cdn/x.pdf'});
      final pdf = await PipelineAdapter.conLlamador(fn).pdfDeOferta(91);
      expect(pdf.nombreArchivo, 'oferta.pdf');
    });
  });

  group('traducción de los errores de los dos canales', () {
    test('email_invalido dice que revise el correo', () {
      final msg = mensajeDeError(ApiError(400, 'email_invalido'));
      expect(msg, contains('Ese correo no es válido'));
      expect(msg, contains('vuelve a enviarlo'));
    });

    test('pdf_failed ofrece el siguiente paso: compartir el link', () {
      final msg = mensajeDeError(ApiError(502, 'pdf_failed'));
      expect(msg, contains('No se pudo generar el PDF'));
      expect(msg, contains('link del cliente'));
    });

    test('email_failed manda al canal que sí funciona', () {
      expect(
        mensajeDeError(ApiError(502, 'email_failed')),
        contains('WhatsApp'),
      );
    });
  });

  group('la hoja de compartir', () {
    /// Abre la hoja de verdad, con el mismo camino que la pantalla: un botón
    /// que llama a [mostrarCompartirOferta].
    Future<void> abrirHoja(
      WidgetTester tester,
      FakePipelinePort port, {
      String? email = 'ana@x.com',
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(420, 1600);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: clientWidgetOverrides(
            overrides: [pipelinePortProvider.overrideWithValue(port)],
          ),
          child: MaterialApp(
            theme: sozuLightTheme(),
            builder: (context, child) =>
                SozuAdaptiveTokens(child: child ?? const SizedBox()),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => mostrarCompartirOferta(
                    ctx,
                    idOferta: 91,
                    titulo: 'O-000091 · A-1',
                    urlCliente: 'https://admin.sozu.com/oferta/O-000091/tok',
                    urlPreview: 'https://admin.sozu.com/oferta/O-000091',
                    mensaje: 'Hola Ana, aquí está tu oferta',
                    email: email,
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

    Future<void> pulsar(WidgetTester tester, String etiqueta) async {
      final boton = find.text(etiqueta);
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
    }

    testWidgets('ofrece los cuatro canales y ya no manda al portal web', (
      tester,
    ) async {
      await abrirHoja(tester, FakePipelinePort());

      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Copiar el link del cliente'), findsOneWidget);
      expect(find.text('Enviar desde la plataforma'), findsOneWidget);
      expect(find.text('Descargar el PDF de la oferta'), findsOneWidget);
      // El correo del prospecto llega precargado y editable.
      expect(find.text('ana@x.com'), findsOneWidget);
      expect(find.textContaining('desde el portal web'), findsNothing);
    });

    testWidgets('la casilla manda adjuntar_pdf como booleano al puerto', (
      tester,
    ) async {
      final port = FakePipelinePort();
      await abrirHoja(tester, port);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await pulsar(tester, 'Enviar desde la plataforma');
      await tester.pumpAndSettle();

      expect(port.ultimoAdjuntarPdf, isTrue);
      expect(port.ultimoDestinatario, 'ana@x.com');
      expect(find.textContaining('con el PDF adjunto'), findsOneWidget);
    });

    testWidgets('sin tocar la casilla el envío va sin adjunto', (tester) async {
      final port = FakePipelinePort();
      await abrirHoja(tester, port);

      await pulsar(tester, 'Enviar desde la plataforma');
      await tester.pumpAndSettle();

      expect(port.ultimoAdjuntarPdf, isFalse);
      expect(find.text('Oferta enviada por correo.'), findsOneWidget);
    });

    testWidgets(
      'el correo muestra el estado de carga y el error SIN cerrar la hoja',
      (tester) async {
        final port = FakePipelinePort();
        final compuerta = Completer<void>();
        port.compuerta = compuerta;
        port.proximoFallo = ApiError(400, 'email_invalido');

        await abrirHoja(tester, port);
        await pulsar(tester, 'Enviar desde la plataforma');
        await tester.pump();

        // Mientras el servidor responde: la hoja sigue abierta y el botón dice
        // que está trabajando.
        expect(find.text('Enviando el correo...'), findsOneWidget);
        expect(find.text('Compartir la oferta'), findsOneWidget);

        compuerta.complete();
        await tester.pumpAndSettle();

        expect(find.text('Enviando el correo...'), findsNothing);
        expect(find.textContaining('Ese correo no es válido'), findsOneWidget);
        // Lo importante: el error se lee dentro de la hoja, que no se fue.
        expect(find.text('Compartir la oferta'), findsOneWidget);
        expect(find.text('Enviar desde la plataforma'), findsOneWidget);
      },
    );

    testWidgets('el PDF muestra el estado de carga y su error en la hoja', (
      tester,
    ) async {
      final port = FakePipelinePort();
      final compuerta = Completer<void>();
      port.compuerta = compuerta;
      port.proximoFallo = ApiError(502, 'pdf_failed');

      await abrirHoja(tester, port);
      await pulsar(tester, 'Descargar el PDF de la oferta');
      await tester.pump();

      expect(find.text('Generando el PDF...'), findsOneWidget);
      expect(find.text('Compartir la oferta'), findsOneWidget);

      compuerta.complete();
      await tester.pumpAndSettle();

      expect(find.text('Generando el PDF...'), findsNothing);
      expect(find.textContaining('No se pudo generar el PDF'), findsOneWidget);
      expect(find.text('Compartir la oferta'), findsOneWidget);
    });

    testWidgets('sin correo capturado no se gasta una llamada al servidor', (
      tester,
    ) async {
      final port = FakePipelinePort();
      await abrirHoja(tester, port, email: null);

      await pulsar(tester, 'Enviar desde la plataforma');
      await tester.pumpAndSettle();

      expect(port.log, isEmpty);
      expect(
        find.textContaining('Captura el correo del prospecto'),
        findsOneWidget,
      );
    });
  });
}
