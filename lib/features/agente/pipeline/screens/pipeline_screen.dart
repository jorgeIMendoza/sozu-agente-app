import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'package:sozu_agente_app/features/agente/pipeline/providers/modo_presentacion_provider.dart';
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

    return PipelineEncabezado(
      resumen: datos.resumen,
      cargando: cargando,
      vista: ref.watch(vistaPipelineProvider),
      onVista: (v) => ref.read(vistaPipelineProvider.notifier).state = v,
      modoPresentacion: ref.watch(modoPresentacionProvider).activo,
      onAlternarPresentacion: () =>
          ref.read(modoPresentacionProvider).alternar(),
      buscador: _buscador,
      onBuscar: (v) => ref.read(busquedaProspectoProvider.notifier).state = v,
      etapaFiltro: filtro,
      opcionesEtapa: _opcionesEtapa(datos, conteo, total, filtro),
      onEtapa: (v) => ref.read(etapaFiltroProvider.notifier).state = v,
      puedeCrear: permisos.generarOferta,
      capacitacionCompleta: onboarding.capacitacionCompleta,
      onNuevaOferta: _nuevaOferta,
      onRefrescar: conRecarga ? () => ref.invalidate(pipelineProvider) : null,
    );
  }

  Widget _avisos(PipelineAgente datos) {
    final filtro = ref.watch(etapaFiltroProvider);
    return PipelineAvisos(
      modoPresentacion: ref.watch(modoPresentacionProvider).activo,
      cerradosSinRazon: ref.watch(cerradosSinRazonProvider).length,
      onVerCerrados: filtro == _etapaPerdido
          ? null
          : () => ref.read(etapaFiltroProvider.notifier).state = _etapaPerdido,
    );
  }

  Widget _vacio(BuildContext context) {
    final filtrando =
        ref.watch(etapaFiltroProvider) != kTodasLasEtapas ||
        ref.watch(busquedaProspectoProvider).trim().isNotEmpty;
    return SEmptyState.card(
      icon: Icons.inbox_outlined,
      title: filtrando
          ? 'Ningún negocio coincide'
          : 'Todavía no tienes negocios',
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
    final puedeRazon =
        permisos.actualizar && datos.catalogoRazones.disponible;
    return AccionesNegocio(
      verDetalle: (n) => _abrirDetalle(n, datos, permisos),
      compartir: (n) => compartirLinkCliente(
        context,
        url: n.urlCliente,
        titulo: '${n.folio} · ${n.unidad}',
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
        etapa: etapaResuelta(
          {for (final e in datos.etapas) e.clave: e},
          negocio.etapa,
        ),
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
      _avisar('Movido a ${destino.nombre}.');
    } catch (e) {
      _avisar(mensajeDeError(e));
    }
  }

  /// El diálogo de nueva oferta lo trae otra tanda (lo construye otro agente):
  /// el punto de entrada ya queda gateado por permiso y capacitación para que al
  /// llegar solo haya que cambiar esta línea.
  void _nuevaOferta() => _avisar('Disponible en la siguiente tanda.');

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }
}

/// Clave de la etapa de cierre perdido, la que pide razón.
const String _etapaPerdido = 'perdido';
