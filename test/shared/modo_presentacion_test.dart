import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sozu_agente_app/shared/providers/modo_presentacion_provider.dart';

/// Modo presentación: el default y la persistencia.
///
/// El default es lo crítico de la tanda: si algún día arranca apagado, un agente
/// enseña la app a un prospecto con sus comisiones a la vista sin haber tocado
/// nada.
void main() {
  // `SharedPreferences.setMockInitialValues` necesita el binding de servicios.
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer contenedor() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('arranca ACTIVO cuando no hay preferencia guardada', () async {
    SharedPreferences.setMockInitialValues({});
    final modo = contenedor().read(modoPresentacionProvider);

    expect(modo.activo, isTrue);
    // La carga del disco es asíncrona: sin preferencia guardada no debe apagarlo.
    await Future<void>.delayed(Duration.zero);
    expect(modo.activo, isTrue);
  });

  test('respeta la preferencia guardada de la sesión anterior', () async {
    SharedPreferences.setMockInitialValues({
      'sozu_agente_modo_presentacion': false,
    });
    final modo = contenedor().read(modoPresentacionProvider);

    await Future<void>.delayed(Duration.zero);
    expect(modo.activo, isFalse);
  });

  test('alternar avisa a la UI y persiste la elección', () async {
    SharedPreferences.setMockInitialValues({});
    final modo = contenedor().read(modoPresentacionProvider);
    var avisos = 0;
    modo.addListener(() => avisos++);

    await modo.alternar();

    expect(modo.activo, isFalse);
    expect(avisos, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('sozu_agente_modo_presentacion'), isFalse);
  });

  test('establecer el mismo valor no avisa ni escribe', () async {
    SharedPreferences.setMockInitialValues({});
    final modo = contenedor().read(modoPresentacionProvider);
    var avisos = 0;
    modo.addListener(() => avisos++);

    await modo.establecer(true);

    expect(avisos, 0);
  });

  test('enmascara con activo y deja pasar el valor con inactivo', () async {
    SharedPreferences.setMockInitialValues({});
    final modo = contenedor().read(modoPresentacionProvider);

    expect(modo.enmascarar(r'$125,000.50'), ModoPresentacion.mascara);
    expect(modo.enmascararOpcional('ana@sozu.com'),
        ModoPresentacion.mascara);
    // Un campo sin dato se queda sin dato: no hay nada que ocultar.
    expect(modo.enmascararOpcional(null), isNull);
    expect(modo.enmascararOpcional(''), '');

    await modo.establecer(false);
    expect(modo.enmascarar(r'$125,000.50'), r'$125,000.50');
    expect(modo.enmascararOpcional('ana@sozu.com'), 'ana@sozu.com');
  });
}
