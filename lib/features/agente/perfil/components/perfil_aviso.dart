import 'package:flutter/material.dart';

import 'package:sozu_agente_app/ui/ui.dart';

/// Aviso de que una sección la administra la inmobiliaria del agente.
///
/// Va SIEMPRE junto a los campos grises, nunca en un toast: un campo
/// deshabilitado sin explicación al lado se reporta como bug, y el agente no
/// tiene forma de adivinar a quién pedirle el cambio.
class PerfilAvisoSoloLectura extends StatelessWidget {
  /// Por qué no se puede editar ("La administra Grupo X").
  final String nota;

  /// Nombre de la inmobiliaria, para decirle a quién acudir.
  final String? inmobiliaria;

  const PerfilAvisoSoloLectura({
    super.key,
    required this.nota,
    this.inmobiliaria,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final aQuien = inmobiliaria == null
        ? 'Contacta a tu inmobiliaria para corregir esta información.'
        : 'Contacta a $inmobiliaria para corregir esta información.';

    return Container(
      padding: EdgeInsets.all(t.space.sm),
      decoration: BoxDecoration(
        color: tone.surfaceAlt,
        border: Border.all(color: tone.border),
        borderRadius: t.radius.mdBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 16, color: tone.fgMuted),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esta información la administra tu inmobiliaria, por eso no '
                  'se puede editar aquí.',
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fg,
                  ),
                ),
                SizedBox(height: t.space.xxs),
                Text(
                  '$nota. $aQuien',
                  style: t.text.overline.copyWith(
                    color: tone.fgMuted,
                    height: 1.5,
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

/// Aviso ámbar de que al agente le falta algo para poder cobrar.
///
/// Solo aparece cuando el agente SÍ administra sus datos de cobro y alguno está
/// incompleto: al dependiente nunca, porque su inmobiliaria recibe las comisiones
/// y no hay nada que él pueda hacer.
class PerfilAvisoCobros extends StatelessWidget {
  final VoidCallback? onCompletar;

  const PerfilAvisoCobros({super.key, this.onCompletar});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return Container(
      padding: EdgeInsets.all(t.space.sm),
      decoration: BoxDecoration(
        color: tone.warningSoft,
        border: Border.all(color: tone.warning),
        borderRadius: t.radius.mdBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: tone.warningFg),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(
              'Completa tu información fiscal y cuenta bancaria para poder '
              'recibir comisiones.',
              style: t.text.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: tone.warningFg,
                height: 1.45,
              ),
            ),
          ),
          if (onCompletar != null) ...[
            SizedBox(width: t.space.xs),
            SButton(
              label: 'Actualizar',
              onPressed: onCompletar,
              variant: SButtonVariant.ghost,
              size: SButtonSize.sm,
              fullWidth: false,
            ),
          ],
        ],
      ),
    );
  }
}
