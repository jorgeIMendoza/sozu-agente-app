import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/citas/ports/citas_port.dart';
import 'package:sozu_agente_app/features/agente/citas/providers/citas_providers.dart';
import 'package:sozu_agente_app/features/agente/citas/services/seleccion_de_cita.dart';
import 'package:sozu_agente_app/features/agente/citas/services/textos_de_agenda.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Ancho del diálogo en pantalla ancha; el mismo del modal del portal web.
const double _anchoDialogo = 480;

/// Fechas que se ofrecen como pastilla antes de mandar al calendario. La
/// disponibilidad llega a 60 días: pintarlas todas es un muro de pastillas.
const int _maxFechasVisibles = 8;

/// Umbral para cambiar el selector de prospecto por un buscador, igual que el
/// portal web.
const int _maxProspectosEnLista = 10;

/// Abre el agendado de una cita al showroom: diálogo centrado en pantalla ancha,
/// hoja inferior en teléfono.
///
/// Devuelve la cita agendada, o null si el agente cerró sin guardar. Con
/// [prospecto] o [desarrollo] esos campos llegan resueltos y quedan de solo
/// lectura; [reagendar] solo cambia los textos y la acción del servidor.
Future<CitaAgendada?> mostrarAgendarCita(
  BuildContext context, {
  ProspectoParaCita? prospecto,
  DesarrolloParaCita? desarrollo,
  bool reagendar = false,
}) {
  final cuerpo = _AgendarCita(
    prospecto: prospecto,
    desarrollo: desarrollo,
    reagendar: reagendar,
  );

  if (context.bp.hasTwoColumns) {
    return showDialog<CitaAgendada>(
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
  return showModalBottomSheet<CitaAgendada>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.s.color.surface,
    builder: (_) => cuerpo,
  );
}

class _AgendarCita extends ConsumerStatefulWidget {
  final ProspectoParaCita? prospecto;
  final DesarrolloParaCita? desarrollo;
  final bool reagendar;

  const _AgendarCita({this.prospecto, this.desarrollo, this.reagendar = false});

  @override
  ConsumerState<_AgendarCita> createState() => _AgendarCitaState();
}

class _AgendarCitaState extends ConsumerState<_AgendarCita> {
  final _notas = TextEditingController();

  ProspectoParaCita? _prospecto;
  DesarrolloParaCita? _desarrollo;

  /// `YYYY-MM-DD` del día elegido.
  String? _fecha;

  int? _hora;
  int? _idConfiguracion;

  bool _guardando = false;
  String? _error;

  /// Vino resuelto de quien abrió la hoja: se muestra, no se elige.
  bool get _prospectoFijo => widget.prospecto != null;
  bool get _desarrolloFijo => widget.desarrollo != null;

  @override
  void initState() {
    super.initState();
    _prospecto = widget.prospecto;
    _desarrollo = widget.desarrollo ?? _unicoDesarrollo(widget.prospecto);
  }

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  /// El desarrollo del prospecto cuando no hay nada que elegir.
  DesarrolloParaCita? _unicoDesarrollo(ProspectoParaCita? p) =>
      p != null && p.desarrollos.length == 1 ? p.desarrollos.first : null;

  void _elegirProspecto(ProspectoParaCita? p) {
    setState(() {
      _prospecto = p;
      _desarrollo = widget.desarrollo ?? _unicoDesarrollo(p);
      _fecha = null;
      _hora = null;
      _idConfiguracion = null;
      _error = null;
    });
  }

  void _elegirDesarrollo(DesarrolloParaCita? d) {
    setState(() {
      _desarrollo = d;
      _fecha = null;
      _hora = null;
      _idConfiguracion = null;
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

  bool get _listaParaGuardar =>
      _prospecto != null &&
      _desarrollo != null &&
      _fecha != null &&
      _hora != null &&
      _idConfiguracion != null;

  Future<void> _guardar() async {
    if (!_listaParaGuardar) return;
    setState(() {
      _guardando = true;
      _error = null;
    });

    final solicitud = SolicitudDeCita(
      idPersonaProspecto: _prospecto!.idPersona,
      idDesarrollo: _desarrollo!.id,
      fecha: _fecha!,
      horaInicio: '${_hora!.toString().padLeft(2, '0')}:00',
      idConfiguracion: _idConfiguracion!,
      notas: _notas.text,
    );

    try {
      final port = ref.read(citasPortProvider);
      final cita = widget.reagendar
          ? await port.reagendar(solicitud)
          : await port.agendar(solicitud);
      if (!mounted) return;
      Navigator.of(context).pop(cita);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeErrorAgenda(e);
      });
      // El cupo pudo quedar tomado por alguien más: la siguiente lectura de la
      // disponibilidad tiene que salir del servidor, no de la caché.
      ref.invalidate(disponibilidadProvider(solicitud.idDesarrollo));
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
          _Encabezado(
            titulo: widget.reagendar ? 'Reagendar cita' : 'Agendar cita',
            subtitulo: widget.reagendar
                ? 'Elige la nueva fecha y el nuevo horario'
                : 'Coordina una visita al desarrollo',
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
            // Los dos botones se reparten el ancho: en teléfono, a su tamaño
            // natural, "Agendar cita" ya no cabe junto a "Cancelar".
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
                    label: widget.reagendar ? 'Reagendar' : 'Agendar cita',
                    loading: _guardando,
                    loadingLabel: 'Agendando…',
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
    final desarrollo = _desarrollo;

    return [
      if (_error case final mensaje?) ...[
        _Aviso(icono: Icons.error_outline, texto: mensaje, esError: true),
        SizedBox(height: t.space.md),
      ],

      SFieldLabel('Prospecto', requerido: true, habilitado: !_guardando),
      _selectorProspecto(context),
      SizedBox(height: t.space.md),

      // El desarrollo se pinta en cuanto hay de dónde sacarlo: fijo desde la
      // ficha del desarrollo, o los intereses del prospecto ya elegido.
      if (_prospecto != null || _desarrolloFijo) ...[
        SFieldLabel('Desarrollo', requerido: true, habilitado: !_guardando),
        _selectorDesarrollo(context),
        SizedBox(height: t.space.md),
      ],

      if (desarrollo != null) ..._agenda(context, desarrollo),

      SFieldLabel('Notas (opcional)', habilitado: !_guardando),
      STextField(
        controller: _notas,
        hint: 'El prospecto prefiere la tarde y viene acompañado.',
        size: STextFieldSize.md,
        maxLines: 4,
        enabled: !_guardando,
        textCapitalization: TextCapitalization.sentences,
      ),
    ];
  }

  /// El prospecto: fijo cuando lo trajo la pantalla; si no, la cartera del
  /// agente en un selector (o un buscador cuando es larga).
  Widget _selectorProspecto(BuildContext context) {
    if (_prospectoFijo) return _CampoFijo(texto: _prospecto!.nombre);

    final prospectos = ref.watch(prospectosParaCitaProvider);
    return prospectos.when(
      loading: () => const SSkeleton(height: 44),
      error: (e, _) => SErrorState(
        title: 'No pudimos cargar tus prospectos',
        message: mensajeErrorAgenda(e),
        onRetry: () => ref.invalidate(carteraProspectosProvider),
      ),
      data: (lista) {
        if (lista.isEmpty) {
          return const SEmptyState.card(
            icon: Icons.person_off_outlined,
            title: 'Todavía no tienes prospectos',
            message: 'Captura un prospecto y vuelve a agendar su visita.',
          );
        }
        if (lista.length > _maxProspectosEnLista) {
          return SAutocompleteField<ProspectoParaCita>(
            options: lista,
            value: _prospecto,
            labelOf: (p) => p.nombre,
            hintText: 'Busca a tu prospecto…',
            prefixIcon: Icons.person_outline,
            enabled: !_guardando,
            onSelected: _elegirProspecto,
          );
        }
        return SSelectField<int>(
          value: _prospecto?.idPersona,
          hint: 'Elige a tu prospecto',
          opciones: [
            for (final p in lista) (value: p.idPersona, label: p.nombre),
          ],
          onChanged: _guardando
              ? null
              : (id) => _elegirProspecto(
                  lista.firstWhere((p) => p.idPersona == id),
                ),
        );
      },
    );
  }

  /// El desarrollo de la cita: fijo cuando lo trajo la pantalla o cuando el
  /// prospecto solo tiene uno.
  Widget _selectorDesarrollo(BuildContext context) {
    final opciones = _desarrolloFijo
        ? const <DesarrolloParaCita>[]
        : _prospecto?.desarrollos ?? const <DesarrolloParaCita>[];

    if (_desarrolloFijo || opciones.length == 1) {
      return _CampoFijo(
        texto: _desarrollo?.nombre ?? 'Sin desarrollo',
        icono: Icons.apartment_outlined,
      );
    }
    if (opciones.isEmpty) {
      return _Aviso(
        icono: Icons.info_outline,
        texto:
            'Este prospecto no tiene desarrollos de interés. Agrégalos en su '
            'ficha para poder agendar.',
      );
    }
    return SSelectField<int>(
      value: _desarrollo?.id,
      hint: 'Elige el desarrollo',
      opciones: [for (final d in opciones) (value: d.id, label: d.nombre)],
      onChanged: _guardando
          ? null
          : (id) => _elegirDesarrollo(opciones.firstWhere((d) => d.id == id)),
    );
  }

  /// Fecha y horario: los dos salen de la misma disponibilidad, así que se
  /// piden juntos y comparten los estados de carga y error.
  List<Widget> _agenda(BuildContext context, DesarrolloParaCita desarrollo) {
    final t = context.s;
    final disponibilidad = ref.watch(disponibilidadProvider(desarrollo.id));

    return disponibilidad.when(
      loading: () => [
        SFieldLabel('Fecha', requerido: true, habilitado: false),
        const SSkeleton(height: 44),
        SizedBox(height: t.space.md),
      ],
      error: (e, _) => [
        SErrorState(
          title: 'No pudimos cargar los horarios',
          message: mensajeErrorAgenda(e),
          onRetry: () => ref.invalidate(disponibilidadProvider(desarrollo.id)),
        ),
        SizedBox(height: t.space.md),
      ],
      data: (dias) {
        if (dias.isEmpty) {
          return [
            SEmptyState.card(
              icon: Icons.event_busy_outlined,
              title: 'Sin fechas disponibles',
              message:
                  '${desarrollo.nombre} no tiene horarios abiertos en los '
                  'próximos días. Escribe a tu Asesor SOZU.',
            ),
            SizedBox(height: t.space.md),
          ];
        }

        final dia = dias.where((d) => d.fecha == _fecha).firstOrNull;
        return [
          SFieldLabel('Fecha', requerido: true, habilitado: !_guardando),
          _Fechas(
            dias: dias,
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
            _Horarios(
              dia: dia,
              hora: _hora,
              idConfiguracion: _idConfiguracion,
              habilitado: !_guardando,
              onElegir: _elegirHorario,
            ),
            SizedBox(height: t.space.md),
          ],
        ];
      },
    );
  }
}

/// Encabezado de la hoja: título, subtítulo y la salida.
class _Encabezado extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final bool habilitado;

  const _Encabezado({
    required this.titulo,
    required this.subtitulo,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Padding(
      padding: EdgeInsets.fromLTRB(t.space.lg, t.space.md, t.space.xs, 0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(t.space.xs),
            decoration: BoxDecoration(
              color: tone.surfaceAlt,
              borderRadius: t.radius.smBorder,
            ),
            child: Icon(
              Icons.event_available_outlined,
              size: _iconoChico,
              color: tone.fgMuted,
            ),
          ),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: t.text.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone.fg,
                  ),
                ),
                Text(
                  subtitulo,
                  style: t.text.caption.copyWith(color: tone.fgSubtle),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close, size: _iconoMedio),
            color: tone.fgMuted,
            onPressed: habilitado ? () => Navigator.of(context).pop() : null,
          ),
        ],
      ),
    );
  }
}

/// Las fechas con cupo: pastillas para las más próximas y el calendario para el
/// resto de la ventana que abrió el showroom.
class _Fechas extends StatelessWidget {
  final List<DiaDisponible> dias;
  final String? fecha;
  final bool habilitado;
  final ValueChanged<String> onElegir;

  const _Fechas({
    required this.dias,
    required this.fecha,
    required this.onElegir,
    this.habilitado = true,
  });

  Future<void> _abrirCalendario(BuildContext context) async {
    final disponibles = {for (final d in dias) d.fecha};
    final primera = fechaDeAgenda(dias.first.fecha);
    final ultima = fechaDeAgenda(dias.last.fecha);
    if (primera == null || ultima == null) return;

    final elegida = await showDatePicker(
      context: context,
      initialDate: fechaDeAgenda(fecha) ?? primera,
      firstDate: primera,
      lastDate: ultima,
      helpText: 'Elige la fecha de la cita',
      selectableDayPredicate: (d) => disponibles.contains(isoDeFecha(d)),
    );
    if (elegida != null) onElegir(isoDeFecha(elegida));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // La fecha elegida siempre se ve, aunque venga del calendario y quede fuera
    // de las primeras: si no, la selección desaparece de la pantalla.
    final visibles = <DiaDisponible>[
      ...dias.take(_maxFechasVisibles),
      if (fecha != null &&
          !dias.take(_maxFechasVisibles).any((d) => d.fecha == fecha))
        ...dias.where((d) => d.fecha == fecha),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: t.space.xs,
          runSpacing: t.space.xs,
          children: [
            for (final d in visibles)
              SChoiceChip(
                label: etiquetaDiaCorto(d.fecha),
                selected: d.fecha == fecha,
                enabled: habilitado,
                size: SChoiceChipSize.sm,
                onSelected: (_) => onElegir(d.fecha),
              ),
          ],
        ),
        if (dias.length > _maxFechasVisibles) ...[
          SizedBox(height: t.space.xs),
          SButton(
            label: 'Ver todas las fechas (${dias.length})',
            icon: Icons.calendar_month_outlined,
            variant: SButtonVariant.ghost,
            size: SButtonSize.sm,
            fullWidth: false,
            onPressed: habilitado ? () => _abrirCalendario(context) : null,
          ),
        ],
      ],
    );
  }
}

/// Los horarios del día elegido, agrupados por agenda: el nombre y el
/// responsable son lo que distingue dos cupos a la misma hora.
class _Horarios extends StatelessWidget {
  final DiaDisponible dia;
  final int? hora;
  final int? idConfiguracion;
  final bool habilitado;
  final ValueChanged<HorarioDisponible> onElegir;

  const _Horarios({
    required this.dia,
    required this.hora,
    required this.idConfiguracion,
    required this.onElegir,
    this.habilitado = true,
  });

  /// Horarios por configuración, conservando el orden que mandó el servidor.
  Map<int, List<HorarioDisponible>> get _porAgenda {
    final salida = <int, List<HorarioDisponible>>{};
    for (final h in dia.horarios) {
      salida.putIfAbsent(h.idConfiguracion, () => []).add(h);
    }
    return salida;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    if (dia.horarios.isEmpty) {
      return const SEmptyState.card(
        icon: Icons.schedule_outlined,
        title: 'Sin horarios ese día',
        message: 'Elige otra fecha.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final grupo in _porAgenda.entries)
          Padding(
            padding: EdgeInsets.only(bottom: t.space.xs),
            child: Container(
              padding: EdgeInsets.all(t.space.sm),
              decoration: BoxDecoration(
                color: tone.surfaceAlt,
                borderRadius: t.radius.mdBorder,
                border: Border.all(color: tone.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grupo.value.first.configuracion ?? 'Agenda del showroom',
                    style: t.text.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tone.fg,
                    ),
                  ),
                  if (grupo.value.first.responsable case final quien?)
                    Text(
                      'Responsable: $quien',
                      style: t.text.caption.copyWith(color: tone.fgMuted),
                    ),
                  SizedBox(height: t.space.xs),
                  Wrap(
                    spacing: t.space.xs,
                    runSpacing: t.space.xs,
                    children: [
                      for (final h in grupo.value)
                        SChoiceChip(
                          label: h.etiqueta,
                          selected:
                              h.hora == hora &&
                              h.idConfiguracion == idConfiguracion,
                          enabled: habilitado,
                          size: SChoiceChipSize.sm,
                          onSelected: (_) => onElegir(h),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Dato que ya viene resuelto: se lee, no se elige.
class _CampoFijo extends StatelessWidget {
  final String texto;
  final IconData? icono;

  const _CampoFijo({required this.texto, this.icono});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Container(
      constraints: const BoxConstraints(minHeight: _altoCampo),
      padding: EdgeInsets.symmetric(horizontal: t.space.sm),
      decoration: BoxDecoration(
        color: tone.muted,
        borderRadius: t.radius.mdBorder,
        border: Border.all(color: tone.border),
      ),
      child: Row(
        children: [
          if (icono != null) ...[
            Icon(icono, size: _iconoChico, color: tone.fgMuted),
            SizedBox(width: t.space.xs),
          ],
          Expanded(
            child: Text(
              texto,
              style: t.text.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: tone.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloque teñido de información o de error dentro de la hoja.
class _Aviso extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool esError;

  const _Aviso({
    required this.icono,
    required this.texto,
    this.esError = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final acento = esError ? tone.danger : tone.warningFg;
    return Container(
      padding: EdgeInsets.all(t.space.sm),
      decoration: BoxDecoration(
        color: esError ? tone.dangerSoft : tone.warningSoft,
        borderRadius: t.radius.mdBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: _iconoChico, color: acento),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(texto, style: t.text.caption.copyWith(color: acento)),
          ),
        ],
      ),
    );
  }
}

/// Icono dentro de una línea de texto.
const double _iconoChico = 18;

/// Icono de un control (cerrar).
const double _iconoMedio = 20;

/// Alto mínimo de un campo, el mismo de `STextField` en tamaño md.
const double _altoCampo = 44;
