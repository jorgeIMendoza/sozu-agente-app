import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/features/agente/layouts/portal_top_bar.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/prospecto_fila.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/prospecto_form_hoja.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/transferir_prospecto_hoja.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/shared/providers/modo_presentacion_provider.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/prospectos_reglas.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/fx.dart';

/// Valor del filtro que significa "sin filtrar". Los ids del catálogo nunca son
/// 0 (los del catálogo de respaldo son negativos), así que sirve de comodín.
const int _sinFiltro = 0;

/// Ruta con la que la web registra esta vista en la bitácora.
const _rutaVistaWeb = '/admin/agent/prospectos';

/// Página con la que la web etiqueta los CTA de esta pantalla.
const _paginaCta = 'agent_prospectos';

/// Cartera de prospectos del agente: buscador, filtros y una fila por persona
/// que se abre para ver sus desarrollos, mover el estado del lead, transferirlo
/// y revisar sus unidades.
class ProspectosScreen extends ConsumerStatefulWidget {
  const ProspectosScreen({super.key});

  @override
  ConsumerState<ProspectosScreen> createState() => _ProspectosScreenState();
}

class _ProspectosScreenState extends ConsumerState<ProspectosScreen> {
  final _busqueda = TextEditingController();
  String _texto = '';
  int? _idEstado;
  int? _idDesarrollo;

  /// Prospectos abiertos, por id de persona.
  final Set<int> _abiertos = {};

  /// Relación cuyo estado se está guardando, para deshabilitar solo ese select.
  int? _relacionGuardando;

  @override
  void initState() {
    super.initState();
    final telemetria = ref.read(telemetriaPortProvider);
    unawaited(telemetria.registrarVista(_rutaVistaWeb));
    unawaited(
      telemetria.registrarCta(
        pagina: _paginaCta,
        elementoId: 'page_view',
        tipo: 'page',
      ),
    );
  }

  /// Registra el clic de un CTA con los mismos identificadores que la web. No se
  /// espera: la telemetría se traga sus fallos y nunca retrasa la acción.
  void _cta(String elementoId, {Map<String, Object?> metadata = const {}}) {
    unawaited(
      ref
          .read(telemetriaPortProvider)
          .registrarCta(
            pagina: _paginaCta,
            elementoId: elementoId,
            metadata: metadata,
          ),
    );
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _cambiarEstado(DesarrolloDeProspecto d, int idEstado) async {
    setState(() => _relacionGuardando = d.idRelacion);
    try {
      await ref
          .read(prospectosPortProvider)
          .cambiarEstadoLead(idRelacion: d.idRelacion, idEstadoLead: idEstado);
      _cta('cambio_estatus_lead', metadata: {'er': d.idRelacion});
      ref.invalidate(carteraProspectosProvider);
      _aviso('Estado actualizado');
    } catch (e) {
      _aviso(
        mensajeDeErrorProspecto(
          e,
          porDefecto: 'No se pudo actualizar el estado.',
        ),
      );
    } finally {
      if (mounted) setState(() => _relacionGuardando = null);
    }
  }

  Future<void> _transferir(Prospecto p, DesarrolloDeProspecto d) async {
    final ok = await transferirProspecto(
      context,
      idRelacion: d.idRelacion,
      prospecto: p.nombre,
      desarrollo: d.desarrollo,
    );
    if (ok != true) return;
    _cta('reasignar_lead', metadata: {'er': d.idRelacion});
    ref.invalidate(carteraProspectosProvider);
    _aviso('Prospecto transferido. Ya no aparece en tu cartera.');
  }

  Future<void> _nuevo() async {
    final ok = await editarProspecto(context);
    if (ok != true) return;
    ref.invalidate(carteraProspectosProvider);
    _aviso('Prospecto guardado');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final permisos = ref.watch(permisosVistaProvider(VistaAgente.prospectos));

    return Scaffold(
      appBar: const PortalTopBar(title: 'Prospectos'),
      body: SafeArea(
        child: ContentFrame(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(carteraProspectosProvider);
              try {
                await ref.read(carteraProspectosProvider.future);
              } catch (_) {
                // El estado de error lo pinta la lista.
              }
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                t.space.md,
                t.space.sm,
                t.space.md,
                t.space.xxl,
              ),
              children: [
                // En pantallas anchas el marco no trae título de sección, así
                // que la pantalla pone el suyo.
                if (context.bp.hasSidebar) ...[
                  Text(
                    'Prospectos',
                    style: t.text.h2.copyWith(color: t.color.fg),
                  ),
                  Text(
                    'Tu cartera de leads y su seguimiento',
                    style: t.text.bodySmall.copyWith(color: t.color.fgMuted),
                  ),
                  SizedBox(height: t.space.md),
                ],
                ..._cuerpo(context, permisos),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Cuerpo de la pantalla: primero se resuelve el arranque del portal (de ahí
  /// salen los permisos) y solo entonces se pide la cartera. Al revés, un rol
  /// sin permiso vería un error crudo del servidor en vez de la explicación.
  List<Widget> _cuerpo(BuildContext context, PermisosVista permisos) {
    final sesion = ref.watch(sesionProvider);
    if (sesion.valueOrNull == null) {
      if (sesion.hasError) {
        return [
          SErrorState(
            title: 'No pudimos abrir tu portal',
            message: 'Vuelve a intentarlo en un momento.',
            onRetry: () => ref.invalidate(sesionProvider),
          ),
        ];
      }
      return const [_EsqueletoCartera()];
    }
    if (!permisos.leer) return const [_SinPermiso()];
    return _cartera(context, permisos);
  }

  List<Widget> _cartera(BuildContext context, PermisosVista permisos) {
    final t = context.s;
    final tone = t.color;
    final cartera = ref.watch(carteraProspectosProvider);
    final modo = ref.watch(modoPresentacionProvider);
    final prospectos = cartera.valueOrNull?.prospectos ?? const <Prospecto>[];
    final estados =
        cartera.valueOrNull?.catalogoEstados ?? const <EstadoLead>[];
    final filtrados = filtrarProspectos(
      prospectos,
      busqueda: _texto,
      idEstadoLead: _idEstado,
      idDesarrollo: _idDesarrollo,
    );
    final totales = TotalesCartera.de(filtrados);
    final hayFiltros =
        _texto.trim().isNotEmpty || _idEstado != null || _idDesarrollo != null;

    return [
      if (modo.activo) ...[
        Container(
          padding: EdgeInsets.all(t.space.sm),
          decoration: BoxDecoration(
            color: tone.warningSoft,
            borderRadius: t.radius.mdBorder,
            border: Border.all(color: tone.warning),
          ),
          child: Row(
            children: [
              Icon(
                Icons.visibility_off_outlined,
                size: 18,
                color: tone.warningFg,
              ),
              SizedBox(width: t.space.xs),
              Expanded(
                child: Text(
                  'Modo presentación · los datos de tus prospectos están '
                  'ocultos. Apágalo para verlos.',
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.warningFg,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: t.space.sm),
      ],

      SSearchField(
        controller: _busqueda,
        hintText: 'Buscar por nombre, correo, teléfono o desarrollo…',
        onChanged: (v) => setState(() => _texto = v),
      ),
      SizedBox(height: t.space.sm),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SSelectField<int>(
              value: _idEstado ?? _sinFiltro,
              opciones: [
                (value: _sinFiltro, label: 'Todos los estados'),
                for (final e in estados) (value: e.id, label: e.nombre),
              ],
              onChanged: (v) => setState(
                () => _idEstado = v == null || v == _sinFiltro ? null : v,
              ),
            ),
          ),
          SizedBox(width: t.space.xs),
          Expanded(
            child: SSelectField<int>(
              value: _idDesarrollo ?? _sinFiltro,
              opciones: [
                (value: _sinFiltro, label: 'Todos los desarrollos'),
                for (final d in desarrollosDeLaCartera(prospectos))
                  (value: d.id, label: d.nombre),
              ],
              onChanged: (v) => setState(
                () => _idDesarrollo = v == null || v == _sinFiltro ? null : v,
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: t.space.sm),
      // El interruptor del modo presentación lo pinta el shell en todas las
      // pantallas: aquí saldría dos veces.
      if (permisos.crear)
        Align(
          alignment: Alignment.centerLeft,
          child: SButton(
            label: 'Nuevo prospecto',
            icon: Icons.person_add_alt,
            size: SButtonSize.sm,
            fullWidth: false,
            onPressed: () {
              _cta('btn_nuevo_prospecto');
              _nuevo();
            },
          ),
        ),
      SizedBox(height: t.space.sm),

      // Con datos ya en mano se sigue pintando la lista aunque haya un refresco
      // en curso: vaciarla en cada "jalar para actualizar" hace saltar todo.
      if (cartera.valueOrNull == null)
        if (cartera.hasError)
          SErrorState(
            title: 'No pudimos cargar tu cartera',
            message: mensajeDeErrorProspecto(
              cartera.error,
              porDefecto: 'Vuelve a intentarlo en un momento.',
            ),
            onRetry: () => ref.invalidate(carteraProspectosProvider),
          )
        else
          const _EsqueletoCartera()
      else ...[
        Text(
          totales.resumen,
          style: t.text.overline.copyWith(color: tone.fgSubtle),
        ),
        SizedBox(height: t.space.sm),
        if (filtrados.isEmpty)
          SEmptyState.card(
            icon: Icons.person_search_outlined,
            title: hayFiltros
                ? 'No se encontraron prospectos'
                : 'Aún no tienes prospectos',
            message: hayFiltros
                ? 'Prueba con otro nombre, estado o desarrollo.'
                : 'Da de alta al primero y llévalo hasta la oferta.',
            action: hayFiltros || !permisos.crear
                ? null
                : SButton(
                    label: 'Crear mi primer prospecto',
                    icon: Icons.person_add_alt,
                    size: SButtonSize.sm,
                    fullWidth: false,
                    onPressed: _nuevo,
                  ),
          )
        else
          for (final p in filtrados)
            Padding(
              padding: EdgeInsets.only(bottom: t.space.sm),
              child: ProspectoFila(
                prospecto: p,
                estados: estados,
                expandido: _abiertos.contains(p.idPersona),
                relacionGuardando: _relacionGuardando,
                enmascarar: modo.enmascarar,
                onAlternar: () => setState(() {
                  if (!_abiertos.remove(p.idPersona)) {
                    _abiertos.add(p.idPersona);
                  }
                }),
                onVerFicha: () {
                  _cta(
                    'btn_ver_prospecto',
                    metadata: {'persona_id': p.idPersona},
                  );
                  context.push('/prospectos/${p.idPersona}');
                },
                onCambiarEstado: _cambiarEstado,
                onTransferir: (d) => _transferir(p, d),
              ),
            ),
        if (cartera.valueOrNull?.modeloDeTransicion == true &&
            filtrados.isNotEmpty) ...[
          SizedBox(height: t.space.xs),
          Row(
            children: [
              Icon(Icons.people_outline, size: 14, color: tone.fgSubtle),
              SizedBox(width: t.space.xxs),
              Expanded(
                child: Text(
                  'Leyendo del modelo de transición (dueño por agente + '
                  'atribución del CRM).',
                  style: t.text.caption.copyWith(color: tone.fgSubtle),
                ),
              ),
            ],
          ),
        ],
      ],
    ];
  }
}

/// Carga de la cartera: tres filas del alto de una fila real, para que la lista
/// no salte al llegar los datos.
class _EsqueletoCartera extends StatelessWidget {
  const _EsqueletoCartera();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: t.space.sm),
            child: SCard(
              child: Row(
                children: [
                  const SSkeleton.circle(size: 20),
                  SizedBox(width: t.space.sm),
                  const Expanded(child: SSkeleton.text(lines: 3)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Rol sin permiso de lectura en el submenú de prospectos.
class _SinPermiso extends StatelessWidget {
  const _SinPermiso();

  @override
  Widget build(BuildContext context) => const SEmptyState.card(
    icon: Icons.lock_outline,
    title: 'Prospectos no está habilitado para tu rol',
    message:
        'Tu usuario no tiene permiso para ver la cartera de prospectos. '
        'Pídele a tu administrador que active el submenú Prospectos para tu '
        'rol y vuelve a entrar.',
  );
}
