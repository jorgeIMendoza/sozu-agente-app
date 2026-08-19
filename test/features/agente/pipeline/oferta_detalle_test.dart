import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/pipeline/components/compartir_negocio.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/oferta_detalle_dialog.dart';
import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/features/agente/pipeline/providers/pipeline_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';

/// El detalle de la oferta: sobre qué precio se calculan los esquemas y qué se
/// enmascara. Los importes son la razón por la que el agente abre esta hoja, así
/// que un número equivocado aquí se cobra mal en la vida real.
void main() {
  const etapa = EtapaPipeline(clave: 'nuevo', nombre: 'Nuevo');

  /// Oferta de PRODUCTO (una bodega): el precio del negocio es el del producto y
  /// `propiedad.precio_lista` es el de la unidad a la que cuelga.
  const bodega = Negocio(
    idOferta: 91,
    folio: 'OP-000091',
    esProducto: true,
    idProducto: 7,
    idPropiedad: 501,
    proyectoNombre: 'Margot',
    unidad: 'B-12',
    precio: 300000,
    etapa: 'nuevo',
    lead: LeadNegocio(
      nombre: 'Ana Ruiz',
      email: 'ana@x.com',
      telefono: '5544332211',
    ),
    urlCliente: 'https://admin.sozu.com/oferta/OP-000091/tok',
    urlPreview: 'https://admin.sozu.com/oferta/OP-000091',
  );

  /// Un solo esquema, 100% de enganche y sin ajuste: el enganche que se pinta ES
  /// la base, así que la prueba señala el precio equivocado sin aritmética.
  OfertaDetalle detalleDe({required bool esProducto}) =>
      OfertaDetalle.fromJson({
        'id_oferta': 91,
        'es_producto': esProducto,
        'folio': esProducto ? 'OP-000091' : 'O-000091',
        // La function devuelve `propiedad` TAMBIÉN en las ofertas de producto,
        // porque la bodega trae `id_propiedad`. Ahí está la trampa.
        'propiedad': {
          'id': 501,
          'numero_propiedad': 'A-1',
          'precio_lista': 5000000,
        },
        'asociados': const [],
        'esquemas': const [
          {
            'id': 40,
            'nombre': 'Contado',
            'porcentaje_enganche': 100,
            'porcentaje_mensualidades': 0,
            'porcentaje_entrega': 0,
            'numero_mensualidades': 1,
            'porcentaje_descuento_aumento': 0,
          },
        ],
        'link_digital': {
          'token': 'tok',
          'url': 'https://admin.sozu.com/oferta/OP-000091/tok',
          'url_preview': 'https://admin.sozu.com/oferta/OP-000091',
        },
        'ya_tiene_esquema': false,
        'id_esquema_pago_seleccionado': null,
      });

  Future<void> pintar(
    WidgetTester tester, {
    required Negocio negocio,
    required OfertaDetalle detalle,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 1400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [
            detalleOfertaProvider.overrideWith((ref, id) async => detalle),
          ],
        ),
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: Scaffold(
            body: OfertaDetalleHoja(
              negocio: negocio,
              etapa: etapa,
              puedeActualizar: true,
              razonesDisponibles: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la oferta de producto cotiza sobre el precio del PRODUCTO', (
    tester,
  ) async {
    await pintar(tester, negocio: bodega, detalle: detalleDe(esProducto: true));

    expect(find.textContaining('Precio del producto'), findsOneWidget);
    expect(find.text(r'$300,000.00'), findsOneWidget);
    // El precio de lista de la unidad a la que cuelga la bodega no aparece en
    // ningún importe: ni como base ni dentro del esquema.
    expect(find.textContaining(r'$5,000,000.00'), findsNothing);
    expect(find.text(r'Enganche: $300,000.00'), findsOneWidget);
    expect(find.text(r'Precio final: $300,000.00'), findsOneWidget);
  });

  testWidgets('la oferta de propiedad cotiza sobre el precio de lista', (
    tester,
  ) async {
    await pintar(
      tester,
      negocio: bodega,
      detalle: detalleDe(esProducto: false),
    );

    expect(find.textContaining('Precio de la unidad'), findsOneWidget);
    expect(find.text(r'$5,000,000.00'), findsOneWidget);
    expect(find.text(r'Enganche: $5,000,000.00'), findsOneWidget);
  });

  testWidgets('el modo presentación tapa al prospecto pero no los importes', (
    tester,
  ) async {
    // El modo arranca ACTIVO: es justo el estado en el que el agente abre el
    // detalle para leer los números.
    await pintar(tester, negocio: bodega, detalle: detalleDe(esProducto: true));

    expect(find.text('Ana Ruiz'), findsNothing);
    expect(find.text('ana@x.com'), findsNothing);
    expect(find.text(kMascaraPresentacion), findsWidgets);
    expect(find.text(r'$300,000.00'), findsOneWidget);
    expect(find.text(r'Enganche: $300,000.00'), findsOneWidget);
  });

  testWidgets('los esquemas se colapsan y se vuelven a abrir', (tester) async {
    await pintar(tester, negocio: bodega, detalle: detalleDe(esProducto: true));

    expect(find.text('Contado'), findsOneWidget);

    // SSectionLabel pinta en mayúsculas: el finder busca lo que se rinde.
    await tester.tap(find.text('ESQUEMAS DE PAGO (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Contado'), findsNothing);

    await tester.tap(find.text('ESQUEMAS DE PAGO (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Contado'), findsOneWidget);
  });

  testWidgets('compartir ofrece WhatsApp y el link de vista previa', (
    tester,
  ) async {
    await pintar(tester, negocio: bodega, detalle: detalleDe(esProducto: true));

    await tester.tap(find.text('Compartir'));
    await tester.pumpAndSettle();

    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Copiar el link del cliente'), findsOneWidget);
    expect(find.text('Copiar el link de vista previa'), findsOneWidget);
    // Correo y PDF no están en el app y la hoja lo dice, en vez de dejar un
    // botón que no hace nada.
    expect(find.textContaining('desde el portal web'), findsOneWidget);
  });

  group('armado del mensaje y de la lada', () {
    test('el mensaje saluda por el primer nombre y cierra con el link', () {
      expect(
        mensajeDeOferta(
          url: 'https://x/of/1',
          nombreLead: 'Ana María Ruiz',
          unidad: 'A-101',
          proyecto: 'Margot',
        ),
        'Hola Ana, aquí está tu oferta digital - A-101 de Margot:\n'
        'https://x/of/1',
      );
    });

    test('sin prospecto ni unidad queda solo el link', () {
      expect(
        mensajeDeOferta(url: 'https://x/of/1'),
        'Aquí está tu oferta digital:\nhttps://x/of/1',
      );
    });

    test('la clave de país se traduce a lada; el dato numérico se respeta', () {
      expect(ladaDeClavePais('MX'), '52');
      expect(ladaDeClavePais('us'), '1');
      expect(ladaDeClavePais('57'), '57');
      expect(ladaDeClavePais(null), '52');
      expect(ladaDeClavePais('XX'), '52');
    });
  });
}
