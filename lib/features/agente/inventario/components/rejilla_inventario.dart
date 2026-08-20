import 'package:flutter/material.dart';

import 'package:sozu_agente_app/ui/ui.dart';

/// Rejilla de ancho fijo por columna con el aire de las secciones del
/// inventario. Con una sola columna se apila, para no dejar media pantalla en
/// blanco en teléfono.
class RejillaInventario extends StatelessWidget {
  final int columnas;
  final List<Widget> children;

  const RejillaInventario({
    super.key,
    required this.columnas,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final gap = context.s.space.xs;
    if (columnas <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = (c.maxWidth - gap * (columnas - 1)) / columnas;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final w in children) SizedBox(width: ancho, child: w),
          ],
        );
      },
    );
  }
}
