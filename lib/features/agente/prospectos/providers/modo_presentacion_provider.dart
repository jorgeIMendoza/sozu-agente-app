import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo presentación: oculta nombres, correos, teléfonos y montos de los
/// prospectos para poder mostrar el portal en pantalla ajena (una junta, un
/// showroom, una llamada compartida) sin exponer datos de nadie.
///
/// COMPARTIDO: nace en prospectos porque es donde primero hace falta, pero
/// cualquier pantalla del portal con datos de terceros debe leer este mismo
/// provider en vez de crear otro interruptor.
///
/// Es estado de CLIENTE: no viaja en ninguna petición y no cambia lo que el
/// servidor devuelve. Solo tapa lo que se pinta.
class ModoPresentacion extends ChangeNotifier {
  static const _clave = 'sozu_modo_presentacion';

  /// Máscara con la que se sustituye el dato oculto.
  static const mascara = '••••••';

  /// Arranca ENCENDIDO: el descuido que importa es enseñar datos sin querer,
  /// no tener que apagarlo.
  bool activo = true;

  ModoPresentacion() {
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getBool(_clave);
    if (guardado == null || guardado == activo) return;
    activo = guardado;
    notifyListeners();
  }

  Future<void> alternar() => cambiar(!activo);

  Future<void> cambiar(bool valor) async {
    if (valor == activo) return;
    activo = valor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clave, valor);
  }

  /// [texto] tal cual cuando el modo está apagado; la máscara cuando está
  /// encendido. Un valor vacío se devuelve intacto para no tapar un guion.
  String oculta(String? texto) {
    final v = texto ?? '';
    if (!activo || v.isEmpty) return v;
    return mascara;
  }
}

final modoPresentacionProvider = ChangeNotifierProvider<ModoPresentacion>(
  (ref) => ModoPresentacion(),
);
