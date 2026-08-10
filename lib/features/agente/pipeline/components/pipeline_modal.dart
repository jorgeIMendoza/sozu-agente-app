import 'package:flutter/material.dart';

import 'package:sozu_agente_app/ui/ui.dart';

/// Ancho máximo del diálogo en pantallas anchas: la misma medida del modal de
/// la web (480 de contenido más el aire de la caja).
const double _anchoMaximo = 520;

/// Fracción del alto de pantalla que puede ocupar el modal.
const double _altoMaximoFactor = 0.85;

/// Abre el contenido como hoja inferior en teléfono y como diálogo centrado en
/// tablet o escritorio. Decide por el ANCHO disponible, no por la plataforma:
/// web en un celular es un teléfono.
Future<T?> mostrarHojaPipeline<T>(BuildContext context, Widget contenido) {
  final tone = context.s.color;
  final radius = context.s.radius;

  if (context.bp.isMobile) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: tone.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.sheet)),
      ),
      builder: (_) => contenido,
    );
  }

  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: tone.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius.sheetBorder,
        side: BorderSide(color: tone.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _anchoMaximo,
          maxHeight: MediaQuery.sizeOf(ctx).height * _altoMaximoFactor,
        ),
        child: contenido,
      ),
    ),
  );
}

/// Estructura de los modales del pipeline: encabezado con icono, cuerpo con
/// scroll propio y pie con la nota de bloqueo a la izquierda y las acciones a
/// la derecha.
class HojaPipeline extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final List<Widget> cuerpo;

  /// Botones del pie, en orden de lectura (el principal al final).
  final List<Widget> acciones;

  /// Por qué la acción principal está deshabilitada. Sin esto un botón apagado
  /// no dice si falta elegir algo, escribir el detalle o el permiso.
  final String? nota;

  const HojaPipeline({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.cuerpo,
    this.acciones = const [],
    this.nota,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(t.space.md, t.space.md, t.space.sm, 0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(t.space.xs),
                  decoration: BoxDecoration(
                    color: tone.surfaceAlt,
                    borderRadius: t.radius.mdBorder,
                  ),
                  child: Icon(icono, size: _iconoTitulo, color: tone.fgMuted),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.text.caption.copyWith(color: tone.fgSubtle),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: Icon(Icons.close, size: _iconoTitulo, color: tone.fgMuted),
                  onPressed: () => Navigator.of(context).maybePop(),
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
                children: cuerpo,
              ),
            ),
          ),
          if (acciones.isNotEmpty || nota != null)
            Container(
              padding: t.space.allMd,
              decoration: BoxDecoration(
                color: tone.surfaceAlt,
                border: Border(top: BorderSide(color: tone.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (nota != null) ...[
                    Text(
                      nota!,
                      style: t.text.caption.copyWith(color: tone.fgMuted),
                    ),
                    SizedBox(height: t.space.xs),
                  ],
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: t.space.xs,
                    runSpacing: t.space.xs,
                    children: acciones,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Icono del encabezado y de la X de cierre.
const double _iconoTitulo = 18;
