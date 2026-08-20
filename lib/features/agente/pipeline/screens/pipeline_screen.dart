import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/features/agente/layouts/portal_top_bar.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/compartir_negocio.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/etapa_badge.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/negocio_acciones.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/negocio_tabla.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/negocio_tablero.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/negocio_tarjeta.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/oferta_detalle_dialog.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/pipeline_encabezado.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/pipeline_modal.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/razon_no_avance_dialog.dart';
import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/shared/providers/modo_presentacion_provider.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/providers/pipeline_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Ancho máximo del contenido, el mismo del pipeline web.
const double _anchoContenido = 1040;

/// Pipeline del agente: sus negocios por etapa, en tabla, tarjetas o tablero.
///
/// Un negocio = una UNIDAD. La agrupación de las recotizaciones ya viene hecha
/// del servidor (`ofertas_count` dice cuántas versiones hubo), así que aquí no
/// se vuelve a agrupar nada.
class PipelineScreen extends ConsumerStatefulWidget {
  const PipelineScreen({super.key});

  @override
  ConsumerState<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends ConsumerState<PipelineScreen> {
  final _buscador = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Misma ruta y mismos identificadores que el portal web: la serie de la
    // bitácora y del tablero de CTA no se parte entre web y app.
    final telemetria = ref.read(telemetriaPortProvider);
    telemetria.registrarVista(_ruta);
    telemetria.registrarCta(
      pagina: _pagina,
      elementoId: 'page_view',
      tipo: 'page',
    );
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final permisos = ref.watch(permisosVistaProvider(VistaAgente.pipeline));
    final sesionResuelta = ref.watch(sesionProvider).hasValue;
    final pipeline = ref.watch(pipelineProvider);
    final vista = ref.watch(vistaPipelineProvider);
    final modoPresentacion = ref.watch(modoPresentacionProvider).activo;

    // El rol puede no tener el submenú del pipeline. Se espera a que la sesión
    // resuelva para no acusar falta de permiso mientras carga.
    if (sesionResuelta && !permisos.leer) {
      return Scaffold(
        // Sin esto, en movil la pantalla queda sin interruptor de modo
        // presentacion y sin campana: el del shell solo se pinta en escritorio.
        appBar: const PortalTopBar(vista: VistaAgente.pipeline),
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _marco(
            context,
            const SEmptyState(
              icon: Icons.lock_outline,
              title: 'Sin acceso al pipeline',
              message:
                  'Tu rol no tiene permiso de ver los negocios. Pídelo al '
                  'administrador del portal.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const PortalTopBar(vista: VistaAgente.pipeline),
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: pipeline.when(
          loading: () => _marco(context, _cargando(context)),
          error: (e, _) => _marco(
            context,
            Padding(
              padding: EdgeInsets.only(top: t.space.md),
              child: SErrorState(
                title: tituloDeError(e),
                message: mensajeDeError(e),
                onRetry: () => ref.invalidate(pipelineProvider),
              ),
            ),
          ),
          data: (datos) => vista == VistaPipeline.tablero
              ? _tablero(context, datos, permisos, modoPresentacion)
              : _listado(context, datos, permisos, modoPresentacion, vista),
        ),
      ),
    );
  }

  /// Limitador de ancho + gutter: el contenido se centra en pantallas anchas.
  Widget _marco(BuildContext context, Widget hijo) {
    final t = context.s;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _anchoContenido),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space.md),
          child: hijo,
        ),
      ),
    );
  }

  Widget _cargando(BuildContext context) {
    final t = context.s;
    return ListView(
      padding: EdgeInsets.only(top: t.space.xs, bottom: t.space.xl),
      children: [
        _encabezado(
          context,
          datos: const PipelineAgente(),
          permisos: const PermisosVista(),
          cargando: true,
        ),
        SizedBox(height: t.space.md),
        for (var i = 0; i < 4; i++) ...[
          const SCard(child: SSkeleton(height: 56)),
          SizedBox(height: t.space.xs),
        ],
      ],
    );
  }

  /// Tabla y tarjetas: scroll vertical con pull-to-refresh.
  Widget _listado(
    BuildContext context,
    PipelineAgente datos,
    PermisosVista permisos,
    bool modoPresentacion,
    VistaPipeline vista,
  ) {
    final t = context.s;
    final visibles = ref.watch(negociosVisiblesProvider);
    final etapas = ref.watch(etapasPorClaveProvider);
    final acciones = _acciones(datos, permisos);

    return RefreshIndicator(
      onRefresh: _refrescar,
      child: _marco(
        context,
        ListView(
          padding: EdgeInsets.only(top: t.space.xs, bottom: t.space.xl),
          children: [
            _encabezado(context, datos: datos, permisos: permisos),
            _avisos(datos),
            SizedBox(height: t.space.xs),
            if (visibles.isEmpty)
              _vacio(context)
            else if (vista == VistaPipeline.tabla)
              NegocioTabla(
                negocios: visibles,
                etapas: etapas,
                modoPresentacion: modoPresentacion,
                acciones: acciones,
              )
            else
              _rejilla(context, visibles, etapas, modoPresentacion, acciones),
          ],
        ),
      ),
    );
  }

  Widget _rejilla(
    BuildContext context,
    List<Negocio> visibles,
    Map<String, EtapaPipeline> etapas,
    bool modoPresentacion,
    AccionesNegocio acciones,
  ) {
    final t = context.s;
    final columnas = context.responsive(mobile: 1, tablet: 2, desktop: 2);

    // Wrap y no GridView: la tarjeta crece cuando el negocio arrastra el aviso
    // de "falta registrar la razón", y con un alto de celda fijo eso se
    // desborda. Aquí cada tarjeta mide lo que necesita.
    return LayoutBuilder(
      builder: (context, limites) {
        final ancho =
            (limites.maxWidth - t.space.xs * (columnas - 1)) / columnas;
        return Wrap(
          spacing: t.space.xs,
          runSpacing: t.space.xs,
          children: [
            for (final negocio in visibles)
              SizedBox(
                width: ancho,
                child: NegocioTarjeta(
                  negocio: negocio,
                  etapa: etapaResuelta(etapas, negocio.etapa),
                  modoPresentacion: modoPresentacion,
                  acciones: acciones,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Tablero: el encabezado queda fijo y las columnas se recorren en horizontal,
  /// así que la recarga va por botón (no hay arrastre vertical que la dispare).
  Widget _tablero(
    BuildContext context,
    PipelineAgente datos,
    PermisosVista permisos,
    bool modoPresentacion,
  ) {
    final t = context.s;
    final buscados = ref.watch(negociosBuscadosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _marco(
          context,
          Padding(
            padding: EdgeInsets.only(top: t.space.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _encabezado(
                  context,
                  datos: datos,
                  permisos: permisos,
                  conRecarga: true,
                ),
                _avisos(datos),
              ],
            ),
          ),
        ),
        SizedBox(height: t.space.xs),
        Expanded(
          child: datos.etapas.isEmpty
              ? _marco(context, _vacio(context))
              : NegocioTablero(
                  etapas: datos.etapas,
                  negocios: buscados,
                  modoPresentacion: modoPresentacion,
                  onDetalle: (n) => _abrirDetalle(n, datos, permisos),
                  onMover: (n, etapa) => _mover(n, etapa),
                  onAviso: _avisar,
                ),
        ),
        SizedBox(height: t.space.md),
      ],
    );
  }

  Widget _encabezado(
    BuildContext context, {
    required PipelineAgente datos,
    required PermisosVista permisos,
    bool cargando = false,
    bool conRecarga = false,
  }) {
    final conteo = ref.watch(conteoPorEtapaProvider);
    final total = ref.watch(negociosProvider).length;
    final filtro = ref.watch(etapaFiltroProvider);
    final onboarding = ref.watch(onboardingProvider);
    final identidad = ref.watch(identidadAgenteProvider);

    return PipelineEncabezado(
      resumen: datos.resumen,
      cargando: cargando,
      vista: ref.watch(vistaPipelineProvider),
      onVista: (v) => ref.read(vistaPipelineProvider.notifier).state = v,
      modoPresentacion: ref.watch(modoPresentacionProvider).activo,
      buscador: _buscador,
      onBuscar: (v) => ref.read(busquedaProspectoProvider.notifier).state = v,
      etapaFiltro: filtro,
      opcionesEtapa: _opcionesEtapa(datos, conteo, total, filtro),
      onEtapa: _filtrarEtapa,
      puedeCrear: permisos.crear,
      // El candado de capacitación es del aliado externo: al agente interno la
      // web nunca se lo pone.
      faltaCapacitacion:
          identidad?.esAgenteInmobiliario == true &&
          !onboarding.capacitacionCompleta,
      onNuevaOferta: _nuevaOferta,
      onRefrescar: conRecarga ? () => ref.invalidate(pipelineProvider) : null,
    );
  }

  Widget _avisos(PipelineAgente datos) {
    final filtro = ref.watch(etapaFiltroProvider);
    return PipelineAvisos(
      modoPresentacion: ref.watch(modoPresentacionProvider).activo,
      cerradosSinRazon: ref.watch(cerradosSinRazonProvider).length,
      onVerCerrados: filtro == _etapaPerdido ? null : _verCerrados,
    );
  }

  Widget _vacio(BuildContext context) {
    final porEtapa = ref.watch(etapaFiltroProvider) != kTodasLasEtapas;
    final filtrando =
        porEtapa || ref.watch(busquedaProspectoProvider).trim().isNotEmpty;
    return SEmptyState.card(
      icon: Icons.inbox_outlined,
      // Mismos textos que la web; el botón de quitar filtros es de más.
      title: porEtapa
          ? 'No hay negocios en esta etapa'
          : 'No hay negocios que mostrar',
      message: filtrando
          ? 'Prueba con otro prospecto o quita el filtro de etapa.'
          : 'Aquí van a aparecer tus ofertas y apartados de los últimos 30 días.',
      action: filtrando
          ? SButton.secondary(
              label: 'Quitar filtros',
              fullWidth: false,
              onPressed: () {
                _buscador.clear();
                ref.read(busquedaProspectoProvider.notifier).state = '';
                ref.read(etapaFiltroProvider.notifier).state = kTodasLasEtapas;
              },
            )
          : null,
    );
  }

  /// Opciones del filtro. Los conteos salen de los NEGOCIOS, no de las ofertas:
  /// con ofertas el chip decía "19" mientras la tabla mostraba 4 unidades.
  List<SSelectOption<String>> _opcionesEtapa(
    PipelineAgente datos,
    Map<String, int> conteo,
    int total,
    String filtro,
  ) => [
    (value: kTodasLasEtapas, label: 'Todas las etapas ($total)'),
    for (final e in datos.etapas)
      if ((conteo[e.clave] ?? 0) > 0 || e.clave == filtro)
        (
          value: e.clave,
          label:
              '${e.nombre} (${conteo[e.clave] ?? 0})'
              '${e.automatica ? ' · automática' : ''}',
        ),
  ];

  AccionesNegocio _acciones(PipelineAgente datos, PermisosVista permisos) {
    final puedeRazon = permisos.actualizar && datos.catalogoRazones.disponible;
    return AccionesNegocio(
      verDetalle: (n) => _abrirDetalle(n, datos, permisos),
      compartir: (n) => mostrarCompartirOferta(
        context,
        idOferta: n.idOferta,
        titulo: '${n.folio} · ${n.unidad}',
        urlCliente: n.tieneLinkCliente ? n.urlCliente : '',
        urlPreview: n.urlPreview,
        mensaje: mensajeDeOferta(
          url: n.tieneLinkCliente ? n.urlCliente : n.urlPreview,
          nombreLead: n.lead.nombre,
          unidad: n.unidad,
          proyecto: n.proyectoNombre,
        ),
        telefono: n.lead.telefono,
        clavePais: n.lead.clavePaisTelefono,
        email: n.lead.email,
      ),
      abrirLink: (n) => abrirLinkCliente(context, n.urlCliente),
      registrarRazon: puedeRazon
          ? (n) => _abrirRazon(n, datos, permisos)
          : null,
    );
  }

  Future<void> _refrescar() async {
    ref.invalidate(pipelineProvider);
    try {
      await ref.read(pipelineProvider.future);
    } catch (_) {
      // El estado de error ya lo pinta la pantalla.
    }
  }

  Future<void> _abrirDetalle(
    Negocio negocio,
    PipelineAgente datos,
    PermisosVista permisos,
  ) async {
    final resultado = await mostrarHojaPipeline<ResultadoDetalle>(
      context,
      OfertaDetalleHoja(
        negocio: negocio,
        etapa: etapaResuelta({
          for (final e in datos.etapas) e.clave: e,
        }, negocio.etapa),
        puedeActualizar: permisos.actualizar,
        razonesDisponibles: datos.catalogoRazones.disponible,
      ),
    );
    if (!mounted || resultado == null) return;
    if (resultado.aviso != null) _avisar(resultado.aviso!);
    if (resultado.abrirRazon) await _abrirRazon(negocio, datos, permisos);
  }

  Future<void> _abrirRazon(
    Negocio negocio,
    PipelineAgente datos,
    PermisosVista permisos,
  ) async {
    unawaited(
      ref
          .read(telemetriaPortProvider)
          .registrarCta(
            pagina: _pagina,
            elementoId: 'btn_motivo_no_avance',
            etiqueta: negocio.razonNoAvance != null
                ? 'Editar razón'
                : '¿Por qué no avanzó?',
            metadata: {'id_oferta': negocio.idOferta},
          ),
    );
    final guardada = await mostrarHojaPipeline<bool>(
      context,
      RazonNoAvanceHoja(
        negocio: negocio,
        catalogo: datos.catalogoRazones,
        puedeActualizar: permisos.actualizar,
      ),
    );
    if (!mounted || guardada != true) return;
    _avisar('Gracias, registramos la razón.');
  }

  Future<void> _mover(Negocio negocio, EtapaPipeline destino) async {
    try {
      await ref.read(pipelineAccionesProvider).moverEtapa(negocio, destino);
      unawaited(
        ref
            .read(telemetriaPortProvider)
            .registrarCta(
              pagina: _pagina,
              elementoId: 'mover_etapa',
              metadata: {'negocio': negocio.idNegocio, 'etapa': destino.clave},
            ),
      );
      _avisar('Movido a ${destino.nombre}.');
    } catch (e) {
      _avisar(mensajeDeError(e));
    }
  }

  /// Nueva oferta = elegir la unidad. Mismo destino que la web: el inventario
  /// con los filtros abiertos, que es donde se genera la oferta de verdad.
  void _nuevaOferta() {
    ref
        .read(telemetriaPortProvider)
        .registrarCta(
          pagina: _pagina,
          elementoId: 'btn_nueva_oferta',
          etiqueta: 'Nueva oferta',
        );
    context.push('/inventario/unidades?openFilters=true');
  }

  /// Filtra por etapa; `clave` es [kTodasLasEtapas] para quitar el filtro.
  void _filtrarEtapa(String clave) {
    ref
        .read(telemetriaPortProvider)
        .registrarCta(
          pagina: _pagina,
          elementoId: 'filtro_etapa',
          etiqueta: clave,
        );
    ref.read(etapaFiltroProvider.notifier).state = clave;
  }

  /// Salta a los negocios cerrados como perdidos, los que piden razón.
  void _verCerrados() {
    ref
        .read(telemetriaPortProvider)
        .registrarCta(
          pagina: _pagina,
          elementoId: 'btn_ver_expiradas_sin_razon',
          etiqueta: 'Ver perdidos',
        );
    ref.read(etapaFiltroProvider.notifier).state = _etapaPerdido;
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }
}

/// Clave de la etapa de cierre perdido, la que pide razón.
const String _etapaPerdido = 'perdido';

/// Ruta e identificador de página de la telemetría. Son los de la web: si
/// difieren, el mismo botón cuenta dos veces en el tablero de CTA.
const String _ruta = '/admin/agent/pipeline';
const String _pagina = 'agent_pipeline';
