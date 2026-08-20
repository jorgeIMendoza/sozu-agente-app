import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/core/portal_theme.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/compartir_desarrollo.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/desarrollo_card.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/features/agente/inventario/providers/inventario_providers.dart';
import 'package:sozu_agente_app/features/agente/inventario/services/mensajes_error.dart';
import 'package:sozu_agente_app/features/agente/inventario/services/telemetria_inventario.dart';
import 'package:sozu_agente_app/features/agente/layouts/portal_top_bar.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/fx.dart';
import 'package:sozu_agente_app/widgets/portal_widgets.dart';

/// Inventario: los desarrollos que el agente puede vender, con su
/// disponibilidad, y las tres acciones de cada uno (ver ficha, ver unidades,
/// compartir con el cliente).
class InventarioScreen extends ConsumerWidget {
  const InventarioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final portal = isPortalMode(context);
    final cuerpo = _Contenido(portal: portal);

    if (portal) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: EdgeInsets.only(top: t.space.lg, bottom: t.space.xl),
          child: cuerpo,
        ),
      );
    }

    return Scaffold(
      appBar: const PortalTopBar(title: 'Inventario'),
      body: SafeArea(child: ContentFrame(child: cuerpo)),
    );
  }
}

/// Buscador + rejilla. Es un componente con estado (el controlador del campo y
/// la telemetría de la vista) porque la pantalla solo compone.
class _Contenido extends ConsumerStatefulWidget {
  final bool portal;

  const _Contenido({required this.portal});

  @override
  ConsumerState<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends ConsumerState<_Contenido> {
  late final TextEditingController _busqueda = TextEditingController(
    // El texto persiste durante la sesión del app, igual que el
    // `sessionStorage` del portal web: volver a la pestaña no lo borra.
    text: ref.read(busquedaDesarrollosProvider),
  );

  @override
  void initState() {
    super.initState();
    final t = ref.read(telemetriaPortProvider);
    unawaited(t.registrarVista(TelemetriaInventario.rutaListado));
    unawaited(
      t.registrarCta(
        pagina: TelemetriaInventario.paginaListado,
        elementoId: TelemetriaInventario.vistaPantalla,
        tipo: TelemetriaInventario.tipoPagina,
      ),
    );
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _recargar() async {
    ref.invalidate(desarrollosProvider);
    try {
      await ref.read(desarrollosProvider.future);
    } catch (_) {
      // El estado de error lo pinta la lista; aquí solo se corta el spinner.
    }
  }

  /// CTA del inventario. `metadata` va sin PII: solo ids y el canal elegido.
  void _cta(
    String elementoId, {
    String? etiqueta,
    Map<String, Object?> metadata = const {},
  }) {
    unawaited(
      ref
          .read(telemetriaPortProvider)
          .registrarCta(
            pagina: TelemetriaInventario.paginaListado,
            elementoId: elementoId,
            etiqueta: etiqueta,
            metadata: metadata,
          ),
    );
  }

  void _buscar(String texto) {
    ref.read(busquedaDesarrollosProvider.notifier).state = texto;
    // Mismo disparo que la web: cada cambio con texto cuenta como uso del
    // buscador. Sin la misma regla, la serie del app no es comparable.
    if (texto.isNotEmpty) {
      unawaited(
        ref
            .read(telemetriaPortProvider)
            .registrarCta(
              pagina: TelemetriaInventario.paginaListado,
              elementoId: TelemetriaInventario.inputBuscarDesarrollo,
              etiqueta: 'Buscar desarrollo',
              tipo: TelemetriaInventario.tipoCampo,
            ),
      );
    }
  }

  /// Filtrado por nombre, del lado del cliente: el universo de desarrollos son
  /// decenas, no vale una ida al servidor por tecla.
  List<DesarrolloResumen> _filtrar(List<DesarrolloResumen> todos, String q) {
    final texto = q.trim().toLowerCase();
    if (texto.isEmpty) return todos;
    return todos
        .where((d) => d.nombre.toLowerCase().contains(texto))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final lista = ref.watch(desarrollosProvider);
    final busqueda = ref.watch(busquedaDesarrollosProvider);
    final permisos = ref.watch(permisosVistaProvider(VistaAgente.inventario));
    final margen = widget.portal ? 0.0 : t.space.md;

    // El buscador va FUERA del scroll: con 20 desarrollos, buscar obligaba a
    // subir hasta arriba. Es el equivalente del `sticky` del portal web.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            margen,
            widget.portal ? 0 : t.space.xs,
            margen,
            t.space.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.portal) ...[
                const PortalPageHeader(
                  title: 'Inventario',
                  subtitle: 'Desarrollos y unidades disponibles',
                ),
                SizedBox(height: t.space.md),
              ],
              SSearchField(
                controller: _busqueda,
                hintText: 'Buscar desarrollo…',
                onChanged: _buscar,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _recargar,
            child: ListView(
              padding: EdgeInsets.fromLTRB(margen, 0, margen, t.space.xl),
              children: [
                lista.when(
                  loading: () => const ResponsiveCardGrid(
                    children: [
                      DesarrolloCardSkeleton(),
                      DesarrolloCardSkeleton(),
                      DesarrolloCardSkeleton(),
                    ],
                  ),
                  error: (e, _) => SErrorState(
                    title: 'No pudimos cargar el inventario',
                    message: mensajeErrorInventario(e),
                    onRetry: () => ref.invalidate(desarrollosProvider),
                  ),
                  data: (todos) {
                    // Vacío por acceso y vacío por búsqueda no son lo mismo: el
                    // primero se resuelve pidiendo proyectos, el segundo
                    // borrando el texto. Un solo mensaje para los dos manda al
                    // agente a reportar un bug que no existe.
                    if (todos.isEmpty) return const _SinAcceso();
                    final visibles = _filtrar(todos, busqueda);
                    if (visibles.isEmpty) {
                      return SEmptyState.card(
                        icon: Icons.search_off_outlined,
                        title: 'Sin resultados',
                        message:
                            'Ningún desarrollo coincide con '
                            '"${busqueda.trim()}".',
                        action: SButton.secondary(
                          label: 'Limpiar búsqueda',
                          fullWidth: false,
                          onPressed: () {
                            _busqueda.clear();
                            ref
                                    .read(busquedaDesarrollosProvider.notifier)
                                    .state =
                                '';
                          },
                        ),
                      );
                    }
                    return ResponsiveCardGrid(
                      children: [
                        for (final d in visibles)
                          DesarrolloCard(
                            desarrollo: d,
                            puedeVer: permisos.leer,
                            onVerFicha: () {
                              _cta(
                                TelemetriaInventario.btnVerDesarrollo,
                                etiqueta: 'Ver Desarrollo',
                                metadata: {'proyecto_id': d.id},
                              );
                              context.push('/inventario/proyecto/${d.id}');
                            },
                            onVerUnidades: () {
                              _cta(
                                TelemetriaInventario.btnVerInventario,
                                etiqueta: 'Ver inventario',
                                metadata: {'proyecto_id': d.id},
                              );
                              context.push(
                                '/inventario/unidades?proyecto=${d.id}',
                              );
                            },
                            onCompartir: () {
                              _cta(
                                TelemetriaInventario.btnCompartir,
                                etiqueta: 'Compartir',
                                metadata: {'proyecto_id': d.id},
                              );
                              unawaited(
                                mostrarCompartirDesarrollo(
                                  context,
                                  nombre: d.nombre,
                                  urlPublica: d.urlPublica,
                                  ubicacion: d.ubicacion,
                                  onPlataforma: (plataforma) => _cta(
                                    TelemetriaInventario.btnCompartirPlataforma,
                                    etiqueta: 'Compartir $plataforma',
                                    metadata: {
                                      'plataforma': plataforma,
                                      'proyecto_id': d.id,
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// El agente no tiene desarrollos asignados. El servidor devuelve lista vacía,
/// no un error, así que sin este estado la pantalla se queda en blanco y parece
/// que sigue cargando.
class _SinAcceso extends StatelessWidget {
  const _SinAcceso();

  @override
  Widget build(BuildContext context) => const SEmptyState.card(
    icon: Icons.apartment_outlined,
    title: 'Todavía no tienes desarrollos asignados',
    message:
        'El inventario que puedes vender lo asigna SOZU. Pídele a tu supervisor '
        'que te dé acceso a los desarrollos y aparecerán aquí.',
  );
}
