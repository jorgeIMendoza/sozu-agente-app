import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/home/components/modo_presentacion_boton.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// "Hoy 9:30 am" cuando el acceso fue hoy; si no, "11 feb 2026".
///
/// La hora sola no dice nada un día después, y la fecha sola no distingue "hace
/// diez minutos" de "esta mañana": cada caso muestra el dato que informa.
String etiquetaUltimoAcceso(DateTime? momento) {
  if (momento == null) return '';
  final local = momento.toLocal();
  final ahora = DateTime.now();
  final esHoy =
      local.year == ahora.year &&
      local.month == ahora.month &&
      local.day == ahora.day;
  if (!esHoy) return formatDateEsMX(local);
  final sufijo = local.hour < 12 ? 'am' : 'pm';
  final hora = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minutos = local.minute.toString().padLeft(2, '0');
  return 'Hoy $hora:$minutos $sufijo';
}

/// Encabezado de Inicio: nombre del agente y, en una línea de metadatos, su rol,
/// cuántas propiedades trae activas y cuándo entró la última vez.
///
/// Espejo del encabezado del portal web. El conteo de propiedades va enmascarado
/// igual que los montos: delante de un prospecto, "3 propiedades activas" dice
/// cuánto vende el agente.
class SaludoAgente extends StatelessWidget {
  final String nombre;
  final String rol;

  /// Ya enmascarado por la pantalla si el modo presentación está activo.
  final String propiedadesActivas;

  final DateTime? ultimoAcceso;

  const SaludoAgente({
    super.key,
    required this.nombre,
    required this.rol,
    required this.propiedadesActivas,
    this.ultimoAcceso,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final acceso = etiquetaUltimoAcceso(ultimoAcceso);

    Widget separador() => Text(
      '·',
      style: t.text.caption.copyWith(color: tone.fgSubtle),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.text.h3.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tone.fg,
                ),
              ),
              SizedBox(height: t.space.xxs),
              // Wrap y no Row: en un teléfono angosto los tres metadatos no
              // caben en una línea, y truncarlos se come el último acceso.
              Wrap(
                spacing: t.space.xs,
                runSpacing: t.space.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    rol,
                    style: t.text.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tone.primaryHover,
                    ),
                  ),
                  separador(),
                  Text(
                    '$propiedadesActivas propiedades activas',
                    style: t.text.caption.copyWith(color: tone.fgMuted),
                  ),
                  if (acceso.isNotEmpty) ...[
                    separador(),
                    Text(
                      'Último acceso: $acceso',
                      style: t.text.caption.copyWith(color: tone.fgSubtle),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const ModoPresentacionBoton(),
      ],
    );
  }
}
