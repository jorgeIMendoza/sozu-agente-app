import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// "3:20 pm" a partir de una hora local.
String _hora12(DateTime d) {
  final sufijo = d.hour < 12 ? 'am' : 'pm';
  final hora = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$hora:${d.minute.toString().padLeft(2, '0')} $sufijo';
}

/// "Hoy 9:30 am" cuando el acceso fue hoy; si no, "11 ago 2026 3:20 pm".
///
/// La hora va en los dos casos, como en el portal web: la fecha sola no
/// distingue "entró temprano" de "acaba de salir", y ese es el dato con el que
/// el agente reconoce si la sesión es suya.
String etiquetaUltimoAcceso(DateTime? momento) {
  if (momento == null) return '';
  final local = momento.toLocal();
  final ahora = DateTime.now();
  final esHoy =
      local.year == ahora.year &&
      local.month == ahora.month &&
      local.day == ahora.day;
  final hora = _hora12(local);
  return esHoy ? 'Hoy $hora' : '${formatDateEsMX(local)} $hora';
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

  /// Estado del expediente para la insignia "Verificado" / "No verificado".
  /// En null no se pinta: solo el aliado externo tiene expediente que verificar.
  final bool? verificado;

  const SaludoAgente({
    super.key,
    required this.nombre,
    required this.rol,
    required this.propiedadesActivas,
    this.ultimoAcceso,
    this.verificado,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final acceso = etiquetaUltimoAcceso(ultimoAcceso);
    final estado = verificado;

    Widget separador() =>
        Text('·', style: t.text.caption.copyWith(color: tone.fgSubtle));

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
        // El interruptor de modo presentación NO va aquí: lo pinta la barra
        // superior en móvil y el shell en web, así que montarlo también en el
        // saludo lo duplicaba en pantalla angosta.
        if (estado != null) ...[
          SizedBox(width: t.space.sm),
          SBadge(
            label: estado ? 'Verificado' : 'No verificado',
            tone: estado ? SBadgeTone.positive : SBadgeTone.negative,
            icon: estado ? Icons.check_circle_outline : Icons.error_outline,
            size: SBadgeSize.sm,
          ),
        ],
      ],
    );
  }
}
