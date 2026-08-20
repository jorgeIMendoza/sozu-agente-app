import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/citas/ports/citas_port.dart';
import 'package:sozu_agente_app/features/agente/citas/services/textos_de_agenda.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Icono dentro de una línea de texto.
const double kIconoEnLinea = 18;

/// Icono de un control (cerrar).
const double kIconoDeControl = 20;

/// Fechas que se ofrecen como pastilla antes de mandar al calendario. La
/// disponibilidad llega a 60 días: pintarlas todas es un muro de pastillas.
const int kMaxFechasVisibles = 8;

/// Encabezado de una hoja de agenda: icono, título, subtítulo y la salida.
class EncabezadoDeHoja extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final bool habilitado;

  const EncabezadoDeHoja({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.icono = Icons.event_available_outlined,
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
            child: Icon(icono, size: kIconoEnLinea, color: tone.fgMuted),
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
            icon: const Icon(Icons.close, size: kIconoDeControl),
            color: tone.fgMuted,
            onPressed: habilitado ? () => Navigator.of(context).pop() : null,
          ),
        ],
      ),
    );
  }
}

/// Las fechas con cupo: pastillas para las más próximas y el calendario para el
/// resto de la ventana que abrió la agenda.
class FechasDisponibles extends StatelessWidget {
  final List<DiaDisponible> dias;
  final String? fecha;
  final bool habilitado;
  final ValueChanged<String> onElegir;

  const FechasDisponibles({
    super.key,
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
      ...dias.take(kMaxFechasVisibles),
      if (fecha != null &&
          !dias.take(kMaxFechasVisibles).any((d) => d.fecha == fecha))
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
        if (dias.length > kMaxFechasVisibles) ...[
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
class HorariosDisponibles extends StatelessWidget {
  final DiaDisponible dia;
  final int? hora;
  final int? idConfiguracion;
  final bool habilitado;

  /// Rótulo del grupo cuando la configuración no tiene nombre.
  final String agendaSinNombre;

  final ValueChanged<HorarioDisponible> onElegir;

  const HorariosDisponibles({
    super.key,
    required this.dia,
    required this.hora,
    required this.idConfiguracion,
    required this.onElegir,
    this.agendaSinNombre = 'Agenda del showroom',
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
                    grupo.value.first.configuracion ?? agendaSinNombre,
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

/// Bloque teñido de información o de error dentro de una hoja de agenda.
class AvisoDeAgenda extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool esError;

  const AvisoDeAgenda({
    super.key,
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
          Icon(icono, size: kIconoEnLinea, color: acento),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(texto, style: t.text.caption.copyWith(color: acento)),
          ),
        ],
      ),
    );
  }
}
