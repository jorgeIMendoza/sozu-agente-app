import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/shared/adapters/telemetria_adapter.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/shared/ports/telemetria_port.dart';

/// Lo que fija este archivo son las CLAVES del body que espera
/// `agente-telemetria` y la regla de oro del puerto: la telemetria NUNCA rompe
/// una pantalla. Si una clave se renombra aqui, el evento se descarta en el
/// servidor en silencio (responde 200 { registrado: false }) y el tablero de CTA
/// se queda vacio sin que nadie lo note.
void main() {
  /// Invoker que graba la llamada en vez de salir a la red.
  ({List<String> fns, List<Map<String, dynamic>> bodies, TelemetriaInvoker fn})
  grabador() {
    final fns = <String>[];
    final bodies = <Map<String, dynamic>>[];
    return (
      fns: fns,
      bodies: bodies,
      fn: (String fn, {Map<String, dynamic>? body}) async {
        fns.add(fn);
        bodies.add(body ?? const {});
        return {'ok': true, 'registrado': true};
      },
    );
  }

  group('registrarVista', () {
    test('manda tipo actividad + accion vista + ruta', () async {
      final rec = grabador();
      final port = TelemetriaAdapter(invocar: rec.fn);

      await port.registrarVista('/admin/agent/inicio');

      expect(rec.fns, ['agente-telemetria']);
      expect(rec.bodies.single, {
        'tipo': 'actividad',
        'accion': 'vista',
        'ruta': '/admin/agent/inicio',
        'datos': {'origen': 'app'},
      });
    });

    test('los datos extra viajan en `datos`, no sueltos en el body', () async {
      final rec = grabador();

      await TelemetriaAdapter(
        invocar: rec.fn,
      ).registrarVista('/admin/agent/prospectos/91', datos: {'persona_id': 91});

      expect(rec.bodies.single['datos'], {'origen': 'app', 'persona_id': 91});
    });
  });

  group('registrarCta', () {
    test('manda las claves snake_case de cta_events', () async {
      final rec = grabador();

      await TelemetriaAdapter(invocar: rec.fn).registrarCta(
        pagina: 'agent_inventario',
        elementoId: 'btn_ver_desarrollo',
        etiqueta: 'Ver Desarrollo',
        metadata: {'proyecto_id': 12},
      );

      final body = rec.bodies.single;
      expect(body['tipo'], 'cta');
      expect(body['page'], 'agent_inventario');
      expect(body['element_id'], 'btn_ver_desarrollo');
      expect(body['element_label'], 'Ver Desarrollo');
      expect(body['element_type'], 'button');
      expect(body['metadata'], {'origen': 'app', 'proyecto_id': 12});
      expect(body['session_id'], TelemetriaAdapter.sessionId);
    });

    test('el session_id es uno solo para todo el proceso', () async {
      final rec = grabador();

      await TelemetriaAdapter(invocar: rec.fn).registrarCta(
        pagina: 'agent_inicio',
        elementoId: 'page_view',
        tipo: 'page',
      );
      await TelemetriaAdapter(invocar: rec.fn).registrarCta(
        pagina: 'agent_pipeline',
        elementoId: 'page_view',
        tipo: 'page',
      );

      expect(rec.bodies[0]['session_id'], rec.bodies[1]['session_id']);
      expect(rec.bodies[0]['session_id'], isNotEmpty);
      expect(rec.bodies[1]['element_type'], 'page');
    });

    test(
      'sin etiqueta no manda la clave vacia, pero el origen siempre va',
      () async {
        final rec = grabador();

        await TelemetriaAdapter(invocar: rec.fn).registrarCta(
          pagina: 'agent_perfil',
          elementoId: 'btn_seccion_documentos',
        );

        expect(rec.bodies.single.containsKey('element_label'), isFalse);
        expect(rec.bodies.single['metadata'], {'origen': 'app'});
      },
    );
  });

  test('registrarExportacion manda accion + tipo_exportacion', () async {
    final rec = grabador();

    await TelemetriaAdapter(
      invocar: rec.fn,
    ).registrarExportacion('brochure', datos: {'proyecto_id': 12});

    expect(rec.bodies.single, {
      'tipo': 'actividad',
      'accion': 'exportacion',
      'tipo_exportacion': 'brochure',
      'datos': {'origen': 'app', 'proyecto_id': 12},
    });
  });

  test('el origen distingue el evento del app del que manda la web', () async {
    final rec = grabador();
    final port = TelemetriaAdapter(invocar: rec.fn);

    // Las rutas se mandan IGUALES a las de la web para que la serie sea
    // comparable, y ni logs_actividad ni cta_events tienen columna de origen:
    // sin esta marca los dos clientes quedan indistinguibles en el tablero.
    await port.registrarVista('/admin/agent/inicio');
    await port.registrarCta(pagina: 'agent_inicio', elementoId: 'page_view');
    await port.registrarExportacion('ficha_tecnica');

    expect(rec.bodies[0]['datos']['origen'], 'app');
    expect(rec.bodies[1]['metadata']['origen'], 'app');
    expect(rec.bodies[2]['datos']['origen'], 'app');
  });

  test('el body NUNCA lleva identidad: la deriva el backend del JWT', () async {
    final rec = grabador();
    final port = TelemetriaAdapter(invocar: rec.fn);

    await port.registrarVista('/admin/agent/comisiones');
    await port.registrarCta(
      pagina: 'agent_comisiones',
      elementoId: 'btn_subir_factura_agent',
    );
    await port.registrarExportacion('ficha_tecnica');

    for (final body in rec.bodies) {
      expect(body.keys, isNot(contains('email')));
      expect(body.keys, isNot(contains('user_email')));
      expect(body.keys, isNot(contains('id_persona')));
      expect(body.keys, isNot(contains('auth_user_id')));
    }
  });

  group('la telemetria nunca rompe una pantalla', () {
    /// Cada fallo que puede salir del llamador de edge functions, y uno que ni
    /// es Exception: ninguno debe escapar del adaptador.
    final fallos = <String, Object>{
      'red caida': ApiError(0, 'network_error'),
      '403 del gate': ApiError(403, 'forbidden_role'),
      '500 del backend': ApiError(500, 'internal_error'),
      'excepcion cualquiera': Exception('boom'),
      'Error, no Exception': StateError('boom'),
    };

    for (final entry in fallos.entries) {
      test('${entry.key}: la pantalla no se entera', () async {
        final TelemetriaPort port = TelemetriaAdapter(
          invocar: (_, {Map<String, dynamic>? body}) async => throw entry.value,
        );

        await expectLater(
          port.registrarVista('/admin/agent/inicio'),
          completes,
        );
        await expectLater(
          port.registrarCta(pagina: 'agent_inicio', elementoId: 'page_view'),
          completes,
        );
        await expectLater(port.registrarExportacion('brochure'), completes);
      });
    }

    test('un 200 con registrado:false tampoco es un fallo', () async {
      final TelemetriaPort port = TelemetriaAdapter(
        invocar: (_, {Map<String, dynamic>? body}) async => {
          'ok': true,
          'registrado': false,
        },
      );

      await expectLater(
        port.registrarVista('/admin/agent/pipeline'),
        completes,
      );
    });
  });
}
