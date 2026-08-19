import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/citas/components/agendar_cita_hoja.dart';
import 'package:sozu_agente_app/features/agente/citas/ports/citas_port.dart';
import 'package:sozu_agente_app/features/agente/citas/services/seleccion_de_cita.dart';
import 'package:sozu_agente_app/features/agente/home/components/banner_activacion.dart';
import 'package:sozu_agente_app/features/agente/home/components/estado_error_agente.dart';
import 'package:sozu_agente_app/features/agente/home/components/hoja_detalle_cita.dart';
import 'package:sozu_agente_app/features/agente/home/components/modo_presentacion_boton.dart';
import 'package:sozu_agente_app/features/agente/home/components/saludo_agente.dart';
import 'package:sozu_agente_app/features/agente/home/components/tarjeta_accion.dart';
import 'package:sozu_agente_app/features/agente/home/components/tarjeta_cita.dart';
import 'package:sozu_agente_app/features/agente/home/components/tarjeta_kpi.dart';
import 'package:sozu_agente_app/features/agente/home/ports/inicio_port.dart';
import 'package:sozu_agente_app/features/agente/home/providers/inicio_providers.dart';
import 'package:sozu_agente_app/features/agente/layouts/portal_top_bar.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/prospecto_form_hoja.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/shared/providers/modo_presentacion_provider.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/fx.dart';

/// Ancho de lectura del portal web (`max-w-[1040px]`). En web ancho el shell ya
/// centra el contenido; esto evita que las tarjetas se estiren a 1280 px.
const double _anchoContenido = 1040;

/// Destinos a los que salta Inicio.
const String _rutaComisiones = '/comisiones';
const String _rutaPerfil = '/perfil';

/// La capacitación del agente no se reagenda desde la agenda de showroom: tiene
/// su propio flujo en el expediente, igual que en el portal web.
const String _rutaCapacitacion = '/perfil/capacitacion';

/// Identificadores de telemetría, IDÉNTICOS a los del portal web: si difieren,
/// el mismo botón cuenta dos veces en el tablero de CTA.
const String _rutaVistaWeb = '/admin/agent/inicio';
const String _paginaCta = 'agent_inicio';

/// Abre el agendado y, si quedó, refresca el tablero y avisa.
Future<void> _agendar(
  BuildContext context,
  WidgetRef ref, {
  ProspectoParaCita? prospecto,
  DesarrolloParaCita? desarrollo,
  bool reagendar = false,
}) async {
  final cita = await mostrarAgendarCita(
    context,
    prospecto: prospecto,
    desarrollo: desarrollo,
    reagendar: reagendar,
  );
  if (cita == null || !context.mounted) return;
  ref.invalidate(resumenInicioProvider);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        cita.aviso ?? (reagendar ? 'Cita reagendada.' : 'Cita agendada.'),
      ),
    ),
  );
}

/// Inicio del Portal del Agente: quién es, qué le falta para operar, qué puede
/// capturar ahora, cómo va de números y qué tiene agendado.
///
/// El orden no es decorativo: primero lo que bloquea (activación del perfil),
/// luego lo que produce (captura), después el resultado (comisiones) y al final
/// los compromisos con fecha.
class InicioScreen extends ConsumerStatefulWidget {
  const InicioScreen({super.key});

  @override
  ConsumerState<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends ConsumerState<InicioScreen> {
  late final AppLifecycleListener _cicloDeVida;

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

    // La agenda se mueve desde el panel admin mientras el app está en segundo
    // plano. La web se enteraba por realtime sobre `reservas_citas`, que aquí no
    // aplica (suscribirse a una tabla rompe "cero queries a tablas"), y un timer
    // periódico gastaría batería pegándole a producción sin nadie mirando: se
    // recarga al volver al frente y ya.
    _cicloDeVida = AppLifecycleListener(onResume: _alVolverAlFrente);
  }

  @override
  void dispose() {
    _cicloDeVida.dispose();
    super.dispose();
  }

  void _alVolverAlFrente() {
    if (!mounted) return;
    ref.invalidate(resumenInicioProvider);
  }

  /// Registra el clic de un CTA. No se espera: la telemetría se traga sus
  /// fallos y nunca retrasa la acción que la disparó.
  void _cta(String elementoId, String etiqueta) {
    unawaited(
      ref
          .read(telemetriaPortProvider)
          .registrarCta(
            pagina: _paginaCta,
            elementoId: elementoId,
            etiqueta: etiqueta,
          ),
    );
  }

  /// El tablero y la activación se recargan JUNTOS: refrescar solo los números
  /// deja el banner y el porcentaje viejos después de completar un paso del
  /// expediente.
  Future<void> _recargar() async {
    ref.invalidate(sesionProvider);
    ref.invalidate(resumenInicioProvider);
    try {
      await ref.read(resumenInicioProvider.future);
    } catch (_) {
      // El error ya lo pinta la pantalla; aquí solo se cierra el gesto.
    }
  }

  /// Alta de prospecto con el MISMO formulario de la cartera: el atajo es para
  /// capturar en el momento, no para ir a mirar la lista.
  Future<void> _nuevoProspecto() async {
    final guardado = await editarProspecto(context);
    if (guardado != true || !mounted) return;
    ref.invalidate(carteraProspectosProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Prospecto guardado')));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final resumen = ref.watch(resumenInicioProvider);

    // El nombre y el rol para el encabezado salen del bootstrap del portal (una
    // sola llamada al entrar), no del tablero: así el saludo se pinta completo
    // desde el primer frame aunque los números tarden.
    final sesion = ref.watch(sesionProvider);
    final header = sesion.valueOrNull?.header;
    final identidad = ref.watch(identidadAgenteProvider);
    final onboarding = ref.watch(onboardingProvider);
    final permisos = ref.watch(permisosVistaProvider(VistaAgente.inicio));
    final modo = ref.watch(modoPresentacionProvider);

    // Los números llevan al desglose de Comisiones. Si esa vista está recortada
    // (el agente dependiente no cobra: le factura su inmobiliaria), las tarjetas
    // dejan de ser tocables en vez de mandar a una ruta que el portal esconde.
    final verComisiones =
        sesion.valueOrNull?.vistaVisible(VistaAgente.comisiones) ?? false;

    final nombre = header?.nombre?.trim().isNotEmpty == true
        ? header!.nombre!.trim()
        : 'Agente';
    final rol = header?.rol ?? identidad?.rolNombre ?? 'Agente';

    // La insignia de verificación es del aliado externo, igual que el banner de
    // activación: es el único con expediente que verificar.
    final esAliadoExterno = identidad?.esAgenteInmobiliario == true;

    return Scaffold(
      // Sin `backgroundColor`: el fondo sale del tema, que es el MISMO neutro que
      // pinta el shell del portal. Preguntar por el modo portal para forzar
      // transparente no cambiaría un pixel y ataría la pantalla al layout.
      //
      // La barra se colapsa sola en modo portal: ahí el título y la campana los
      // pinta el shell.
      appBar: const PortalTopBar(title: 'Inicio'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _recargar,
          child: ContentFrame(
            maxWidth: _anchoContenido,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                t.space.md,
                t.space.sm,
                t.space.md,
                t.space.xxl,
              ),
              children: [
                SaludoAgente(
                  nombre: nombre,
                  rol: rol,
                  propiedadesActivas: modo.enmascarar(
                    '${resumen.valueOrNull?.propiedadesActivas ?? 0}',
                  ),
                  ultimoAcceso: resumen.valueOrNull?.ultimoAcceso,
                  verificado: esAliadoExterno ? onboarding.verificado : null,
                ),

                // Activación: solo el aliado externo tiene expediente que
                // completar, y solo mientras no esté al 100%.
                if (esAliadoExterno && onboarding.porcentaje < 100) ...[
                  SizedBox(height: t.space.md),
                  BannerActivacion(
                    porcentaje: onboarding.porcentaje,
                    capacitacionCompleta: onboarding.capacitacionCompleta,
                    identidadBasicaCompleta: onboarding.identidadBasicaCompleta,
                    esDependiente: identidad?.esDependiente ?? false,
                    onCompletar: () {
                      _cta('btn_completar_perfil', 'Completar ahora');
                      context.go(_rutaPerfil);
                    },
                  ),
                ],

                // Atajos de captura: fuera del `when` porque no dependen de los
                // números. Con la red caída el agente sigue pudiendo capturar.
                if (permisos.crear) ...[
                  SizedBox(height: t.space.md),
                  _Atajos(
                    onNuevoProspecto: () {
                      _cta('btn_nuevo_prospecto', 'Nuevo prospecto');
                      unawaited(_nuevoProspecto());
                    },
                    onAgendar: () {
                      _cta('btn_agendar_cita', 'Agendar cita');
                      unawaited(_agendar(context, ref));
                    },
                  ),
                ],

                SizedBox(height: t.space.xs),
                _TituloSeccion(
                  texto: 'Tus números',
                  accion: const ModoPresentacionInsignia(),
                ),

                ...resumen.when(
                  loading: () => const [_KpisCargando()],
                  error: (e, _) => [
                    EstadoErrorAgente(
                      error: e,
                      onReintentar: () => ref.invalidate(resumenInicioProvider),
                    ),
                  ],
                  data: (data) => [
                    _Kpis(
                      kpis: data.kpis,
                      enmascarar: modo.enmascarar,
                      onVerComisiones: verComisiones
                          ? () => context.go(_rutaComisiones)
                          : null,
                    ),
                    if (data.citas.isNotEmpty) ...[
                      // Sin conteo, como la web: el número de la agenda completa
                      // no cuadra con las tres citas que se alcanzan a ver.
                      const _TituloSeccion(texto: 'Citas'),
                      _Citas(
                        citas: ref.watch(citasInicioProvider),
                        enmascarar: modo.enmascararOpcional,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Encabezado de bloque con una acción opcional a la derecha.
class _TituloSeccion extends StatelessWidget {
  final String texto;
  final Widget? accion;

  const _TituloSeccion({required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    final accion = this.accion;
    if (accion == null) return SSectionLabel(text: texto);

    // Wrap, y no el `trailing` de SSectionLabel: ese va sin flex y el aviso de
    // presentación no cabe al lado del título en un teléfono. Como la web
    // (`flex-wrap`), baja de línea en vez de desbordar.
    final t = context.s;
    return Wrap(
      spacing: t.space.xs,
      runSpacing: t.space.xxs,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SSectionLabel(text: texto),
        accion,
      ],
    );
  }
}

/// Los dos atajos de captura. En pantalla ancha van lado a lado; en teléfono,
/// apilados.
class _Atajos extends StatelessWidget {
  final VoidCallback onNuevoProspecto;
  final VoidCallback onAgendar;

  const _Atajos({required this.onNuevoProspecto, required this.onAgendar});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tarjetas = [
      TarjetaAccion(
        icono: Icons.person_add_alt_outlined,
        titulo: 'Nuevo prospecto',
        subtitulo: 'Captura un comprador potencial',
        onTap: onNuevoProspecto,
      ),
      TarjetaAccion(
        icono: Icons.event_available_outlined,
        titulo: 'Agendar cita',
        subtitulo: 'Coordina una visita al desarrollo',
        onTap: onAgendar,
      ),
    ];

    if (!context.bp.hasTwoColumns) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tarjetas.first,
          SizedBox(height: t.space.sm),
          tarjetas.last,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: tarjetas.first),
        SizedBox(width: t.space.sm),
        Expanded(child: tarjetas.last),
      ],
    );
  }
}

/// Los cuatro números, en dos columnas en teléfono y cuatro en pantalla ancha.
class _Kpis extends StatelessWidget {
  final KpisAgente kpis;
  final String Function(String) enmascarar;
  final VoidCallback? onVerComisiones;

  const _Kpis({
    required this.kpis,
    required this.enmascarar,
    this.onVerComisiones,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final columnas = context.responsive(mobile: 2, desktop: 4);
    final tarjetas = <Widget>[
      TarjetaKpi(
        etiqueta: 'Comisión pagada',
        valor: enmascarar(formatMXN(kpis.comisionPagada)),
        detalle: 'cobrado',
        tono: TonoKpi.logro,
        onTap: onVerComisiones,
      ),
      TarjetaKpi(
        etiqueta: 'Comisión pendiente',
        valor: enmascarar(formatMXN(kpis.comisionPendiente)),
        detalle: 'por cobrar',
        tono: TonoKpi.pendiente,
        onTap: onVerComisiones,
      ),
      TarjetaKpi(
        etiqueta: 'Ventas activas',
        valor: enmascarar('${kpis.ventasActivas}'),
        detalle: 'en proceso',
        tono: TonoKpi.logro,
        onTap: onVerComisiones,
      ),
      TarjetaKpi(
        etiqueta: 'Ventas cerradas',
        valor: enmascarar('${kpis.ventasCerradas}'),
        detalle: 'completadas',
        onTap: onVerComisiones,
      ),
    ];

    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho =
            (restricciones.maxWidth - t.space.sm * (columnas - 1)) / columnas;
        return Wrap(
          spacing: t.space.sm,
          runSpacing: t.space.sm,
          children: [
            for (final tarjeta in tarjetas)
              SizedBox(width: ancho, child: tarjeta),
          ],
        );
      },
    );
  }
}

/// Placeholder de los cuatro números mientras cargan.
class _KpisCargando extends StatelessWidget {
  const _KpisCargando();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final columnas = context.responsive(mobile: 2, desktop: 4);
    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho =
            (restricciones.maxWidth - t.space.sm * (columnas - 1)) / columnas;
        return Wrap(
          spacing: t.space.sm,
          runSpacing: t.space.sm,
          children: [
            for (var i = 0; i < 4; i++)
              SizedBox(
                width: ancho,
                // Mismo alto que la tarjeta real: un skeleton más corto hace
                // saltar la lista al llegar los datos.
                child: SSkeleton(height: 104, radius: t.radius.lg),
              ),
          ],
        );
      },
    );
  }
}

/// Las citas próximas, con su detalle y la baja.
class _Citas extends ConsumerWidget {
  final List<CitaAgente> citas;
  final String? Function(String?) enmascarar;

  const _Citas({required this.citas, required this.enmascarar});

  /// Reagendar es agendar de nuevo sobre el mismo prospecto y desarrollo, con
  /// una excepción que también hace la web: la capacitación del agente no vive
  /// en la agenda de showroom, así que se manda a su paso del expediente.
  void _reagendar(BuildContext context, WidgetRef ref, CitaAgente cita) {
    if (cita.idTipoCita == kTipoCitaCapacitacion) {
      context.push(_rutaCapacitacion);
      return;
    }
    final idProspecto = cita.idPersonaProspecto;
    final idDesarrollo = cita.idProyecto;
    _agendar(
      context,
      ref,
      reagendar: true,
      // Sin ids no hay nada que precargar: la hoja los pide como si fuera una
      // cita nueva en vez de mandar al servidor un reagendado incompleto.
      prospecto: idProspecto == null
          ? null
          : ProspectoParaCita(
              idPersona: idProspecto,
              nombre: cita.prospectoNombre ?? 'Prospecto',
              desarrollos: idDesarrollo == null
                  ? const []
                  : [
                      DesarrolloParaCita(
                        id: idDesarrollo,
                        nombre: cita.proyectoNombre ?? 'Desarrollo',
                      ),
                    ],
            ),
      desarrollo: idDesarrollo == null
          ? null
          : DesarrolloParaCita(
              id: idDesarrollo,
              nombre: cita.proyectoNombre ?? 'Desarrollo',
            ),
    );
  }

  Future<void> _abrirDetalle(
    BuildContext context,
    WidgetRef ref,
    CitaAgente cita,
  ) async {
    final cancelada = await mostrarDetalleCita(
      context,
      cita: cita,
      nombreProspecto: enmascarar(cita.prospectoNombre),
      onReagendar: () => _reagendar(context, ref, cita),
      onCancelar: () async {
        try {
          await ref.read(inicioPortProvider).cancelarCita(cita.id);
          return null;
        } catch (e) {
          return mensajeAccionFallida(
            e,
            porCodigo: const {
              'cita_pasada': 'Esta cita ya pasó y no se puede cancelar.',
              'cita_no_cancelable': 'Esta cita ya no se puede cancelar.',
              'not_found': 'La cita ya no existe.',
            },
            generico: 'No pudimos cancelar la cita. Intenta de nuevo.',
          );
        }
      },
    );
    if (cancelada != true || !context.mounted) return;
    ref.invalidate(resumenInicioProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cita cancelada.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    return SStaggered(
      children: [
        for (final cita in citas)
          Padding(
            padding: EdgeInsets.only(bottom: t.space.sm),
            child: TarjetaCita(
              cita: cita,
              nombreProspecto: enmascarar(cita.prospectoNombre),
              onTap: () => _abrirDetalle(context, ref, cita),
            ),
          ),
      ],
    );
  }
}
