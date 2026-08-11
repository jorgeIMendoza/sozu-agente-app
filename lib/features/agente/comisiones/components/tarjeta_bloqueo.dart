import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Comisiones bloqueadas por perfil incompleto, con la lista exacta de lo que
/// falta.
///
/// La lista importa más que el aviso: "completa tu perfil" manda al agente a
/// recorrer seis secciones para descubrir cuál era, y por eso el backend devuelve
/// los faltantes nombrados.
class TarjetaBloqueo extends StatelessWidget {
  final BloqueoComisiones bloqueo;
  final VoidCallback onCompletarPerfil;

  const TarjetaBloqueo({
    super.key,
    required this.bloqueo,
    required this.onCompletarPerfil,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final faltantes = bloqueo.faltantes;

    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.warningSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline, size: 20, color: tone.warningFg),
              ),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perfil incompleto',
                      style: t.text.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tone.fg,
                      ),
                    ),
                    Text(
                      'Termina tu perfil para ver y recibir tus comisiones.',
                      style: t.text.caption.copyWith(color: tone.fgMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: t.space.md),
          if (faltantes.isEmpty)
            const _Pendiente(texto: 'Perfil completo', listo: true)
          else
            for (final falta in faltantes) _Pendiente(texto: falta),
          SizedBox(height: t.space.md),
          SButton(
            label: 'Completar perfil',
            trailingIcon: Icons.chevron_right,
            onPressed: onCompletarPerfil,
            isNavigation: true,
          ),
        ],
      ),
    );
  }
}

/// Un renglón de la lista de faltantes.
class _Pendiente extends StatelessWidget {
  final String texto;
  final bool listo;

  const _Pendiente({required this.texto, this.listo = false});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.xs),
      child: Row(
        children: [
          Icon(
            listo ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: listo ? tone.positive : tone.warningFg,
          ),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(
              texto,
              style: t.text.bodySmall.copyWith(
                color: listo ? tone.fg : tone.fgMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
