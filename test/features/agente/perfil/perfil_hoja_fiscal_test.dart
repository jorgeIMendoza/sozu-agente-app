import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja_fiscal.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import 'fake_perfil_agente_port.dart';

/// El capturador fiscal es lo que le permite al agente independiente cerrar su
/// paso fiscal, y de eso dependen sus comisiones. Lo que se fija aquí es el
/// CONTRATO de lo que sale hacia `guardar_fiscal`: el país viaja como cadena y
/// el estado y el municipio como enteros. Mandarlos al revés los deja en null en
/// `personas` y el paso nunca cierra.
///
/// El adaptador no se puede ejercitar directo (construye su llamador sobre el
/// singleton de Supabase), así que el doble del puerto guarda el cuerpo con las
/// MISMAS claves que manda el adaptador.
void main() {
  /// Abre la hoja con el perfil de prueba y devuelve el doble del puerto.
  Future<FakePerfilAgentePort> abrir(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(tester.view.reset);

    final port = FakePerfilAgentePort();
    final perfil = port.perfil;

    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [perfilAgentePortProvider.overrideWithValue(port)],
        ),
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => mostrarHojaDeFiscal(
                  context,
                  fiscal: perfil.fiscal,
                  catalogos: perfil.catalogos,
                  domicilioParticular: perfil.identidad.domicilio,
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
    return port;
  }

  /// Deja la hoja lista para guardar: el domicilio fiscal copiado del particular
  /// (que es el atajo que la web ofrece) y el RFC capturado.
  Future<void> completar(
    WidgetTester tester, {
    String rfc = 'HEAL850101AB1',
  }) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate((w) => w is STextField && w.label == 'RFC'),
      rfc,
    );
    await tester.pumpAndSettle();
  }

  String? errorDelCampo(WidgetTester tester, String label) => tester
      .widget<STextField>(
        find.byWidgetPredicate((w) => w is STextField && w.label == label),
      )
      .errorText;

  testWidgets('el país sale como cadena y los ids del catálogo como enteros', (
    tester,
  ) async {
    final port = await abrir(tester);
    await completar(tester);

    await tester.tap(find.widgetWithText(SButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(port.log, contains('guardarFiscal'));
    final cuerpo = port.ultimoFiscal!;
    expect(cuerpo['rfc'], 'HEAL850101AB1');
    expect(cuerpo['regimen'], '626');
    expect(cuerpo['uso_cfdi'], 'G03');
    expect(cuerpo['direccion_fiscal_id_pais'], isA<String>());
    expect(cuerpo['direccion_fiscal_id_pais'], 'MX');
    expect(cuerpo['direccion_fiscal_id_estado'], isA<int>());
    expect(cuerpo['direccion_fiscal_id_estado'], 9);
    expect(cuerpo['direccion_fiscal_id_municipio'], isA<int>());
    expect(cuerpo['direccion_fiscal_id_municipio'], 15);
    // El único opcional del domicilio: vacío viaja como null, no como ''.
    expect(cuerpo['direccion_fiscal_num_int'], isNull);
  });

  testWidgets('copiar el domicilio particular lo trae completo', (
    tester,
  ) async {
    final port = await abrir(tester);
    await completar(tester);

    await tester.tap(find.widgetWithText(SButton, 'Guardar'));
    await tester.pumpAndSettle();

    final cuerpo = port.ultimoFiscal!;
    expect(cuerpo['direccion_fiscal_calle'], 'Av. Insurgentes Sur');
    expect(cuerpo['direccion_fiscal_num_ext'], '1234');
    expect(cuerpo['direccion_fiscal_colonia'], 'Del Valle');
    expect(cuerpo['direccion_fiscal_codigo_postal'], '03100');
  });

  testWidgets('un RFC con el formato equivocado no gasta el viaje', (
    tester,
  ) async {
    final port = await abrir(tester);
    await completar(tester, rfc: 'XXXX850101AB1');

    await tester.tap(find.widgetWithText(SButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(port.log, isNot(contains('guardarFiscal')));
    expect(find.textContaining('Faltan campos obligatorios'), findsOneWidget);
  });

  testWidgets('rfc_duplicado se pinta JUNTO al campo del RFC', (tester) async {
    final port = await abrir(tester);
    await completar(tester);
    // Se arma después de cargar los catálogos: el fallo se consume en la
    // PRÓXIMA llamada, y la cascada de domicilio también llama al puerto.
    port.proximoFallo = ApiError(409, 'rfc_duplicado');

    await tester.tap(find.widgetWithText(SButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(errorDelCampo(tester, 'RFC'), contains('ya está registrado'));
  });

  testWidgets('rfc_invalido del backend también cae en el campo del RFC', (
    tester,
  ) async {
    // El formato local pasa (13 caracteres bien formados) y el backend lo
    // rechaza igual por el mes o el día embebidos: el aviso no puede quedar
    // flotando lejos del campo.
    final port = await abrir(tester);
    await completar(tester);
    port.proximoFallo = ApiError(400, 'rfc_invalido');

    await tester.tap(find.widgetWithText(SButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(errorDelCampo(tester, 'RFC'), contains('formato oficial'));
  });

  testWidgets('forbidden_field no se atribuye a ningún campo', (tester) async {
    final port = await abrir(tester);
    await completar(tester);
    port.proximoFallo = ApiError(403, 'forbidden_field');

    await tester.tap(find.widgetWithText(SButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(errorDelCampo(tester, 'RFC'), isNull);
    expect(
      find.textContaining('la administra tu inmobiliaria'),
      findsOneWidget,
    );
  });
}
