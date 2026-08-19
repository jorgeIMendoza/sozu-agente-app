import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/home/components/tarjeta_cita.dart';
import 'package:sozu_agente_app/features/agente/home/ports/inicio_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Abre el detalle de una cita: diálogo centrado en pantalla ancha, hoja
/// inferior en teléfono.
///
/// [onCancelar] hace la baja y devuelve el mensaje de error, o null si salió
/// bien. La hoja se queda abierta con el mensaje cuando falla: cerrarla obligaría
/// al agente a volver a buscar la cita para reintentar.
///
/// [onReagendar] se dispara con la hoja YA cerrada, porque el reagendado abre su
/// propia hoja y dos modales apilados dejan al agente sin saber cuál cierra.
///
/// Devuelve `true` si la cita quedó cancelada.
Future<bool?> mostrarDetalleCita(
  BuildContext context, {
  required CitaAgente cita,
  required String? nombreProspecto,
  required Future<String?> Function() onCancelar,
  VoidCallback? onReagendar,
}) {
  final cuerpo = _DetalleCita(
    cita: cita,
    nombreProspecto: nombreProspecto,
    onCancelar: onCancelar,
    onReagendar: onReagendar,
  );

  if (context.bp.hasTwoColumns) {
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: context.s.color.surface,
        shape: RoundedRectangleBorder(
          borderRadius: context.s.radius.sheetBorder,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: cuerpo,
        ),
      ),
    );
  }
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.s.color.surface,
    builder: (_) => SafeArea(child: cuerpo),
  );
}

class _DetalleCita extends StatefulWidget {
  final CitaAgente cita;
  final String? nombreProspecto;
  final Future<String?> Function() onCancelar;
  final VoidCallback? onReagendar;

  const _DetalleCita({
    required this.cita,
    required this.nombreProspecto,
    required this.onCancelar,
    this.onReagendar,
  });

  @override
  State<_DetalleCita> createState() => _DetalleCitaState();
}

class _DetalleCitaState extends State<_DetalleCita> {
  /// Cancelar una cita no se deshace, así que se pide confirmación en el mismo
  /// sitio en vez de abrir un segundo diálogo encima del primero.
  bool _confirmando = false;
  bool _cancelando = false;
  String? _error;

  void _reagendar() {
    final reagendar = widget.onReagendar;
    if (reagendar == null) return;
    Navigator.of(context).pop();
    reagendar();
  }

  Future<void> _cancelar() async {
    setState(() {
      _cancelando = true;
      _error = null;
    });
    final error = await widget.onCancelar();
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _cancelando = false;
        _confirmando = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final cita = widget.cita;
    final insignia = insigniaDeCita(cita.distintivo.tono);
    final prospecto = widget.nombreProspecto;
    final horario = cita.horario;
    final ubicacion = cita.ubicacion;
    final notas = cita.notas;

    return Padding(
      padding: EdgeInsets.all(t.space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cita.titulo,
                      style: t.text.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tone.fg,
                      ),
                    ),
                    SizedBox(height: t.space.xxs),
                    Text(
                      'Detalle de la cita',
                      style: t.text.caption.copyWith(color: tone.fgMuted),
                    ),
                  ],
                ),
              ),
              SizedBox(width: t.space.xs),
              SBadge(
                label: cita.distintivo.etiqueta,
                tone: insignia.tono,
                icon: insignia.icono,
              ),
            ],
          ),
          SizedBox(height: t.space.md),
          if (prospecto != null && prospecto.isNotEmpty)
            _Dato(
              icono: Icons.person_outline,
              etiqueta: 'Prospecto',
              valor: prospecto,
            ),
          _Dato(
            icono: Icons.calendar_today_outlined,
            etiqueta: 'Fecha',
            valor: formatDateEsMX(cita.fecha),
          ),
          if (horario != null)
            _Dato(
              icono: Icons.schedule_outlined,
              etiqueta: 'Horario',
              valor: horario,
            ),
          if (ubicacion != null && ubicacion.isNotEmpty)
            _Dato(
              icono: Icons.place_outlined,
              etiqueta: 'Ubicación',
              valor: ubicacion,
            ),
          if (notas != null && notas.isNotEmpty) ...[
            SizedBox(height: t.space.xs),
            Container(
              padding: EdgeInsets.all(t.space.sm),
              decoration: BoxDecoration(
                color: tone.surfaceAlt,
                borderRadius: t.radius.mdBorder,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NOTAS',
                    style: t.text.overline.copyWith(color: tone.fgMuted),
                  ),
                  SizedBox(height: t.space.xxs),
                  Text(notas, style: t.text.bodySmall.copyWith(color: tone.fg)),
                ],
              ),
            ),
          ],
          if (_confirmando) ...[
            SizedBox(height: t.space.md),
            _Aviso(
              icono: Icons.warning_amber_rounded,
              titulo: '¿Seguro que quieres cancelar esta cita?',
              detalle: 'No se puede deshacer.',
              fondo: tone.dangerSoft,
              acento: tone.danger,
            ),
          ],
          if (_error != null) ...[
            SizedBox(height: t.space.md),
            _Aviso(
              icono: Icons.error_outline,
              titulo: _error!,
              fondo: tone.dangerSoft,
              acento: tone.danger,
            ),
          ],
          if (cita.puedeCancelarse) ...[
            SizedBox(height: t.space.lg),
            if (_confirmando)
              Row(
                children: [
                  Expanded(
                    child: SButton.secondary(
                      label: 'No, volver',
                      onPressed: _cancelando
                          ? null
                          : () => setState(() => _confirmando = false),
                    ),
                  ),
                  SizedBox(width: t.space.sm),
                  Expanded(
                    child: SButton.danger(
                      label: 'Sí, cancelar',
                      loading: _cancelando,
                      loadingLabel: 'Cancelando…',
                      onPressed: _cancelar,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SButton.secondary(
                      label: 'Cancelar cita',
                      icon: Icons.event_busy_outlined,
                      color: tone.danger,
                      onPressed: () => setState(() => _confirmando = true),
                    ),
                  ),
                  if (widget.onReagendar != null) ...[
                    SizedBox(width: t.space.sm),
                    Expanded(
                      child: SButton.secondary(
                        label: 'Reagendar',
                        icon: Icons.event_repeat_outlined,
                        onPressed: _reagendar,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// Un dato del detalle: icono en caja, etiqueta chica y valor.
class _Dato extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;

  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.surfaceAlt,
              borderRadius: t.radius.mdBorder,
            ),
            child: Icon(icono, size: 16, color: tone.fgMuted),
          ),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta.toUpperCase(),
                  style: t.text.overline.copyWith(color: tone.fgMuted),
                ),
                Text(
                  valor,
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloque teñido de confirmación o de error dentro de la hoja.
class _Aviso extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? detalle;
  final Color fondo;
  final Color acento;

  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.fondo,
    required this.acento,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      padding: EdgeInsets.all(t.space.sm),
      decoration: BoxDecoration(color: fondo, borderRadius: t.radius.mdBorder),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: acento),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: t.color.fg,
                  ),
                ),
                if (detalle != null)
                  Text(detalle!, style: t.text.caption.copyWith(color: acento)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
