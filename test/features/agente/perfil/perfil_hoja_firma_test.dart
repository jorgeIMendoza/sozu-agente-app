import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja_firma.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// El pad de firma se recorre de verdad: lo que se manda al backend es un data
/// URL de PNG (el backend parte la cadena en la coma y decide el formato por el
/// mime que lleva dentro), y omitir el trazo tiene que ser distinguible de
/// cancelar.
void main() {
  /// Abre la hoja y devuelve cómo leer lo que decidió el agente.
  Future<({TrazoDeFirma? Function() resultado, bool Function() cerro})> abrir(
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.reset);

    TrazoDeFirma? resultado;
    var cerro = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        builder: (context, child) =>
            SozuAdaptiveTokens(child: child ?? const SizedBox()),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await mostrarHojaDeFirma(context);
                cerro = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return (resultado: () => resultado, cerro: () => cerro);
  }

  /// Arrastra sobre el recuadro para dejar un trazo.
  Future<void> trazar(WidgetTester tester) async {
    final centro = tester.getCenter(find.byKey(padDeFirmaKey));
    final gesto = await tester.startGesture(centro - const Offset(60, 0));
    await gesto.moveBy(const Offset(40, 20));
    await gesto.moveBy(const Offset(40, -20));
    await gesto.up();
    await tester.pump();
  }

  testWidgets('sin trazo no se puede usar la firma', (tester) async {
    await abrir(tester);

    expect(
      tester
          .widget<SButton>(find.widgetWithText(SButton, 'Usar esta firma'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('el trazo habilita el guardado y sale como data URL de PNG', (
    tester,
  ) async {
    final hoja = await abrir(tester);
    await trazar(tester);

    expect(
      tester
          .widget<SButton>(find.widgetWithText(SButton, 'Usar esta firma'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(SButton, 'Usar esta firma'));
    await tester.pump();
    // La rasterización a PNG es trabajo real del motor: sin `runAsync` la
    // exportación se queda colgada en el reloj falso del test.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(hoja.cerro(), isTrue);
    expect(hoja.resultado()?.pngDataUrl, startsWith('data:image/png;base64,'));
  });

  testWidgets('"Firmar sin trazo" no es lo mismo que cancelar', (tester) async {
    final hoja = await abrir(tester);

    await tester.tap(find.widgetWithText(SButton, 'Firmar sin trazo'));
    await tester.pumpAndSettle();

    expect(hoja.cerro(), isTrue);
    expect(hoja.resultado(), isNotNull, reason: 'omitir NO es cancelar');
    expect(hoja.resultado()!.pngDataUrl, isNull);
  });

  testWidgets('avisa que el trazo es ilustrativo y no la firma legal', (
    tester,
  ) async {
    await abrir(tester);
    expect(
      find.textContaining('La firma con validez legal es la digital'),
      findsOneWidget,
    );
  });

  testWidgets('"Limpiar" deshabilita otra vez el guardado', (tester) async {
    await abrir(tester);
    await trazar(tester);

    await tester.tap(find.widgetWithText(SButton, 'Limpiar'));
    await tester.pump();

    expect(
      tester
          .widget<SButton>(find.widgetWithText(SButton, 'Usar esta firma'))
          .onPressed,
      isNull,
    );
  });
}
