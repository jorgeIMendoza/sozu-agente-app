import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/citas/components/piezas_de_agenda.dart';
import 'package:sozu_agente_app/features/agente/citas/ports/citas_port.dart';
import 'package:sozu_agente_app/features/agente/citas/providers/citas_providers.dart';
import 'package:sozu_agente_app/features/agente/citas/services/textos_de_agenda.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Ancho del diálogo en pantalla ancha; el mismo del modal del portal web.
const double _anchoDialogo = 480;

/// Hasta cuándo hacia atrás se puede reportar una asistencia.
const int _diasHaciaAtras = 365;

/// Lo que dejó la hoja de capacitación: la cita agendada o el reporte de
/// asistencia.
class ResultadoDeCapacitacion {
  final CitaAgendada? cita;
  final AsistenciaReportada? asistencia;

  const ResultadoDeCapacitacion({this.cita, this.asistencia});

  /// Confirmación para el agente, ya en su idioma.
  String get mensaje {
    final agendada = cita;
    if (agendada != null) {
      return agendada.aviso ?? 'Capacitación agendada.';
    }
    if (asistencia?.yaReportada ?? false) {
      return 'Ya habías reportado tu asistencia de ese día.';
    }
    return 'Asistencia reportada. Falta que un administrador la confirme.';
  }
}

/// Abre la capacitación del agente: diálogo centrado en pantalla ancha, hoja
/// inferior en teléfono.
///
/// Devuelve qué quedó, o null si el agente cerró sin guardar. Con
/// [reportarAsistencia] la hoja abre en "Ya acudí".
Future<ResultadoDeCapacitacion?> mostrarAgendarCapacitacion(
  BuildContext context, {
  bool reportarAsistencia = false,
}) {
  final cuerpo = _AgendarCapacitacion(reportarAsistencia: reportarAsistencia);

  if (context.bp.hasTwoColumns) {
    return showDialog<ResultadoDeCapacitacion>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: context.s.color.surface,
        shape: RoundedRectangleBorder(
          borderRadius: context.s.radius.sheetBorder,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _anchoDialogo,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
          ),
          child: cuerpo,
        ),
      ),
    );
  }
  return showModalBottomSheet<ResultadoDeCapacitacion>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.s.color.surface,
    builder: (_) => cuerpo,
  );
}

/// Las dos cosas que el agente puede hacer con su capacitación, igual que el
/// segmentado del portal web.
enum _Modo { agendar, yaAcudi }

class _AgendarCapacitacion extends ConsumerStatefulWidget {
  final bool reportarAsistencia;

  const _AgendarCapacitacion({this.reportarAsistencia = false});

  @override
  ConsumerState<_AgendarCapacitacion> createState() =>
      _AgendarCapacitacionState();
}

class _AgendarCapacitacionState extends ConsumerState<_AgendarCapacitacion> {
  late _Modo _modo;

  /// `YYYY-MM-DD` del día elegido para agendar.
  String? _fecha;

  int? _hora;
  int? _idConfiguracion;

  /// `YYYY-MM-DD` en el que el agente dice que acudió.
  String? _fechaAsistencia;

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _modo = widget.reportarAsistencia ? _Modo.yaAcudi : _Modo.agendar;
  }

  void _cambiarModo(_Modo modo) {
    if (_guardando || modo == _modo) return;
    setState(() {
      _modo = modo;
      _error = null;
    });
  }

  void _elegirFecha(String? fecha) {
    setState(() {
      _fecha = fecha;
      _hora = null;
      _idConfiguracion = null;
    });
  }

  void _elegirHorario(HorarioDisponible h) {
    setState(() {
      _hora = h.hora;
      _idConfiguracion = h.idConfiguracion;
    });
  }

  bool get _listaParaGuardar => _modo == _Modo.agendar
      ? _fecha != null && _hora != null && _idConfiguracion != null
      : _fechaAsistencia != null;

  Future<void> _elegirFechaDeAsistencia() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: fechaDeAgenda(_fechaAsistencia) ?? hoy,
      firstDate: hoy.subtract(const Duration(days: _diasHaciaAtras)),
      lastDate: hoy,
      helpText: 'Elige la fecha en la que acudiste',
    );
    if (elegida == null) return;
    setState(() {
      _fechaAsistencia = isoDeFecha(elegida);
      _error = null;
    });
  }

  Future<void> _guardar() async {
    if (!_listaParaGuardar) return;
    setState(() {
      _guardando = true;
      _error = null;
    });

    final port = ref.read(citasPortProvider);
    try {
      if (_modo == _Modo.yaAcudi) {
        final asistencia = await port.reportarAsistencia(_fechaAsistencia!);
        if (!mounted) return;
        Navigator.of(
          context,
        ).pop(ResultadoDeCapacitacion(asistencia: asistencia));
        return;
      }

      final agenda = ref.read(agendaDeCapacitacionProvider).valueOrNull;
      final cita = await port.agendarCapacitacion(
        SolicitudDeCapacitacion(
          fecha: _fecha!,
          hora: '${_hora!.toString().padLeft(2, '0')}:00',
          idConfiguracion: _idConfiguracion!,
          idDesarrollo: agenda?.desarrolloPorConfiguracion[_idConfiguracion!],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(ResultadoDeCapacitacion(cita: cita));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = _modo == _Modo.yaAcudi
            ? mensajeErrorAsistencia(e)
            : mensajeErrorAgenda(e);
      });
      // El cupo pudo quedar tomado por alguien más: la siguiente lectura tiene
      // que salir del servidor, no de la caché.
      if (_modo == _Modo.agendar) ref.invalidate(agendaDeCapacitacionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return Padding(
      // El teclado tapa el pie del formulario en teléfono si no se compensa.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoDeHoja(
            titulo: 'Capacitación',
            subtitulo: 'Agenda tu cita o reporta que ya acudiste',
            icono: Icons.school_outlined,
            habilitado: !_guardando,
          ),
          Divider(color: tone.border, height: t.space.lg),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                t.space.lg,
                0,
                t.space.lg,
                t.space.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _campos(context),
              ),
            ),
          ),
          Container(
            padding: t.space.allMd,
            decoration: BoxDecoration(
              color: tone.surfaceAlt,
              border: Border(top: BorderSide(color: tone.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SButton.secondary(
                    label: 'Cancelar',
                    onPressed: _guardando
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: t.space.sm),
                Expanded(
                  child: SButton(
                    label: _modo == _Modo.yaAcudi ? 'Reportar' : 'Agendar cita',
                    loading: _guardando,
                    loadingLabel: _modo == _Modo.yaAcudi
                        ? 'Enviando…'
                        : 'Agendando…',
                    onPressed: _listaParaGuardar && !_guardando
                        ? _guardar
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _campos(BuildContext context) {
    final t = context.s;
    return [
      _Segmentado(
        modo: _modo,
        habilitado: !_guardando,
        onCambiar: _cambiarModo,
      ),
      SizedBox(height: t.space.md),

      if (_error case final mensaje?) ...[
        AvisoDeAgenda(
          icono: Icons.error_outline,
          texto: mensaje,
          esError: true,
        ),
        SizedBox(height: t.space.md),
      ],

      if (_modo == _Modo.yaAcudi)
        ..._asistencia(context)
      else
        ..._agenda(context),
    ];
  }

  /// "Ya acudí": la fecha y qué pasa después de mandarla.
  List<Widget> _asistencia(BuildContext context) {
    final t = context.s;
    return [
      SFieldLabel(
        '¿En qué fecha acudiste?',
        requerido: true,
        habilitado: !_guardando,
      ),
      SButton.secondary(
        label: _fechaAsistencia == null
            ? 'Elegir la fecha'
            : etiquetaDiaLargo(_fechaAsistencia),
        icon: Icons.calendar_month_outlined,
        onPressed: _guardando ? null : _elegirFechaDeAsistencia,
      ),
      SizedBox(height: t.space.md),
      const AvisoDeAgenda(
        icono: Icons.info_outline,
        texto:
            'Tu asistencia queda pendiente de que un administrador la '
            'confirme. Hasta entonces no cierra tu paso de capacitación.',
      ),
    ];
  }

  /// Agendar: fecha y horario salen de la misma disponibilidad, así que
  /// comparten los estados de carga y error.
  List<Widget> _agenda(BuildContext context) {
    final t = context.s;
    final agenda = ref.watch(agendaDeCapacitacionProvider);

    return agenda.when(
      loading: () => [
        SFieldLabel('Fecha', requerido: true, habilitado: false),
        const SSkeleton(height: 44),
      ],
      error: (e, _) => [
        SErrorState(
          title: 'No pudimos cargar los horarios',
          message: mensajeErrorAgenda(e),
          onRetry: () => ref.invalidate(agendaDeCapacitacionProvider),
        ),
      ],
      data: (datos) {
        if (datos.vacia) {
          return [
            const SEmptyState.card(
              icon: Icons.event_busy_outlined,
              title: 'Sin fechas disponibles',
              message:
                  'Todavía no hay horarios abiertos de capacitación. Escribe a '
                  'tu Asesor SOZU o reporta la fecha en la que ya acudiste.',
            ),
          ];
        }

        final dia = datos.dia(_fecha);
        return [
          SFieldLabel('Fecha', requerido: true, habilitado: !_guardando),
          FechasDisponibles(
            dias: datos.dias,
            fecha: _fecha,
            habilitado: !_guardando,
            onElegir: _elegirFecha,
          ),
          SizedBox(height: t.space.md),
          if (dia != null) ...[
            SFieldLabel(
              'Horario del ${etiquetaDiaLargo(dia.fecha)}',
              requerido: true,
              habilitado: !_guardando,
            ),
            HorariosDisponibles(
              dia: dia,
              hora: _hora,
              idConfiguracion: _idConfiguracion,
              habilitado: !_guardando,
              agendaSinNombre: 'Capacitación',
              onElegir: _elegirHorario,
            ),
            SizedBox(height: t.space.md),
          ],
          // El servidor MUEVE la cita que ya existe solo si el cupo nuevo es de
          // la misma agenda; en otra agenda quedan las dos, igual que la web.
          const AvisoDeAgenda(
            icono: Icons.info_outline,
            texto:
                'Si ya tienes una capacitación agendada, elegir un horario de '
                'la misma agenda la mueve. En otra agenda te quedan las dos.',
          ),
        ];
      },
    );
  }
}

/// Segmentado de dos vías: agendar o reportar que ya acudió.
class _Segmentado extends StatelessWidget {
  final _Modo modo;
  final bool habilitado;
  final ValueChanged<_Modo> onCambiar;

  const _Segmentado({
    required this.modo,
    required this.onCambiar,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      padding: EdgeInsets.all(t.space.xxs),
      decoration: BoxDecoration(
        color: t.color.surfaceAlt,
        borderRadius: t.radius.mdBorder,
      ),
      child: Row(
        children: [
          Expanded(
            child: _Pestana(
              etiqueta: 'Agendar cita',
              activa: modo == _Modo.agendar,
              habilitada: habilitado,
              onTap: () => onCambiar(_Modo.agendar),
            ),
          ),
          Expanded(
            child: _Pestana(
              etiqueta: 'Ya acudí',
              activa: modo == _Modo.yaAcudi,
              habilitada: habilitado,
              onTap: () => onCambiar(_Modo.yaAcudi),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una vía del segmentado. La activa levanta superficie; la otra se queda
/// transparente sobre la pista.
class _Pestana extends StatelessWidget {
  final String etiqueta;
  final bool activa;
  final bool habilitada;
  final VoidCallback onTap;

  const _Pestana({
    required this.etiqueta,
    required this.activa,
    required this.habilitada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return SPressable(
      onTap: habilitada ? onTap : null,
      borderRadius: t.radius.smBorder,
      hoverColor: tone.muted,
      semanticLabel: etiqueta,
      child: AnimatedContainer(
        duration: t.motion.fast,
        curve: t.motion.standard,
        padding: EdgeInsets.symmetric(vertical: t.space.xs),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activa ? tone.surface : Colors.transparent,
          borderRadius: t.radius.smBorder,
          boxShadow: activa ? t.shadow.sm : null,
        ),
        child: Text(
          etiqueta,
          style: t.text.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: activa ? tone.fg : tone.fgMuted,
          ),
        ),
      ),
    );
  }
}
