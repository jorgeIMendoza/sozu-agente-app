import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/comisiones/components/fila_comision.dart';
import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/features/agente/comisiones/providers/comisiones_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import 'fake_comisiones_port.dart';

/// La tarjeta de comisión pintada de verdad: los documentos que faltan se
/// anuncian, el porcentaje de copropiedad conserva sus decimales y el CTA de la
/// factura avisa a la pantalla (que es quien manda la telemetría).
void main() {
  Future<void> pintar(
    WidgetTester tester,
    Comision comision, {
    VoidCallback? onAbrirCargaFactura,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [
            comisionesPortProvider.overrideWithValue(FakeComisionesPort()),
          ],
        ),
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: Scaffold(
            body: SingleChildScrollView(
              child: FilaComision(
                comision: comision,
                onAbrirCargaFactura: onAbrirCargaFactura ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el comprobante que no existe se anuncia', (tester) async {
    await pintar(tester, _comision());

    expect(find.textContaining('Sin comprobante de pago'), findsOneWidget);
    expect(find.text('Comprobante'), findsNothing);
  });

  testWidgets('con comprobante se ofrece verlo y no hay aviso', (tester) async {
    await pintar(
      tester,
      _comision(
        comprobanteUrl: 'https://firmada/comprobante.pdf',
        facturaUrl: 'https://firmada/factura.pdf',
      ),
    );

    expect(find.text('Comprobante'), findsOneWidget);
    expect(find.text('Mi factura'), findsOneWidget);
    expect(find.textContaining('Sin comprobante de pago'), findsNothing);
  });

  testWidgets('el porcentaje de copropiedad no se redondea', (tester) async {
    await pintar(
      tester,
      _comision(
        clientes: const [
          ClienteComision(nombre: 'Ana', porcentaje: 33.33),
          ClienteComision(nombre: 'Luis', porcentaje: 33.33),
          ClienteComision(nombre: 'Sara', porcentaje: 33.34),
        ],
      ),
    );

    await tester.tap(find.text('3 compradores'));
    await tester.pumpAndSettle();

    // Truncado a entero, tres copropietarios se leían como 33% + 33% + 33% y
    // parecía que faltaba un pedazo de la operación.
    expect(find.text('33.33%'), findsNWidgets(2));
    expect(find.text('33.34%'), findsOneWidget);
  });

  testWidgets('el porcentaje entero se imprime sin decimales', (tester) async {
    await pintar(
      tester,
      _comision(
        clientes: const [
          ClienteComision(nombre: 'Ana', porcentaje: 50),
          ClienteComision(nombre: 'Luis', porcentaje: 50),
        ],
      ),
    );

    await tester.tap(find.text('2 compradores'));
    await tester.pumpAndSettle();

    expect(find.text('50%'), findsNWidgets(2));
  });

  testWidgets('abrir la carga de factura avisa a la pantalla', (tester) async {
    var avisos = 0;
    await pintar(
      tester,
      _comision(puedeSubirFactura: true),
      onAbrirCargaFactura: () => avisos++,
    );

    await tester.tap(find.text('Subir factura'));
    await tester.pumpAndSettle();

    expect(avisos, 1);
  });
}

/// Comisión aprobada de una unidad, sin documentos: el caso donde los avisos y
/// el CTA de la factura se deciden.
Comision _comision({
  String? comprobanteUrl,
  String? facturaUrl,
  bool puedeSubirFactura = false,
  List<ClienteComision> clientes = const [
    ClienteComision(nombre: 'Ana López', email: 'ana@example.com'),
  ],
}) => Comision(
  idCuentaCobranza: 101,
  folio: 'CC-000101',
  proyecto: 'Margot',
  propiedad: 'A-301',
  precioFinal: 4200000,
  porcentajeComision: 3,
  montoComision: 126000,
  etapa: EtapaComision.aprobado,
  etapaEtiqueta: 'Aprobado',
  comprobanteUrl: comprobanteUrl,
  facturaUrl: facturaUrl,
  clientes: clientes,
  puedeSubirFactura: puedeSubirFactura,
);
