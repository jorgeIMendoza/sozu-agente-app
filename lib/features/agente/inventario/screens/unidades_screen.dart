import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/core/portal_theme.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/filtros_unidades_hoja.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/unidad_card.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/unidad_detalle.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/features/agente/inventario/providers/inventario_providers.dart';
import 'package:sozu_agente_app/features/agente/inventario/screens/planos_unidad_screen.dart';
import 'package:sozu_agente_app/features/agente/inventario/services/mensajes_error.dart';
import 'package:sozu_agente_app/features/agente/inventario/services/telemetria_inventario.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/nueva_oferta_hoja.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/fx.dart';

/// Buscador de unidades disponibles. Llega con el desarrollo y el modelo
/// preseleccionados desde el inventario o la ficha, y con [abrirFiltros] cuando
/// el agente entra por el atajo de filtrar.
class UnidadesScreen extends StatelessWidget {
  final int? idProyecto;
  final int? idModelo;
  final bool abrirFiltros;

  const UnidadesScreen({
    super.key,
    this.idProyecto,
    this.idModelo,
    this.abrirFiltros = false,
  });

  @override
  Widget build(BuildContext context) {
    final portal = isPortalMode(context);
    return Scaffold(
      backgroundColor: portal ? Colors.transparent : null,
      appBar: portal
          ? null
          : AppBar(
              title: const Text('Unidades'),
              leading: BackButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/inventario'),
              ),
            ),
      body: SafeArea(
        top: !portal,
        child: _Buscador(
          idProyecto: idProyecto,
          idModelo: idModelo,
          abrirFiltros: abrirFiltros,
          portal: portal,
        ),
      ),
    );
  }
}

/// Buscador con estado: página vigente, resolución de la preselección y el
/// controlador del campo de texto.
class _Buscador extends ConsumerStatefulWidget {
  final int? idProyecto;
  final int? idModelo;
  final bool abrirFiltros;
  final bool portal;

  const _Buscador({
    required this.idProyecto,
    required this.idModelo,
    required this.abrirFiltros,
    required this.portal,
  });

  @override
  ConsumerState<_Buscador> createState() => _BuscadorState();
}

class _BuscadorState extends ConsumerState<_Buscador> {
  late final TextEditingController _busqueda = TextEditingController(
    text: ref.read(busquedaUnidadProvider),
  );

  /// Controlador de la lista, para volver al tope al cambiar de página: sin él
  /// el agente pasa a la 3 y aterriza a media lista, viendo unidades nuevas
  /// desde el renglón 12.
  final ScrollController _scroll = ScrollController();

  int _pagina = 0;

  /// Última página que llegó completa. Se sigue pintando mientras la siguiente
  /// viaja: reemplazarla por siluetas hace parpadear la pantalla entera cuando
  /// lo único que cambió son 30 renglones.
  PaginaUnidades? _ultimaPagina;

  /// Mayor total visto. Al buscar por número de unidad se filtra en cliente, y
  /// para eso hay que pedir de una todas las unidades del filtro vigente, no la
  /// página de 30. El techo de 500 lo impone el servidor.
  int _ultimoTotal = ConsultaUnidades.paginaDefault;

  /// Extremos de precio del inventario visible, calculados una vez para que
  /// mover el rango no los recalcule contra los resultados ya filtrados.
  double? _precioMinVisto;
  double? _precioMaxVisto;

  /// La preselección por ids se resuelve contra otras dos vistas: mientras eso
  /// pasa NO se pinta la lista, o se vería un instante el inventario completo.
  bool _resolviendo = false;

  @override
  void initState() {
    super.initState();
    final tel = ref.read(telemetriaPortProvider);
    unawaited(tel.registrarVista(TelemetriaInventario.rutaUnidades));
    unawaited(
      tel.registrarCta(
        pagina: TelemetriaInventario.paginaUnidades,
        elementoId: TelemetriaInventario.vistaPantalla,
        tipo: TelemetriaInventario.tipoPagina,
      ),
    );
    final hayPreseleccion =
        widget.idProyecto != null || widget.idModelo != null;
    if (hayPreseleccion) {
      _resolviendo = true;
      _resolverPreseleccion();
    } else if (widget.abrirFiltros) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _abrirFiltros());
    }
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// CTA de la vista de unidades. `metadata` va sin PII ni montos.
  void _cta(
    String elementoId, {
    String? etiqueta,
    Map<String, Object?> metadata = const {},
  }) {
    unawaited(
      ref
          .read(telemetriaPortProvider)
          .registrarCta(
            pagina: TelemetriaInventario.paginaUnidades,
            elementoId: elementoId,
            etiqueta: etiqueta,
            metadata: metadata,
          ),
    );
  }

  /// Traduce los ids con los que se navegó a los nombres que entiende la
  /// búsqueda y los deja como filtros vigentes.
  Future<void> _resolverPreseleccion() async {
    final pre = (idDesarrollo: widget.idProyecto, idModelo: widget.idModelo);
    try {
      final filtros = await ref.read(preseleccionFiltrosProvider(pre).future);
      if (!mounted) return;
      ref.read(filtrosUnidadesProvider.notifier).state = filtros;
      // Contexto nuevo: la búsqueda anterior no aplica a este desarrollo.
      ref.read(busquedaUnidadProvider.notifier).state = '';
      _busqueda.clear();
    } catch (_) {
      // Si no se pudo resolver el nombre, se entra sin filtro en vez de dejar
      // la pantalla trabada: la lista completa es un resultado usable.
    }
    if (!mounted) return;
    setState(() => _resolviendo = false);
    if (widget.abrirFiltros) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _abrirFiltros());
    }
  }

  Future<void> _abrirFiltros() async {
    final consulta = _consulta(ref.read(filtrosUnidadesProvider));
    final pagina = ref.read(unidadesProvider(consulta)).valueOrNull;
    if (!mounted) return;
    final elegidos = await mostrarFiltrosUnidades(
      context,
      actuales: ref.read(filtrosUnidadesProvider),
      opciones: pagina?.opciones ?? const OpcionesFiltro(),
      conteoPorDesarrollo: pagina?.conteoPorDesarrollo ?? const {},
      precioMin: _precioMinVisto ?? 0,
      precioMax: _precioMaxVisto ?? _precioMaxDefault,
    );
    if (elegidos == null || !mounted) return;
    ref.read(filtrosUnidadesProvider.notifier).state = elegidos;
  }

  ConsultaUnidades _consulta(FiltrosUnidades filtros) {
    final buscando = ref.read(busquedaUnidadProvider).trim().isNotEmpty;
    if (!buscando) {
      return ConsultaUnidades(filtros: filtros, pagina: _pagina);
    }
    final pedido = _ultimoTotal > ConsultaUnidades.paginaDefault
        ? _ultimoTotal
        : ConsultaUnidades.paginaDefault;
    return ConsultaUnidades(
      filtros: filtros,
      porPagina: pedido > ConsultaUnidades.paginaMaxima
          ? ConsultaUnidades.paginaMaxima
          : pedido,
    );
  }

  /// Guarda el total y los extremos de precio vistos. Va en el frame siguiente:
  /// tocar el estado durante el `build` de la lista lo reconstruiría a mitad.
  void _memorizar(PaginaUnidades pagina) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final precios = pagina.unidades
          .map((u) => u.precioLista)
          .where((p) => p > 0)
          .toList();
      final nuevoTotal = pagina.total > _ultimoTotal
          ? pagina.total
          : _ultimoTotal;
      final min = precios.isEmpty
          ? null
          : precios.reduce((a, b) => a < b ? a : b);
      final max = precios.isEmpty
          ? null
          : precios.reduce((a, b) => a > b ? a : b);
      final cambiaMin = min != null && _precioMinVisto == null;
      final cambiaMax = max != null && _precioMaxVisto == null;
      final cambiaPagina = !identical(_ultimaPagina, pagina);
      if (nuevoTotal == _ultimoTotal &&
          !cambiaMin &&
          !cambiaMax &&
          !cambiaPagina) {
        return;
      }
      setState(() {
        _ultimoTotal = nuevoTotal;
        _ultimaPagina = pagina;
        if (cambiaMin) _precioMinVisto = min.floorToDouble();
        if (cambiaMax) _precioMaxVisto = max.ceilToDouble();
      });
    });
  }

  void _irAPagina(int destino) {
    setState(() => _pagina = destino);
    if (_scroll.hasClients) {
      unawaited(
        _scroll.animateTo(
          0,
          duration: context.s.motion.normal,
          curve: context.s.motion.standard,
        ),
      );
    }
  }

  Future<void> _abrirUnidad(Unidad unidad, PaginaUnidades pagina) {
    final permisos = ref.read(permisosVistaProvider(VistaAgente.inventario));
    final onboarding = ref.read(onboardingProvider);
    // El nombre del desarrollo no es PII: identifica el inventario, no a una
    // persona. Es el mismo par que manda la web.
    final identificadores = <String, Object?>{
      'propiedad_id': unidad.id,
      'proyecto': unidad.desarrolloNombre,
    };
    _cta(
      TelemetriaInventario.btnDetalleUnidad,
      etiqueta: 'Depto ${unidad.numero ?? unidad.id}',
      metadata: identificadores,
    );
    return mostrarDetalleUnidad(
      context,
      unidad: unidad,
      esquemas: pagina.esquemasDe(unidad),
      mesesEfectivos: pagina.mesesDe(unidad),
      onVerPlanos: () => abrirPlanosUnidad(
        context,
        idUnidad: unidad.id,
        titulo: 'Planos ${unidad.etiqueta}',
      ),
      puedeGenerarOferta: permisos.generarOferta,
      capacitacionCompleta: onboarding.capacitacionCompleta,
      onConfigurarOferta: (esquema) => _configurarOferta(unidad, esquema),
    );
  }

  /// Abre la configuración de la oferta con el plan ya elegido en el detalle.
  ///
  /// El CTA se emite AQUÍ y no dentro de la hoja: mide la intención de cotizar,
  /// que es el último paso del embudo, y así cuadra con el de la web.
  void _configurarOferta(Unidad unidad, EsquemaPago? esquema) {
    _cta(
      TelemetriaInventario.btnConfigurarOferta,
      etiqueta: 'Configurar Oferta',
      metadata: {
        'propiedad_id': unidad.id,
        if (unidad.idDesarrollo != null) 'proyecto_id': unidad.idDesarrollo,
        if (esquema != null) 'esquema_id': esquema.id,
      },
    );
    unawaited(
      configurarNuevaOferta(
        context,
        unidad: UnidadParaOferta(
          idPropiedad: unidad.id,
          etiqueta: unidad.etiqueta,
          desarrollo: unidad.desarrolloNombre ?? '',
          precioTotal: unidad.precioLista + unidad.totalExtrasConCosto,
          idEsquemaPago: esquema?.id,
          esquemaNombre: esquema?.nombre ?? '',
          extras: [
            for (final e in unidad.extrasConCosto)
              ExtraParaOferta(
                etiqueta: e.etiqueta,
                esBodega: e.tipo == TipoExtra.bodega,
                costo: e.costo,
              ),
          ],
        ),
        onAgendarCapacitacion: () => context.go('/perfil/capacitacion'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final filtros = ref.watch(filtrosUnidadesProvider);
    final busqueda = ref.watch(busquedaUnidadProvider);

    // Cambiar un filtro o el texto devuelve a la primera página: quedarse en la
    // 4 de un resultado que ahora tiene 2 muestra una lista vacía sin motivo.
    ref.listen<FiltrosUnidades>(filtrosUnidadesProvider, (_, __) {
      if (_pagina != 0) _irAPagina(0);
    });
    ref.listen<String>(busquedaUnidadProvider, (_, __) {
      if (_pagina != 0) _irAPagina(0);
    });

    final consulta = _consulta(filtros);
    final resultado = ref.watch(unidadesProvider(consulta));
    final columnas = context.responsive(mobile: 1, tablet: 2, desktop: 3);
    // Solo el aliado externo: el agente interno de SOZU no tiene expediente que
    // verificar. `identidad == null` = la sesión aún no llegó, y sin eso el
    // badge alcanzaría a parpadear en cada entrada.
    final identidad = ref.watch(identidadAgenteProvider);
    final sinVerificar =
        identidad != null &&
        identidad.esAgenteInmobiliario &&
        !ref.watch(onboardingProvider).verificado;

    return ContentFrame(
      maxWidth: _anchoLista,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.portal ? 0 : t.space.md,
              widget.portal ? t.space.lg : t.space.xs,
              widget.portal ? 0 : t.space.md,
              t.space.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fuera del scroll y siempre a la vista, como en la web: el
                // agente que va a generar una oferta tiene que saber que su
                // expediente todavia no esta completo.
                if (sinVerificar) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: SBadge(
                      label: 'No verificado',
                      tone: SBadgeTone.negative,
                      size: SBadgeSize.sm,
                      icon: Icons.error_outline,
                    ),
                  ),
                  SizedBox(height: t.space.xxs),
                ],
                Row(
                  children: [
                    Expanded(
                      child: SSearchField(
                        controller: _busqueda,
                        hintText: 'Buscar unidad…',
                        onChanged: (v) =>
                            ref.read(busquedaUnidadProvider.notifier).state = v,
                      ),
                    ),
                    SizedBox(width: t.space.xs),
                    _BotonFiltros(
                      activos: filtros.activos,
                      onAbrir: () {
                        _cta(
                          TelemetriaInventario.btnFiltros,
                          etiqueta: 'Filtros',
                        );
                        unawaited(_abrirFiltros());
                      },
                    ),
                    SizedBox(width: t.space.xxs),
                    IconButton(
                      tooltip: 'Limpiar filtros',
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      color: filtros.hayFiltros
                          ? t.color.primaryHover
                          : t.color.fgSubtle,
                      onPressed: filtros.hayFiltros
                          ? () =>
                                ref
                                        .read(filtrosUnidadesProvider.notifier)
                                        .state =
                                    const FiltrosUnidades()
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _resolviendo
                ? _ListaCargando(columnas: columnas, portal: widget.portal)
                : resultado.when(
                    // Con una página ya vista se conserva y solo se marca que
                    // viene otra; las siluetas quedan para la primera carga.
                    loading: () {
                      final previa = _ultimaPagina;
                      if (previa == null) {
                        return _ListaCargando(
                          columnas: columnas,
                          portal: widget.portal,
                        );
                      }
                      return _Lista(
                        unidades: _filtrarPorNumero(previa.unidades, busqueda),
                        columnas: columnas,
                        portal: widget.portal,
                        total: previa.total,
                        totalPaginas: previa.totalPaginas,
                        pagina: _pagina,
                        paginable: busqueda.trim().isEmpty,
                        cargando: true,
                        scroll: _scroll,
                        onPagina: _irAPagina,
                        onTocar: (u) => _abrirUnidad(u, previa),
                      );
                    },
                    error: (e, _) => ListView(
                      padding: EdgeInsets.all(t.space.md),
                      children: [
                        SErrorState(
                          title: 'No pudimos cargar las unidades',
                          message: mensajeErrorInventario(e),
                          onRetry: () =>
                              ref.invalidate(unidadesProvider(consulta)),
                        ),
                      ],
                    ),
                    data: (pagina) {
                      _memorizar(pagina);
                      final visibles = _filtrarPorNumero(
                        pagina.unidades,
                        busqueda,
                      );
                      if (visibles.isEmpty) {
                        return ListView(
                          padding: EdgeInsets.all(t.space.md),
                          children: [
                            _Vacio(
                              hayFiltros: filtros.hayFiltros,
                              busqueda: busqueda.trim(),
                              onLimpiar: () {
                                _busqueda.clear();
                                ref
                                        .read(busquedaUnidadProvider.notifier)
                                        .state =
                                    '';
                                ref
                                        .read(filtrosUnidadesProvider.notifier)
                                        .state =
                                    const FiltrosUnidades();
                              },
                            ),
                          ],
                        );
                      }
                      return _Lista(
                        unidades: visibles,
                        columnas: columnas,
                        portal: widget.portal,
                        total: pagina.total,
                        totalPaginas: pagina.totalPaginas,
                        pagina: _pagina,
                        // Con búsqueda activa se pidió una sola página grande:
                        // paginar ahí no tiene sentido.
                        paginable: busqueda.trim().isEmpty,
                        scroll: _scroll,
                        onPagina: _irAPagina,
                        onTocar: (u) => _abrirUnidad(u, pagina),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Filtrado por número de unidad, en cliente: es una coincidencia parcial
  /// sobre el número y el servidor no la expone como filtro.
  List<Unidad> _filtrarPorNumero(List<Unidad> unidades, String busqueda) {
    final texto = busqueda.trim().toLowerCase();
    if (texto.isEmpty) return unidades;
    return unidades
        .where((u) => (u.numero ?? '').toLowerCase().contains(texto))
        .toList(growable: false);
  }
}

/// Botón de filtros con el contador de los que están puestos.
class _BotonFiltros extends StatelessWidget {
  final int activos;
  final VoidCallback onAbrir;

  const _BotonFiltros({required this.activos, required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return SButton.secondary(
      label: activos == 0 ? 'Filtros' : 'Filtros ($activos)',
      icon: Icons.tune,
      fullWidth: false,
      onPressed: onAbrir,
      color: activos == 0 ? null : t.color.primary,
    );
  }
}

/// Rejilla de resultados con su paginador.
class _Lista extends StatelessWidget {
  final List<Unidad> unidades;
  final int columnas;
  final bool portal;
  final int total;
  final int totalPaginas;
  final int pagina;
  final bool paginable;

  /// La página que se pinta es la anterior y ya viene otra en camino.
  final bool cargando;

  final ScrollController scroll;
  final ValueChanged<int> onPagina;
  final ValueChanged<Unidad> onTocar;

  const _Lista({
    required this.unidades,
    required this.columnas,
    required this.portal,
    required this.total,
    required this.totalPaginas,
    required this.pagina,
    required this.paginable,
    required this.scroll,
    required this.onPagina,
    required this.onTocar,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return ListView(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(
        portal ? 0 : t.space.md,
        0,
        portal ? 0 : t.space.md,
        t.space.xl,
      ),
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: t.space.xs),
          child: Text(
            total == 1 ? '1 unidad disponible' : '$total unidades disponibles',
            style: t.text.caption.copyWith(color: t.color.fgMuted),
          ),
        ),
        _RejillaUnidades(
          columnas: columnas,
          children: [
            for (final u in unidades)
              UnidadCard(unidad: u, onTocar: () => onTocar(u)),
          ],
        ),
        if (paginable && totalPaginas > 1) ...[
          SizedBox(height: t.space.md),
          // `Wrap` y no `Row`: los dos botones con su texto y el indicador no
          // caben en el ancho de un teléfono, y una fila que se desborda recorta
          // "Siguiente" justo cuando hay más de una página.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: t.space.md,
            runSpacing: t.space.xs,
            children: [
              SButton.secondary(
                label: 'Anterior',
                icon: Icons.chevron_left,
                fullWidth: false,
                onPressed: pagina == 0 ? null : () => onPagina(pagina - 1),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${pagina + 1} / $totalPaginas',
                    style: t.text.bodySmall.copyWith(color: t.color.fgMuted),
                  ),
                  if (cargando) ...[
                    SizedBox(width: t.space.xxs),
                    SizedBox.square(
                      dimension: _ladoSpinnerPagina,
                      child: CircularProgressIndicator(
                        strokeWidth: _grosorSpinnerPagina,
                        color: t.color.fgSubtle,
                      ),
                    ),
                  ],
                ],
              ),
              SButton.secondary(
                label: 'Siguiente',
                trailingIcon: Icons.chevron_right,
                fullWidth: false,
                onPressed: pagina >= totalPaginas - 1
                    ? null
                    : () => onPagina(pagina + 1),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Siluetas mientras llega la página.
class _ListaCargando extends StatelessWidget {
  final int columnas;
  final bool portal;

  const _ListaCargando({required this.columnas, required this.portal});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        portal ? 0 : t.space.md,
        0,
        portal ? 0 : t.space.md,
        t.space.xl,
      ),
      children: [
        _RejillaUnidades(
          columnas: columnas,
          children: const [
            UnidadCardSkeleton(),
            UnidadCardSkeleton(),
            UnidadCardSkeleton(),
            UnidadCardSkeleton(),
          ],
        ),
      ],
    );
  }
}

/// Rejilla de ancho fijo por columna, con el mismo aire que la ficha.
class _RejillaUnidades extends StatelessWidget {
  final int columnas;
  final List<Widget> children;

  const _RejillaUnidades({required this.columnas, required this.children});

  @override
  Widget build(BuildContext context) {
    final gap = context.s.space.sm;
    if (columnas <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = (c.maxWidth - gap * (columnas - 1)) / columnas;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final w in children) SizedBox(width: ancho, child: w),
          ],
        );
      },
    );
  }
}

/// Sin resultados. Distingue los tres motivos, porque la salida de cada uno es
/// distinta: borrar el texto, quitar filtros, o pedir acceso a un desarrollo.
class _Vacio extends StatelessWidget {
  final bool hayFiltros;
  final String busqueda;
  final VoidCallback onLimpiar;

  const _Vacio({
    required this.hayFiltros,
    required this.busqueda,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    if (busqueda.isNotEmpty) {
      return SEmptyState.card(
        icon: Icons.search_off_outlined,
        title: 'Sin unidades con ese número',
        message: 'Ninguna unidad disponible coincide con "$busqueda".',
        action: SButton.secondary(
          label: 'Limpiar búsqueda y filtros',
          fullWidth: false,
          onPressed: onLimpiar,
        ),
      );
    }
    if (hayFiltros) {
      return SEmptyState.card(
        icon: Icons.filter_alt_off_outlined,
        title: 'Sin unidades con estos filtros',
        message: 'Prueba con menos filtros o con otro rango de precio.',
        action: SButton.secondary(
          label: 'Limpiar filtros',
          fullWidth: false,
          onPressed: onLimpiar,
        ),
      );
    }
    return const SEmptyState.card(
      icon: Icons.apartment_outlined,
      title: 'No hay unidades disponibles',
      message:
          'El inventario que puedes vender lo asigna SOZU. Si esperabas ver '
          'unidades aquí, pídele a tu supervisor que revise tus desarrollos '
          'asignados.',
    );
  }
}

/// Ancho de lectura de la lista en el portal ancho.
const double _anchoLista = 1100;

/// Tope del rango de precio mientras no se conoce el inventario visible.
const double _precioMaxDefault = 10000000;

/// Spinner del paginador: acompaña al texto "3 / 8", no lo reemplaza.
const double _ladoSpinnerPagina = 12;
const double _grosorSpinnerPagina = 1.6;
