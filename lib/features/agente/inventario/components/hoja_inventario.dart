import 'package:flutter/material.dart';

import 'package:sozu_agente_app/ui/ui.dart';

/// Hoja modal de las cuatro vistas del inventario: compartir, filtros, detalle
/// de unidad y planos.
///
/// Una sola hoja para todas y en todos los anchos: en teléfono sube desde
/// abajo, y en el portal ancho el `constraints` la deja centrada con ancho de
/// lectura en vez de estirada de lado a lado. Antes de esto cada modal del
/// portal traía su propio diálogo y no coincidían ni el radio ni el borde.
Future<T?> mostrarHojaInventario<T>(
  BuildContext context, {
  required String titulo,
  String? subtitulo,
  required WidgetBuilder cuerpo,

  /// Botones del pie. Vacío = sin pie.
  List<Widget> acciones = const [],

  double anchoMax = _anchoMaxHoja,
}) {
  final t = context.s;
  final tone = t.color;
  return showModalBottomSheet<T>(
    context: context,
    // Raíz: la hoja debe sobrevivir a que la pantalla de abajo se reconstruya.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: tone.surface,
    constraints: BoxConstraints(maxWidth: anchoMax),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radius.sheet)),
    ),
    builder: (ctx) {
      final tc = ctx.s;
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * _altoMaxFactor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tc.space.md,
                  tc.space.sm,
                  tc.space.xs,
                  tc.space.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tc.text.h3.copyWith(color: tc.color.fg),
                          ),
                          if (subtitulo != null)
                            Text(
                              subtitulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tc.text.bodySmall.copyWith(
                                color: tc.color.fgMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close),
                      color: tc.color.fgMuted,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: tc.color.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(tc.space.md),
                  child: cuerpo(ctx),
                ),
              ),
              if (acciones.isNotEmpty) ...[
                Divider(height: 1, color: tc.color.border),
                Padding(
                  padding: EdgeInsets.all(tc.space.md),
                  child: Row(
                    children: [
                      for (var i = 0; i < acciones.length; i++) ...[
                        if (i > 0) SizedBox(width: tc.space.xs),
                        Expanded(child: acciones[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Ancho de lectura de la hoja en pantallas anchas.
const double _anchoMaxHoja = 560;

/// Alto máximo relativo a la pantalla: deja ver que hay algo detrás.
const double _altoMaxFactor = 0.9;
