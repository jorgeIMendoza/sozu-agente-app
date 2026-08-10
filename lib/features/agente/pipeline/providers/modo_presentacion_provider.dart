import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo presentación: oculta montos, nombres y correos para poder mostrar la
/// pantalla frente a un cliente.
///
/// Estado de cliente y nada más: no viaja en ninguna petición ni cambia lo que
/// el servidor devuelve. Arranca ACTIVO a propósito -- el agente suele abrir el
/// pipeline delante de alguien, y el default seguro es el que no filtra datos
/// de otros prospectos.
///
/// Se persiste en `shared_preferences` (no es dato sensible; los tokens van en
/// `SecureSessionStorage`). Si otra pantalla del portal lo necesita, este
/// provider sube a `shared/providers/`.
class ModoPresentacion extends ChangeNotifier {
  static const _clave = 'sozu_agente_modo_presentacion';

  bool _activo = true;

  ModoPresentacion() {
    _cargar();
  }

  bool get activo => _activo;

  Future<void> _cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getBool(_clave);
      if (guardado == null || guardado == _activo) return;
      _activo = guardado;
      notifyListeners();
    } catch (_) {
      // Sin almacenamiento disponible (tests sin plugin) se queda el default.
    }
  }

  Future<void> alternar() => cambiar(!_activo);

  Future<void> cambiar(bool valor) async {
    if (valor == _activo) return;
    _activo = valor;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_clave, valor);
    } catch (_) {
      // La preferencia no se persistió; el estado de la sesión ya cambió.
    }
  }
}

final modoPresentacionProvider = ChangeNotifierProvider<ModoPresentacion>(
  (ref) => ModoPresentacion(),
);
