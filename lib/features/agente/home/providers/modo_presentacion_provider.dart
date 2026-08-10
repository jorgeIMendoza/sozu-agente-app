import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo presentación del Portal del Agente.
///
/// Con el modo activo, lo que el agente no quiere que se lea por encima del
/// hombro — comisiones, montos, nombres y correos de sus clientes — se sustituye
/// por una máscara. El agente enseña la app a un prospecto sentado enfrente:
/// arranca ACTIVO a propósito, porque el descuido que cuesta caro es el de
/// olvidar prenderlo, no el de olvidar apagarlo.
///
/// Es estado del cliente y no del backend: el payload llega completo y lo único
/// que cambia es qué se dibuja. La elección se recuerda entre sesiones.
///
/// Vive en `home` porque Inicio es la primera pantalla que lo necesita;
/// Comisiones lo reutiliza. Si aparece un tercer consumidor, súbelo a
/// `features/agente/providers/`.
class ModoPresentacionController extends ChangeNotifier {
  /// No es dato sensible (es una preferencia de vista): va en
  /// `shared_preferences`, no en el almacenamiento seguro de tokens.
  static const _clave = 'sozu_agente_modo_presentacion';

  /// Seis puntos, como en el portal web: suficientes para que se lea como un
  /// dato oculto y no como un dato vacío.
  static const mascara = '••••••';

  bool _activo = true;

  ModoPresentacionController() {
    _cargar();
  }

  /// true = información sensible oculta.
  bool get activo => _activo;

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    // Sin preferencia guardada se queda en `true`: privacidad primero.
    final guardado = prefs.getBool(_clave);
    if (guardado == null || guardado == _activo) return;
    _activo = guardado;
    notifyListeners();
  }

  Future<void> establecer(bool valor) async {
    if (valor == _activo) return;
    _activo = valor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clave, valor);
  }

  Future<void> alternar() => establecer(!_activo);

  /// [valor] o su máscara, según el modo.
  String enmascarar(String valor) => _activo ? mascara : valor;

  /// Igual que [enmascarar] pero tolera nulos y vacíos: un campo sin dato se
  /// queda vacío en vez de fingir que hay algo oculto detrás.
  String? enmascararOpcional(String? valor) {
    if (valor == null || valor.isEmpty) return valor;
    return enmascarar(valor);
  }
}

final modoPresentacionProvider =
    ChangeNotifierProvider<ModoPresentacionController>(
      (ref) => ModoPresentacionController(),
    );
