import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/features/agente/home/providers/notificaciones_providers.dart';
import 'package:sozu_agente_app/features/agente/inventario/providers/inventario_providers.dart';
import 'package:sozu_agente_app/features/agente/inventario/screens/inventario_screen.dart';
import 'package:sozu_agente_app/features/agente/inventario/screens/proyecto_detalle_screen.dart';
import 'package:sozu_agente_app/features/agente/inventario/screens/unidades_screen.dart';
import 'package:sozu_agente_app/features/agente/inventario/services/telemetria_inventario.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import '../home/fake_notificaciones_port.dart';
import 'fake_inventario_port.dart';
import 'fake_telemetria_port.dart';

/// Las tres pantallas del inventario se pintan de verdad y emiten la MISMA
/// telemetría que el portal web. Los ids son contrato: si cambian, el tablero
/// de CTA parte la serie entre web y app y ninguna de las dos es el total.
void main() {
  const sesionAliado = SesionAgente(
    identidad: IdentidadAgente(
      email: 'agente@sozu.com',
      rolId: 3,
      esAgenteInmobiliario: true,
    ),
    permisos: {VistaAgente.inventario: PermisosVista.todo},
    onboarding: Onboarding(porcentaje: 60, capacitacionCompleta: true),
  );

  const sesionVerificada = SesionAgente(
    identidad: IdentidadAgente(
      email: 'agente@sozu.com',
      rolId: 3,
      esAgenteInmobiliario: true,
    ),
    permisos: {VistaAgente.inventario: PermisosVista.todo},
    onboarding: Onboarding(porcentaje: 100, capacitacionCompleta: true),
  );

  /// Avanza hasta que la pantalla queda quieta. NO se usa `pumpAndSettle`: el
  /// placeholder de las imágenes de red es un `SSkeleton`, cuyo brillo se
  /// repite para siempre porque en un test la descarga nunca termina.
  Future<void> asentar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Monta [pantalla] con un router mínimo: los CTA de navegación llaman
  /// `context.push`, que sin GoRouter revienta antes de registrarse.
  Future<void> pintar(
    WidgetTester tester,
    Widget pantalla, {
    required FakeInventarioPort port,
    required FakeTelemetriaPort telemetria,
    SesionAgente sesion = sesionAliado,
    Size tamano = const Size(430, 1200),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = tamano;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => pantalla),
        GoRoute(
          path: '/inventario/proyecto/:id',
          builder: (_, __) => const Scaffold(body: Text('ficha')),
        ),
        GoRoute(
          path: '/inventario/unidades',
          builder: (_, __) => const Scaffold(body: Text('unidades')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [
            inventarioPortProvider.overrideWithValue(port),
            telemetriaPortProvider.overrideWithValue(telemetria),
            notificacionesPortProvider.overrideWithValue(
              FakeNotificacionesPort(),
            ),
            sesionProvider.overrideWith((ref) async => sesion),
          ],
        ),
        child: MaterialApp.router(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          routerConfig: router,
        ),
      ),
    );
    await asentar(tester);
  }

  group('listado de desarrollos', () {
    testWidgets('registra la vista y el page_view de la web', (tester) async {
      final telemetria = FakeTelemetriaPort();
      await pintar(
        tester,
        const InventarioScreen(),
        port: FakeInventarioPort(),
        telemetria: telemetria,
      );

      expect(telemetria.vistas, [TelemetriaInventario.rutaListado]);
      final vista = telemetria.primero(TelemetriaInventario.vistaPantalla)!;
      expect(vista.pagina, 'agent_inventario');
      expect(vista.tipo, 'page');
      expect(find.text('Torre Margot'), findsOneWidget);
    });

    testWidgets('escribir en el buscador cuenta como uso del campo', (
      tester,
    ) async {
      final telemetria = FakeTelemetriaPort();
      await pintar(
        tester,
        const InventarioScreen(),
        port: FakeInventarioPort(),
        telemetria: telemetria,
      );

      await tester.enterText(find.byType(TextField).first, 'Margot');
      await asentar(tester);

      final cta = telemetria.primero(
        TelemetriaInventario.inputBuscarDesarrollo,
      )!;
      expect(cta.tipo, 'input');
      expect(cta.pagina, 'agent_inventario');
      // Filtra de verdad: el otro desarrollo desaparece.
      expect(find.text('Distrito Andares'), findsNothing);
    });

    testWidgets('ver ficha y ver unidades llevan el id del proyecto', (
      tester,
    ) async {
      final telemetria = FakeTelemetriaPort();
      await pintar(
        tester,
        const InventarioScreen(),
        port: FakeInventarioPort(),
        telemetria: telemetria,
      );

      await tester.tap(find.text('Ver').first);
      await asentar(tester);
      expect(
        telemetria.primero(TelemetriaInventario.btnVerDesarrollo)!.metadata,
        {'proyecto_id': 7},
      );
    });

    testWidgets('compartir ofrece Facebook y Correo, y cuenta el canal', (
      tester,
    ) async {
      final telemetria = FakeTelemetriaPort();
      await pintar(
        tester,
        const InventarioScreen(),
        port: FakeInventarioPort(),
        telemetria: telemetria,
      );

      await tester.tap(find.byTooltip('Compartir').first);
      await asentar(tester);

      expect(telemetria.primero(TelemetriaInventario.btnCompartir)!.metadata, {
        'proyecto_id': 7,
      });
      expect(find.text('Ver página web'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      expect(find.text('Correo'), findsOneWidget);
      expect(find.text('Copiar liga'), findsOneWidget);

      await tester.tap(find.text('Copiar liga'));
      await asentar(tester);
      final canal = telemetria.primero(
        TelemetriaInventario.btnCompartirPlataforma,
      )!;
      expect(canal.metadata, {'plataforma': 'copy', 'proyecto_id': 7});
    });
  });

  group('ficha del desarrollo', () {
    testWidgets('la vista lleva el id del proyecto en ruta y metadata', (
      tester,
    ) async {
      final telemetria = FakeTelemetriaPort();
      await pintar(
        tester,
        const ProyectoDetalleScreen(idProyecto: 7),
        port: FakeInventarioPort(),
        telemetria: telemetria,
      );

      expect(telemetria.vistas, ['/admin/agent/inventario/proyecto/7']);
      expect(telemetria.datosDeVista.single, {'proyecto_id': 7});
      final vista = telemetria.primero(TelemetriaInventario.vistaPantalla)!;
      expect(vista.pagina, 'agent_detalle_desarrollo');
      expect(vista.metadata, {'proyecto_id': 7});
    });

    testWidgets('la portada anuncia el avance de obra', (tester) async {
      await pintar(
        tester,
        const ProyectoDetalleScreen(idProyecto: 7),
        port: FakeInventarioPort(),
        telemetria: FakeTelemetriaPort(),
      );

      expect(find.text('45% avance de obra'), findsOneWidget);
    });

    testWidgets('las amenidades se topan en 8 y se despliegan', (tester) async {
      await pintar(
        tester,
        const ProyectoDetalleScreen(idProyecto: 7),
        port: FakeInventarioPort()..amenidades = 11,
        telemetria: FakeTelemetriaPort(),
        tamano: const Size(1200, 4000),
      );

      expect(find.text('Amenidad 9'), findsNothing);
      expect(find.text('Ver todas (11)'), findsOneWidget);

      await tester.tap(find.text('Ver todas (11)'));
      await asentar(tester);
      expect(find.text('Amenidad 11'), findsOneWidget);
      expect(find.text('Ver menos'), findsOneWidget);
    });

    testWidgets('sin showroom los puntos de interés van dentro de Ubicación', (
      tester,
    ) async {
      await pintar(
        tester,
        const ProyectoDetalleScreen(idProyecto: 7),
        port: FakeInventarioPort()..conShowroom = false,
        telemetria: FakeTelemetriaPort(),
        tamano: const Size(1200, 4000),
      );

      // Un solo encabezado: el de la celda, no el de una sección aparte.
      expect(find.text('PUNTOS DE INTERÉS'), findsOneWidget);
      expect(find.text('Puntos de interés'), findsNothing);
      expect(find.text('Plaza Andares'), findsOneWidget);
    });

    testWidgets('el atajo del modelo dice "Ver inventario" y cuenta su id', (
      tester,
    ) async {
      final telemetria = FakeTelemetriaPort();
      await pintar(
        tester,
        const ProyectoDetalleScreen(idProyecto: 7),
        port: FakeInventarioPort(),
        telemetria: telemetria,
        tamano: const Size(1200, 4000),
      );

      final atajo = find.text('Ver inventario');
      // Dos: el CTA de la ficha y el del modelo.
      expect(atajo, findsNWidgets(2));
      await tester.tap(atajo.last);
      await asentar(tester);

      expect(
        telemetria
            .primero(TelemetriaInventario.btnVerInventarioModelo)!
            .metadata,
        {'modelo_id': 55},
      );
    });

    testWidgets('bajar el brochure cuenta el CTA y la exportación', (
      tester,
    ) async {
      final telemetria = FakeTelemetriaPort();
      await pintar(
        tester,
        const ProyectoDetalleScreen(idProyecto: 7),
        port: FakeInventarioPort(),
        telemetria: telemetria,
        tamano: const Size(1200, 4000),
      );

      // La ficha es larga y el ListView es perezoso: hay que llegar al pie.
      await tester.dragUntilVisible(
        find.text('Brochure'),
        find.byType(ListView).first,
        const Offset(0, -400),
      );
      await tester.tap(find.text('Brochure'));
      await tester.pump();

      expect(
        telemetria.primero(TelemetriaInventario.btnDescargarBrochure),
        isNotNull,
      );
      expect(telemetria.exportaciones, ['brochure']);
      expect(telemetria.datosDeExportacion.single, {'proyecto_id': 7});
    });
  });

  group('buscador de unidades', () {
    testWidgets('registra su vista y el badge de no verificado', (
      tester,
    ) async {
      final telemetria = FakeTelemetriaPort();
      await pintar(
        tester,
        const UnidadesScreen(),
        port: FakeInventarioPort(),
        telemetria: telemetria,
      );

      expect(telemetria.vistas, ['/admin/agent/inventario/unidades']);
      expect(
        telemetria.primero(TelemetriaInventario.vistaPantalla)!.pagina,
        'agent_unidades',
      );
      expect(find.text('No verificado'), findsOneWidget);
    });

    testWidgets('con el expediente al 100% no hay badge', (tester) async {
      await pintar(
        tester,
        const UnidadesScreen(),
        port: FakeInventarioPort(),
        telemetria: FakeTelemetriaPort(),
        sesion: sesionVerificada,
      );

      expect(find.text('No verificado'), findsNothing);
    });

    testWidgets('abrir el detalle cuenta la unidad y su desarrollo', (
      tester,
    ) async {
      final telemetria = FakeTelemetriaPort();
      await pintar(
        tester,
        const UnidadesScreen(),
        port: FakeInventarioPort(),
        telemetria: telemetria,
      );

      await tester.tap(find.text('Depto. 1203'));
      await asentar(tester);

      expect(
        telemetria.primero(TelemetriaInventario.btnDetalleUnidad)!.metadata,
        {'propiedad_id': 101, 'proyecto': 'Torre Margot'},
      );
      // La unidad tiene planos, así que el botón sí se ofrece.
      expect(find.text('Ver planos'), findsOneWidget);
    });

    testWidgets('sin planos cargados el detalle no ofrece "Ver planos"', (
      tester,
    ) async {
      await pintar(
        tester,
        const UnidadesScreen(),
        port: FakeInventarioPort()..planosVacios = true,
        telemetria: FakeTelemetriaPort(),
      );

      await tester.tap(find.text('Depto. 1203'));
      await asentar(tester);

      expect(find.text('Depto. 1203'), findsWidgets);
      expect(find.text('Ver planos'), findsNothing);
    });

    testWidgets('paginar conserva la lista anterior mientras llega la nueva', (
      tester,
    ) async {
      final port = FakeInventarioPort()
        ..totalPaginas = 3
        ..retrasoUnidades = const Duration(milliseconds: 300);
      await pintar(
        tester,
        const UnidadesScreen(),
        port: port,
        telemetria: FakeTelemetriaPort(),
      );

      expect(find.text('Depto. 1203'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Sigue habiendo unidades a la vista (no siluetas) y el paginador ya
      // muestra la página nueva con su spinner.
      expect(find.text('Depto. 1203'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await asentar(tester);
      expect(find.text('Depto. 1203'), findsOneWidget);
    });
  });
}
