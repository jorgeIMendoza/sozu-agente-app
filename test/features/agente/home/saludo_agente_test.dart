import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/home/components/modo_presentacion_boton.dart';
import 'package:sozu_agente_app/features/agente/home/components/saludo_agente.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Encabezado de Inicio: el sello de verificación, el último acceso con hora y
/// la ausencia del interruptor de presentación (lo pinta la barra superior; aquí
/// salía dos veces en teléfono).
void main() {
  Future<void> pintar(
    WidgetTester tester, {
    bool? verificado,
    DateTime? ultimoAcceso,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: Scaffold(
            body: SaludoAgente(
              nombre: 'Ana Torres',
              rol: 'Agente Inmobiliario',
              propiedadesActivas: '3',
              ultimoAcceso: ultimoAcceso,
              verificado: verificado,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('etiquetaUltimoAcceso', () {
    test('sin dato no dice nada', () {
      expect(etiquetaUltimoAcceso(null), '');
    });

    test('hoy lleva la hora, no la fecha', () {
      final ahora = DateTime.now();
      final hoy = DateTime(ahora.year, ahora.month, ahora.day, 15, 20);
      expect(etiquetaUltimoAcceso(hoy), 'Hoy 3:20 pm');
    });

    test('otro día lleva fecha Y hora, como la web', () {
      final etiqueta = etiquetaUltimoAcceso(DateTime(2026, 2, 11, 15, 20));
      expect(etiqueta, '11 feb 2026 3:20 pm');
    });

    test('la medianoche se lee 12:00 am y el mediodía 12:00 pm', () {
      expect(
        etiquetaUltimoAcceso(DateTime(2026, 2, 11)),
        '11 feb 2026 12:00 am',
      );
      expect(
        etiquetaUltimoAcceso(DateTime(2026, 2, 11, 12)),
        '11 feb 2026 12:00 pm',
      );
    });
  });

  testWidgets('el saludo NO monta el interruptor de presentación', (
    tester,
  ) async {
    await pintar(tester);

    expect(find.text('Ana Torres'), findsOneWidget);
    // Lo pinta PortalTopBar en móvil y el shell en web: montarlo aquí lo
    // duplicaba en pantalla angosta.
    expect(find.byType(ModoPresentacionBoton), findsNothing);
  });

  testWidgets('sin dato de verificación no hay insignia', (tester) async {
    await pintar(tester);

    expect(find.text('Verificado'), findsNothing);
    expect(find.text('No verificado'), findsNothing);
  });

  testWidgets('al 100% dice Verificado; abajo, No verificado', (tester) async {
    await pintar(tester, verificado: true);
    expect(find.text('Verificado'), findsOneWidget);

    await pintar(tester, verificado: false);
    expect(find.text('No verificado'), findsOneWidget);
  });

  testWidgets('el último acceso se pinta en la línea de metadatos', (
    tester,
  ) async {
    await pintar(tester, ultimoAcceso: DateTime(2026, 2, 11, 15, 20));

    expect(find.text('Último acceso: 11 feb 2026 3:20 pm'), findsOneWidget);
  });
}
