import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja_password.dart';
import 'package:sozu_agente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_agente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../../auth/fake_auth_port.dart';

/// El cambio de contraseña del Perfil tiene que DECIR por qué falló: la hoja
/// anterior solo distinguía "contraseña actual incorrecta" y mandaba todo lo
/// demás a un genérico, así que quien tecleaba la contraseña que ya tenía veía
/// "no se pudo" con las cinco palomitas en verde.
void main() {
  const perfil = UserProfile(
    displayName: 'Alex Hernández',
    email: 'alex@sozu.com',
    roleName: 'Agente Inmobiliario',
    roleId: 3,
    personId: 7,
  );

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // BiometricService lee secure storage al construir el controlador; null =
    // "no hay biometría guardada".
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  Future<void> abrir(WidgetTester tester, FakeAuthPort port) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authPortProvider.overrideWithValue(port)],
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => mostrarHojaDePassword(context),
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

  /// Llena los tres campos y toca "Actualizar contraseña".
  Future<void> llenarYGuardar(
    WidgetTester tester, {
    required String actual,
    required String nueva,
  }) async {
    final campos = find.byType(STextField);
    await tester.enterText(campos.at(0), actual);
    await tester.pump();
    await tester.enterText(campos.at(1), nueva);
    await tester.pump();
    await tester.enterText(campos.at(2), nueva);
    await tester.pump();
    await tester.tap(find.widgetWithText(SButton, 'Actualizar contraseña'));
    await tester.pumpAndSettle();
  }

  testWidgets('los tres campos traen el ojo de mostrar/ocultar', (
    tester,
  ) async {
    await abrir(tester, FakeAuthPort(profileRow: perfil));

    expect(find.byType(STextField), findsNWidgets(3));
    // Un ojo por campo: es el sufijo que arma STextField.password.
    expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(3));
  });

  testWidgets('ofrece recuperar la contraseña si no la recuerda', (
    tester,
  ) async {
    await abrir(tester, FakeAuthPort(profileRow: perfil));

    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
  });

  testWidgets('la contraseña actual incorrecta se nombra tal cual', (
    tester,
  ) async {
    final port = FakeAuthPort(profileRow: perfil);
    await abrir(tester, port);

    await llenarYGuardar(tester, actual: 'LaQueNoEs9!', nueva: 'NuevaSegura9!');

    expect(find.text('Tu contraseña actual no es correcta.'), findsOneWidget);
    expect(port.log, isNot(contains('updatePassword')));
  });

  testWidgets('un rechazo de Auth se traduce, no cae al genérico', (
    tester,
  ) async {
    final port = FakeAuthPort(profileRow: perfil)
      ..nextFailure = AuthFailure.samePassword;
    await abrir(tester, port);

    await llenarYGuardar(tester, actual: 'secreta123', nueva: 'NuevaSegura9!');

    expect(
      find.text('Esa ya es tu contraseña actual. Elige una distinta.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Revisa que cumpla los requisitos'),
      findsNothing,
      reason: 'el genérico esconde la causa real',
    );
  });

  testWidgets('repetir la contraseña actual se avisa sin salir a la red', (
    tester,
  ) async {
    final port = FakeAuthPort(profileRow: perfil);
    await abrir(tester, port);

    final campos = find.byType(STextField);
    await tester.enterText(campos.at(0), 'MiSegura9!');
    await tester.pump();
    await tester.enterText(campos.at(1), 'MiSegura9!');
    await tester.pump();
    await tester.enterText(campos.at(2), 'MiSegura9!');
    await tester.pump();

    expect(
      find.text('La nueva contraseña debe ser distinta a la actual.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<SButton>(
            find.widgetWithText(SButton, 'Actualizar contraseña'),
          )
          .onPressed,
      isNull,
    );
    expect(port.log, isEmpty);
  });

  testWidgets('al cambiarla cierra la hoja y lo confirma', (tester) async {
    final port = FakeAuthPort(profileRow: perfil);
    await abrir(tester, port);

    await llenarYGuardar(tester, actual: 'secreta123', nueva: 'NuevaSegura9!');

    expect(port.log, containsAllInOrder(['verifyPassword', 'updatePassword']));
    expect(find.byType(STextField), findsNothing, reason: 'la hoja se cierra');
    expect(find.textContaining('Contraseña actualizada'), findsOneWidget);
  });
}
