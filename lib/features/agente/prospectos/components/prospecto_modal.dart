import 'package:flutter/material.dart';

import 'package:sozu_agente_app/ui/ui.dart';

/// Abre una hoja de prospectos: bottom sheet en teléfono y diálogo centrado en
/// pantallas anchas. El criterio es el ANCHO disponible, no la plataforma.
Future<T?> mostrarHojaProspecto<T>(BuildContext context, Widget hoja) {
  if (context.bp.isMobile) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.s.color.surface,
      builder: (_) => hoja,
    );
  }
  final t = context.s;
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: t.color.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: t.radius.lgBorder,
        side: BorderSide(color: t.color.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: hoja,
      ),
    ),
  );
}

/// Envoltorio de las hojas de prospectos: encabezado con icono, título y
/// subtítulo, cuerpo con scroll y una fila de acciones al pie.
///
/// Existe para que el alta, la transferencia y la nota compartan encabezado y
/// pie: tres modales con márgenes distintos se leen como tres formularios de
/// productos distintos.
class HojaProspecto extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;

  /// Contenido del cuerpo, ya separado por el llamador.
  final List<Widget> children;

  /// Botones del pie, alineados a la derecha.
  final List<Widget> acciones;

  const HojaProspecto({
    super.key,
    required this.icono,
    required this.titulo,
    required this.children,
    this.subtitulo,
    this.acciones = const [],
  });

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
          Padding(
            padding: EdgeInsets.fromLTRB(t.space.md, t.space.md, t.space.xs, 0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(t.space.xs),
                  decoration: BoxDecoration(
                    color: tone.surfaceAlt,
                    borderRadius: t.radius.smBorder,
                  ),
                  child: Icon(icono, size: 18, color: tone.fgMuted),
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
                      if (subtitulo != null)
                        Text(
                          subtitulo!,
                          style: t.text.caption.copyWith(color: tone.fgSubtle),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, size: 20),
                  color: tone.fgMuted,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(color: tone.border, height: t.space.lg),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                t.space.md,
                0,
                t.space.md,
                t.space.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          if (acciones.isNotEmpty)
            Container(
              padding: t.space.allMd,
              decoration: BoxDecoration(
                color: tone.surfaceAlt,
                border: Border(top: BorderSide(color: tone.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final a in acciones) ...[
                    a,
                    if (a != acciones.last) SizedBox(width: t.space.sm),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
