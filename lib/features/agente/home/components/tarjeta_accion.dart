import 'package:flutter/material.dart';

import 'package:sozu_agente_app/ui/ui.dart';

/// Atajo a una acción de captura ("Nuevo prospecto", "Agendar cita"): icono en
/// caja teñida, título y una línea que dice para qué sirve.
///
/// Es una tarjeta y no un botón porque el subtítulo es parte del mensaje: un
/// agente nuevo no sabe qué es un "prospecto" en SOZU hasta que lee "captura un
/// comprador potencial".
class TarjetaAccion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const TarjetaAccion({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return SPressable(
      onTap: onTap,
      borderRadius: t.radius.lgBorder,
      hoverLift: true,
      semanticLabel: '$titulo. $subtitulo',
      child: SCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.primarySoftStrong,
                borderRadius: t.radius.mdBorder,
              ),
              child: Icon(icono, size: 20, color: tone.primaryHover),
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                  Text(
                    subtitulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.caption.copyWith(color: tone.fgMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: tone.fgSubtle),
          ],
        ),
      ),
    );
  }
}
