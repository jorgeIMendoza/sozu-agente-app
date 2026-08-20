import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/comisiones/components/tarjetas_totales.dart';
import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Regresión del layout de los KPIs.
///
/// `TarjetasTotales` es un `Row` con `crossAxisAlignment.stretch`, y la pantalla
/// lo monta como hijo DIRECTO de un `ListView`. En un scroll vertical el hijo
/// recibe alto no acotado, así que estirar contra infinito lanza
/// "BoxConstraints forces an infinite height": la pantalla con datos no pintaba
/// los totales. Venía así desde el port original de las 9 pantallas del portal.
///
/// El arreglo es el `IntrinsicHeight` que envuelve el `Row`. Esta prueba lo fija
/// montándolo en el MISMO contexto que la pantalla real: sin el `ListView` el
/// caso no se reproduce, porque cualquier padre con alto acotado lo tapa.
void main() {
  const totales = TotalesComisiones(cobrado: 125000.5, porCobrar: 48000);

  Widget enListView({required Widget child}) => MaterialApp(
    theme: sozuLightTheme(),
    home: Scaffold(body: ListView(children: [child])),
  );

  testWidgets('dentro de un ListView los totales pintan sin reventar el layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      enListView(
        child: const TarjetasTotales(totales: totales, enmascarar: _sinMascara),
      ),
    );

    // La aserción de verdad: cero excepciones de layout. Antes del arreglo aquí
    // salía "BoxConstraints forces an infinite height".
    expect(tester.takeException(), isNull);
    expect(find.text('TOTAL COBRADO'), findsOneWidget);
    expect(find.text('POR COBRAR'), findsOneWidget);
  });

  testWidgets('las dos tarjetas miden lo mismo de alto', (tester) async {
    await tester.pumpWidget(
      enListView(
        child: const TarjetasTotales(totales: totales, enmascarar: _sinMascara),
      ),
    );

    // Es para lo que estaba el `stretch`: si el IntrinsicHeight se quitara y se
    // cambiara por un `start`, las tarjetas dejarían de igualarse y este caso lo
    // diría, en vez de dejar pasar una regresión visual.
    final alto = tester
        .getSize(
          find
              .ancestor(
                of: find.text('TOTAL COBRADO'),
                matching: find.byType(SCard),
              )
              .first,
        )
        .height;
    final altoPorCobrar = tester
        .getSize(
          find
              .ancestor(
                of: find.text('POR COBRAR'),
                matching: find.byType(SCard),
              )
              .first,
        )
        .height;
    expect(alto, altoPorCobrar);
  });

  testWidgets('el modo presentación tapa las dos cifras', (tester) async {
    await tester.pumpWidget(
      enListView(
        child: const TarjetasTotales(totales: totales, enmascarar: _tapado),
      ),
    );

    expect(find.text(r'$125,000.50'), findsNothing);
    expect(find.text(r'$48,000.00'), findsNothing);
    expect(find.text('••••••'), findsNWidgets(2));
  });
}

String _sinMascara(String v) => v;
String _tapado(String _) => '••••••';
