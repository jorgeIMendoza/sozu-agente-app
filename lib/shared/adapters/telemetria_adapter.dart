import 'dart:math';

import 'package:sozu_agente_app/shared/adapters/edge_function.dart';
import 'package:sozu_agente_app/shared/ports/telemetria_port.dart';

/// Firma de la invocacion de una edge function. Existe para que los tests fijen
/// el body sin tocar red ni inicializar el backend.
typedef TelemetriaInvoker =
    Future<Map<String, dynamic>> Function(
      String fn, {
      Map<String, dynamic>? body,
    });

/// Implementacion actual de [TelemetriaPort] sobre la edge function
/// `agente-telemetria`: la unica frontera donde se conocen sus claves.
class TelemetriaAdapter implements TelemetriaPort {
  /// Agrupa los eventos de una misma corrida del app, como el `sessionStorage`
  /// de la web. `static`: sobrevive a la reconstruccion del adaptador cuando
  /// cambia la impersonacion.
  static final String sessionId = _nuevoSessionId();

  /// Distingue el evento del que manda el portal web. Ni `logs_actividad` ni
  /// `cta_events` tienen columna de origen, y las rutas se mandan iguales a las
  /// de la web para que la serie sea comparable: sin esta marca los dos
  /// clientes quedan indistinguibles en el tablero.
  static const origen = 'app';

  final TelemetriaInvoker _invocar;

  /// `impersonate`: el evento se atribuye al agente EFECTIVO, igual que el resto
  /// de las pantallas. Sin el header, un admin recibe 403 y el evento se pierde.
  TelemetriaAdapter({int? impersonate, TelemetriaInvoker? invocar})
    : _invocar = invocar ?? EdgeFunctions(impersonate: impersonate).call;

  @override
  Future<void> registrarVista(
    String ruta, {
    Map<String, Object?> datos = const {},
  }) => _enviar({
    'tipo': 'actividad',
    'accion': 'vista',
    'ruta': ruta,
    'datos': {'origen': origen, ...datos},
  });

  @override
  Future<void> registrarCta({
    required String pagina,
    required String elementoId,
    String? etiqueta,
    String tipo = 'button',
    Map<String, Object?> metadata = const {},
  }) => _enviar({
    'tipo': 'cta',
    'session_id': sessionId,
    'page': pagina,
    'element_id': elementoId,
    if (etiqueta != null) 'element_label': etiqueta,
    'element_type': tipo,
    'metadata': {'origen': origen, ...metadata},
  });

  @override
  Future<void> registrarExportacion(
    String tipo, {
    Map<String, Object?> datos = const {},
  }) => _enviar({
    'tipo': 'actividad',
    'accion': 'exportacion',
    'tipo_exportacion': tipo,
    'datos': {'origen': origen, ...datos},
  });

  /// Manda el evento y se traga CUALQUIER fallo. Perder una metrica es
  /// aceptable; romper la pantalla que la emitio, no.
  Future<void> _enviar(Map<String, dynamic> body) async {
    try {
      await _invocar('agente-telemetria', body: body);
    } catch (_) {
      // Sin log: el body puede traer metadata y no se imprime nada del evento.
    }
  }
}

/// Id aleatorio con forma de UUID v4. No identifica a nadie: solo agrupa los
/// eventos de una corrida.
String _nuevoSessionId() {
  final aleatorio = Random.secure();
  final bytes = List<int>.generate(16, (_) => aleatorio.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
