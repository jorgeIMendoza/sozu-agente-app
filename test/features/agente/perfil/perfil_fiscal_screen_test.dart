import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/screens/perfil_detalle_screens.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import 'fake_perfil_agente_port.dart';

/// El capturador fiscal se OCULTA al agente dependiente en vez de deshabilitarse:
/// esos datos los lleva su inmobiliaria y `guardar_fiscal` responde
/// `403 forbidden_field`, así que ofrecer el botón solo lo lleva a un error que
/// no puede resolver.
void main() {
  SesionAgente sesionDependiente() => const SesionAgente(
    identidad: IdentidadAgente(
      email: 'alex@sozu.com',
      esDependiente: true,
      inmobiliariaNombre: 'Grupo Inmobiliario Norte',
    ),
    accesoTotal: true,
    restricciones: Restricciones(
      soloLectura: {
        'fiscal': 'La administra Grupo Inmobiliario Norte',
        'banco': 'La administra Grupo Inmobiliario Norte',
      },
    ),
  );

  SesionAgente sesionIndependiente() => const SesionAgente(
    identidad: IdentidadAgente(email: 'alex@sozu.com'),
    accesoTotal: true,
  );

  Future<void> pump(
    WidgetTester tester, {
    required SesionAgente sesion,
    required PerfilAgente Function() perfil,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 2600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [
            sesionProvider.overrideWith((ref) => Future.value(sesion)),
            perfilAgentePortProvider.overrideWithValue(
              FakePerfilAgentePort(perfil: perfil()),
            ),
          ],
        ),
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: const PerfilFiscalScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el agente independiente puede editar su información fiscal', (
    tester,
  ) async {
    await pump(tester, sesion: sesionIndependiente(), perfil: perfilDePrueba);

    expect(find.widgetWithText(SButton, 'Editar'), findsOneWidget);
  });

  testWidgets('el dependiente NO ve el botón de editar', (tester) async {
    await pump(
      tester,
      sesion: sesionDependiente(),
      perfil: perfilDependienteDePrueba,
    );

    expect(find.widgetWithText(SButton, 'Editar'), findsNothing);
    // Y sí ve por qué: un campo gris sin explicación se reporta como bug.
    expect(
      find.textContaining('La administra Grupo Inmobiliario Norte'),
      findsWidgets,
    );
  });
}
