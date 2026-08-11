import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_agente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

import 'fake_auth_port.dart';

/// Lo que fija este archivo es que `AuthController` funciona contra el PUERTO,
/// no contra Supabase: todo corre con [FakeAuthPort] y ni un test inicializa
/// el backend. Antes esto era imposible (ver ADR 0002 §1.1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Perfil que SÍ pasa el gate del portal (`PortalAccess.allows`): un agente
  /// inmobiliario (rol 3). Con el perfil de Cliente que traía el app anterior,
  /// `hasPortalAccess` es false y el controller cierra la sesión.
  const agenteProfile = UserProfile(
    displayName: 'Agente de Prueba',
    email: 'cliente@sozu.com',
    roleId: 3,
    roleName: 'Agente Inmobiliario',
    personId: 7,
  );

  /// BiometricService lee secure storage desde `_init` (en tests
  /// `defaultTargetPlatform` es Android); `null` = "no hay biometría guardada".
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  /// Construye el controller y deja terminar el `_init` asíncrono.
  Future<AuthController> makeController(FakeAuthPort port) async {
    final controller = AuthController(port);
    await pumpEventQueue();
    return controller;
  }

  test('arranca sin sesión: listo y deslogueado', () async {
    final port = FakeAuthPort();
    final controller = await makeController(port);

    expect(controller.isLoading, isFalse);
    expect(controller.session, isNull);
    expect(controller.profile, isNull);
  });

  test('signIn correcto: sesión viva y perfil cargado', () async {
    final port = FakeAuthPort(profileRow: agenteProfile);
    final controller = await makeController(port);

    await controller.signIn('cliente@sozu.com', 'secreta123');
    await pumpEventQueue();

    expect(controller.session?.userId, 'user-de-prueba');
    expect(controller.profile?.roleName, 'Agente Inmobiliario');
    expect(controller.hasPortalAccess, isTrue);
    expect(controller.locked, isFalse);
  });

  test('signIn con contraseña equivocada lanza AuthError traducible', () async {
    final port = FakeAuthPort(profileRow: agenteProfile);
    final controller = await makeController(port);

    Object? error;
    try {
      await controller.signIn('cliente@sozu.com', 'incorrecta');
    } catch (e) {
      error = e;
    }

    expect(error, isA<AuthError>());
    expect(
      AuthController.signInErrorMessage(error!),
      'Correo o contraseña incorrectos.',
    );
    expect(controller.session, isNull);
  });

  test('signInErrorMessage distingue límite de intentos y red caída', () {
    expect(
      AuthController.signInErrorMessage(AuthError(AuthFailure.tooManyAttempts)),
      'Demasiados intentos. Espera un minuto y vuelve a probar.',
    );
    expect(
      AuthController.signInErrorMessage(AuthError(AuthFailure.network)),
      'No pudimos conectar. Revisa tu conexión e intenta de nuevo.',
    );
    expect(
      AuthController.signInErrorMessage(
        AuthError(AuthFailure.emailNotConfirmed),
      ),
      'Tu correo aún no está confirmado. Revisa tu bandeja.',
    );
    // Sin AuthError no hubo respuesta del servidor: fue la red.
    expect(
      AuthController.signInErrorMessage(Exception('boom')),
      'No pudimos conectar. Revisa tu conexión e intenta de nuevo.',
    );
  });

  test('resetPassword propaga el fallo real: no se traga nada', () async {
    final port = FakeAuthPort();
    final controller = await makeController(port);
    port.nextFailure = AuthFailure.network;

    await expectLater(
      controller.resetPassword('cliente@sozu.com'),
      throwsA(isA<AuthError>()),
    );
    expect(port.log, contains('sendPasswordReset'));
  });

  test('resetPassword propaga el límite de envíos como éxito, no como '
      'error', () async {
    final port = FakeAuthPort();
    final controller = await makeController(port);
    port.nextResetResult = const PasswordResetResult(
      rateLimited: true,
      retryAfterMinutes: 15,
    );

    final result = await controller.resetPassword('cliente@sozu.com');

    expect(result.rateLimited, isTrue);
    expect(result.retryAfterMinutes, 15);
  });

  test('resetPasswordErrorMessage distingue red y límite de solicitudes', () {
    expect(
      AuthController.resetPasswordErrorMessage(
        AuthError(AuthFailure.tooManyAttempts),
      ),
      'Demasiadas solicitudes. Espera unos minutos y vuelve a intentar.',
    );
    expect(
      AuthController.resetPasswordErrorMessage(AuthError(AuthFailure.network)),
      'No pudimos conectar. Revisa tu conexión e intenta de nuevo.',
    );
    expect(
      AuthController.resetPasswordErrorMessage(AuthError(AuthFailure.unknown)),
      'No pudimos enviar el correo. Intenta de nuevo o escribe a soporte.',
    );
  });

  test('changePasswordErrorMessage explica los rechazos del backend que la '
      'checklist no puede anticipar', () {
    // Los dos son 422 y antes caían en "revisa que cumpla los requisitos", con
    // las cinco reglas en verde: el usuario reintentaba lo mismo.
    expect(
      AuthController.changePasswordErrorMessage(
        AuthError(AuthFailure.samePassword),
      ),
      'Esa ya es tu contraseña actual. Elige una distinta.',
    );
    expect(
      AuthController.changePasswordErrorMessage(
        AuthError(AuthFailure.weakPassword),
      ),
      contains('filtraciones'),
    );
  });

  test('changePasswordErrorMessage distingue la contraseña actual', () {
    expect(
      AuthController.changePasswordErrorMessage(WrongCurrentPasswordError()),
      'Tu contraseña actual no es correcta.',
    );
    expect(
      AuthController.changePasswordErrorMessage(
        AuthError(AuthFailure.sessionRevoked),
      ),
      'Tu sesión expiró. Vuelve a iniciar sesión e intenta de nuevo.',
    );
    expect(
      AuthController.changePasswordErrorMessage(AuthError(AuthFailure.network)),
      'No pudimos conectar. Revisa tu conexión e intenta de nuevo.',
    );
  });

  test(
    'changePassword con actual equivocada: Wrong... y NO cambia nada',
    () async {
      final port = FakeAuthPort(profileRow: agenteProfile);
      final controller = await makeController(port);
      await controller.signIn('cliente@sozu.com', 'secreta123');

      await expectLater(
        controller.changePassword('incorrecta', 'NuevaSegura9'),
        throwsA(isA<WrongCurrentPasswordError>()),
      );
      expect(port.log, isNot(contains('updatePassword')));
      expect(port.password, 'secreta123');
    },
  );

  test(
    'changePassword sin red: propaga AuthError, no acusa contraseña mala',
    () async {
      final port = FakeAuthPort(profileRow: agenteProfile);
      final controller = await makeController(port);
      await controller.signIn('cliente@sozu.com', 'secreta123');

      port.nextFailure = AuthFailure.network;
      await expectLater(
        controller.changePassword('secreta123', 'NuevaSegura9'),
        throwsA(
          isA<AuthError>().having(
            (e) => e.reason,
            'reason',
            AuthFailure.network,
          ),
        ),
      );
      expect(port.log, isNot(contains('updatePassword')));
    },
  );

  test(
    'changePassword feliz: verifica, cambia y limpia el flag, en orden',
    () async {
      final port = FakeAuthPort(profileRow: agenteProfile);
      final controller = await makeController(port);
      await controller.signIn('cliente@sozu.com', 'secreta123');
      port.log.clear();

      await controller.changePassword('secreta123', 'NuevaSegura9');

      expect(
        port.log,
        containsAllInOrder([
          'verifyPassword',
          'updatePassword',
          'markPasswordChanged',
        ]),
      );
      expect(port.password, 'NuevaSegura9');
    },
  );

  test('cierre de sesión emitido por el puerto limpia el perfil', () async {
    final port = FakeAuthPort(profileRow: agenteProfile);
    final controller = await makeController(port);
    await controller.signIn('cliente@sozu.com', 'secreta123');
    await pumpEventQueue();
    expect(controller.profile, isNotNull);

    port.emitSession(null);
    await pumpEventQueue();

    expect(controller.session, isNull);
    expect(controller.profile, isNull);
  });

  test('signOut revoca en el servidor vía el puerto', () async {
    final port = FakeAuthPort(profileRow: agenteProfile);
    final controller = await makeController(port);
    await controller.signIn('cliente@sozu.com', 'secreta123');
    await pumpEventQueue();

    await controller.signOut();
    await pumpEventQueue();

    expect(port.log, contains('signOut'));
    expect(controller.session, isNull);
    expect(controller.profile, isNull);
    expect(controller.locked, isFalse);
  });
}
