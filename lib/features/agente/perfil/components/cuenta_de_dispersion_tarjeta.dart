import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Tarjeta de una cuenta de dispersión: banco, estatus, últimos 4 y titular.
///
/// Tonta: recibe la cuenta y qué hacer con ella.
class CuentaDeDispersionTarjeta extends StatelessWidget {
  final CuentaDeDispersion cuenta;

  /// Abre la corrección; null la deja de solo consulta.
  final VoidCallback? onEditar;

  /// Da de baja la cuenta; null la oculta (una cuenta ya validada solo la baja
  /// SOZU, porque es la que recibe la dispersión).
  final VoidCallback? onBorrar;

  /// Abre la carátula del estado de cuenta; null si no hay.
  final VoidCallback? onVerEvidencia;

  const CuentaDeDispersionTarjeta({
    super.key,
    required this.cuenta,
    this.onEditar,
    this.onBorrar,
    this.onVerEvidencia,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    final contenido = SCard.outlined(
      padding: EdgeInsets.all(t.space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.surfaceAlt,
                  borderRadius: t.radius.mdBorder,
                ),
                child: Icon(
                  Icons.account_balance_outlined,
                  size: 17,
                  color: tone.fgMuted,
                ),
              ),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: t.space.xs,
                      runSpacing: t.space.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          cuenta.banco,
                          style: t.text.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tone.fg,
                          ),
                        ),
                        SBadge(
                          label: cuenta.estatusLegible,
                          tone: cuenta.validada
                              ? SBadgeTone.positive
                              : SBadgeTone.neutral,
                          size: SBadgeSize.sm,
                        ),
                      ],
                    ),
                    if (cuenta.numeroEnmascarado.isNotEmpty) ...[
                      SizedBox(height: t.space.xxs),
                      Text(
                        cuenta.numeroEnmascarado,
                        style: t.text.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tone.fgMuted,
                        ),
                      ),
                    ],
                    if ((cuenta.titular ?? '').isNotEmpty) ...[
                      SizedBox(height: t.space.xxs),
                      Text(
                        'Titular: ${cuenta.titular}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.text.overline.copyWith(color: tone.fgSubtle),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (onEditar != null || onBorrar != null || onVerEvidencia != null) ...[
            SizedBox(height: t.space.sm),
            Wrap(
              spacing: t.space.xs,
              runSpacing: t.space.xs,
              children: [
                if (onEditar != null)
                  SButton(
                    label: 'Editar',
                    icon: Icons.edit_outlined,
                    onPressed: onEditar,
                    variant: SButtonVariant.secondary,
                    size: SButtonSize.sm,
                    fullWidth: false,
                  ),
                if (onVerEvidencia != null)
                  SButton(
                    label: 'Ver carátula',
                    icon: Icons.visibility_outlined,
                    onPressed: onVerEvidencia,
                    variant: SButtonVariant.ghost,
                    size: SButtonSize.sm,
                    fullWidth: false,
                  ),
                if (onBorrar != null)
                  SButton(
                    label: 'Eliminar',
                    icon: Icons.delete_outline,
                    onPressed: onBorrar,
                    variant: SButtonVariant.danger,
                    size: SButtonSize.sm,
                    fullWidth: false,
                  ),
              ],
            ),
          ],
          // Cambiar banco, cuenta o CLABE obliga a revalidar: se dice ANTES de
          // que el agente edite, no después de que su cuenta validada se caiga.
          if (cuenta.validada && onEditar != null) ...[
            SizedBox(height: t.space.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: tone.fgMuted),
                SizedBox(width: t.space.xxs),
                Expanded(
                  child: Text(
                    'Si cambias el banco, el número de cuenta o la CLABE, la '
                    'volvemos a validar antes de dispersarte.',
                    style: t.text.overline.copyWith(
                      color: tone.fgMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return contenido;
  }
}
