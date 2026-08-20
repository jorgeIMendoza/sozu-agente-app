import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Porcentaje con decimales SOLO si los tiene, como lo imprime la web.
/// Redondear a entero hacía que dos copropietarios al 33.33% se leyeran como
/// 33% + 33% = 66%, y pareciera que falta un tercio de la operación.
String _porcentaje(double valor) =>
    valor.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// Compradores de una operación en copropiedad.
///
/// Se abre desde la fila en vez de listarlos ahí: una operación a nombre de
/// cuatro personas convertiría la tarjeta de comisión en una lista de nombres y
/// escondería el monto, que es el dato que el agente busca.
Future<void> mostrarClientesComision(
  BuildContext context, {
  required String folio,
  required List<ClienteComision> clientes,

  /// Aplica el modo presentación a nombres y correos.
  required String Function(String) enmascarar,
}) {
  final t = context.s;
  final tone = t.color;

  final cuerpo = Padding(
    padding: EdgeInsets.all(t.space.lg),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Compradores de la operación',
          style: t.text.bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: tone.fg,
          ),
        ),
        SizedBox(height: t.space.xxs),
        Text(
          folio,
          style: t.text.caption.copyWith(
            color: tone.fgMuted,
            fontFeatures: SozuType.tabular,
          ),
        ),
        SizedBox(height: t.space.md),
        for (final cliente in clientes)
          Padding(
            padding: EdgeInsets.only(bottom: t.space.xs),
            child: Container(
              padding: EdgeInsets.all(t.space.sm),
              decoration: BoxDecoration(
                color: tone.surfaceAlt,
                borderRadius: t.radius.mdBorder,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.nombre.isEmpty
                              ? 'Sin nombre'
                              : enmascarar(cliente.nombre),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: tone.fg,
                          ),
                        ),
                        if (cliente.email.isNotEmpty)
                          Text(
                            enmascarar(cliente.email),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.text.caption.copyWith(color: tone.fgMuted),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: t.space.xs),
                  SBadge(
                    label: '${_porcentaje(cliente.porcentaje)}%',
                    size: SBadgeSize.sm,
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  if (context.bp.hasTwoColumns) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: tone.surface,
        shape: RoundedRectangleBorder(borderRadius: t.radius.sheetBorder),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(child: cuerpo),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: tone.surface,
    builder: (_) => SafeArea(child: SingleChildScrollView(child: cuerpo)),
  );
}
