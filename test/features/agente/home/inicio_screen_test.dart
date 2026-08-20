import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/home/providers/inicio_providers.dart';
import 'package:sozu_agente_app/features/agente/home/providers/notificaciones_providers.dart';
import 'package:sozu_agente_app/features/agente/home/screens/inicio_screen.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/shared/ports/telemetria_port.dart';
import 'package:sozu_agente_app/shared/providers/modo_presentacion_provider.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import 'fake_inicio_port.dart';
import 'fake_notificaciones_port.dart';

/// Doble de telemetría: guarda lo registrado para fijar los identificadores que
/// comparte con el portal web. Nunca lanza, igual que el puerto real.
class _FakeTelemetria implements TelemetriaPort {
  final List<String> vistas = [];
  final List<String> ctas = [];

  @override
  Future<void> registrarVista(
    String ruta, {
    Map<String, Object?> datos = const {},
  }) async {
    vistas.add(ruta);
  }

  @override
  Future<void> registrarCta({
    required String pagina,
    required String elementoId,
    String? etiqueta,
    String tipo = 'button',
    Map<String, Object?> metadata = const {},
  }) async {
    ctas.add('$pagina/$elementoId/$tipo');
  }

  @override
  Future<void> registrarExportacion(
    String tipo, {
    Map<String, Object?> datos = const {},
  }) async {}
}

/// Inicio pintado de verdad: la telemetría que alimenta los tableros, el atajo
/// que captura en vez de navegar y el refresco que arrastra a la activación.
void main() {
  const sesionBase = SesionAgente(
    identidad: IdentidadAgente(
      email: 'agente@sozu.com',
      rolId: 3,
      rolNombre: 'Agente Inmobiliario',
      esAgenteInmobiliario: true,
    ),
    permisos: {VistaAgente.inicio: PermisosVista.todo},
    header: HeaderAgente(nombre: 'Ana Torres', rol: 'Agente Inmobiliario'),
    onboarding: Onboarding(porcentaje: 60, capacitacionCompleta: true),
  );

  late FakeInicioPort inicio;
  late _FakeTelemetria telemetria;
  late int cargasDeSesion;

  setUp(() {
    inicio = FakeInicioPort();
    telemetria = _FakeTelemetria();
    cargasDeSesion = 0;
  });

  Future<void> pintar(
    WidgetTester tester, {
    // Alto de sobra: la lista construye solo lo visible, y con la fuente de
    // prueba (todo glifo mide un cuadrado) las tarjetas ocupan el doble.
    Size tamano = const Size(390, 2400),
    SesionAgente sesion = sesionBase,
    bool modoPresentacion = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = tamano;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [
            // El modo arranca ACTIVO en producción; aquí se fija por test para
            // no depender de `shared_preferences`, que sin plugin no resuelve.
            modoPresentacionProvider.overrideWith(
              (ref) => ModoPresentacion()..establecer(modoPresentacion),
            ),
            inicioPortProvider.overrideWithValue(inicio),
            notificacionesPortProvider.overrideWithValue(
              FakeNotificacionesPort(),
            ),
            telemetriaPortProvider.overrideWithValue(telemetria),
            sesionProvider.overrideWith((ref) async {
              cargasDeSesion++;
              return sesion;
            }),
            // El formulario de prospectos solo necesita el catálogo para
            // pintarse; guardar no se ejercita aquí.
            desarrollosVinculablesProvider.overrideWith(
              (ref) async => const <DesarrolloVinculable>[],
            ),
            carteraProspectosProvider.overrideWith(
              (ref) => Completer<CarteraProspectos>().future,
            ),
          ],
        ),
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: const InicioScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pinta saludo, números y agenda en teléfono', (tester) async {
    await pintar(tester);

    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('COMISIÓN PAGADA'), findsOneWidget);
    expect(find.text('Activa tu perfil profesional'), findsOneWidget);
    // 60% de activación: la insignia dice que el expediente no está cerrado.
    expect(find.text('No verificado'), findsOneWidget);
  });

  testWidgets('registra la vista y el page_view con los ids de la web', (
    tester,
  ) async {
    await pintar(tester);

    expect(telemetria.vistas, ['/admin/agent/inicio']);
    expect(telemetria.ctas, ['agent_inicio/page_view/page']);
  });

  testWidgets('el encabezado de la agenda dice "Citas", sin conteo', (
    tester,
  ) async {
    // El doble trae CUATRO citas y la tarjeta muestra tres.
    await pintar(tester);

    expect(find.text('CITAS'), findsOneWidget);
    expect(find.textContaining('Citas ('), findsNothing);
  });

  testWidgets('el atajo "Nuevo prospecto" abre el alta y registra su CTA', (
    tester,
  ) async {
    await pintar(tester);

    await tester.tap(find.text('Nuevo prospecto').first);
    await tester.pumpAndSettle();

    expect(
      telemetria.ctas,
      contains('agent_inicio/btn_nuevo_prospecto/button'),
    );
    // El formulario, no la lista: el título de la hoja y su botón de guardar.
    expect(find.text('Guardar'), findsOneWidget);
    expect(
      find.text('Se liga a los desarrollos que tú vendes'),
      findsOneWidget,
    );
  });

  testWidgets('el pull to refresh recarga tablero Y activación', (
    tester,
  ) async {
    // Viewport de teléfono a propósito: con la lista más corta que la pantalla
    // no hay sobre-scroll y el gesto del RefreshIndicator no dispara.
    await pintar(tester, tamano: const Size(390, 700));
    expect(cargasDeSesion, 1);
    expect(inicio.log.where((m) => m == 'cargarResumen').length, 1);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    // Sin la invalidación de la sesión, el banner y el porcentaje de activación
    // se quedaban viejos después de completar un paso del expediente.
    expect(cargasDeSesion, 2);
    expect(inicio.log.where((m) => m == 'cargarResumen').length, 2);
  });

  testWidgets('la insignia de presentación explica cómo apagarlo', (
    tester,
  ) async {
    // Escritorio: con la fuente de prueba (todo glifo mide un cuadrado) el
    // texto largo no cabe en 390 px, y ahí no se está midiendo nada real.
    await pintar(
      tester,
      tamano: const Size(1200, 1000),
      modoPresentacion: true,
    );

    expect(find.text('Ocultos · desactiva Modo presentación'), findsOneWidget);
  });

  testWidgets('sin modo presentación no hay insignia de ocultos', (
    tester,
  ) async {
    await pintar(tester, tamano: const Size(1200, 1000));

    expect(find.textContaining('desactiva Modo presentación'), findsNothing);
  });
}
