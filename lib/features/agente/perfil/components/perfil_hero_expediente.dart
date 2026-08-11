import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Hero "Tu expediente · el motor de tu activación": explica de dónde sale la
/// información del agente y cuántas secciones le faltan.
///
/// El conteo lo calcula el backend (validadas / en proceso / pendientes) para que
/// el número del app coincida al dígito con el del portal web.
class PerfilHeroExpediente extends StatelessWidget {
  final ResumenSecciones resumen;
  final VoidCallback onGestionarDocumentos;

  const PerfilHeroExpediente({
    super.key,
    required this.resumen,
    required this.onGestionarDocumentos,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    final izquierda = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'TU EXPEDIENTE · EL MOTOR DE TU ACTIVACIÓN',
          style: t.text.overline.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: tone.primaryHover,
          ),
        ),
        SizedBox(height: t.space.xs),
        Text(
          'Tu información se construye desde tus documentos.',
          style: t.text.h3.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: -0.4,
            color: tone.fg,
          ),
        ),
        SizedBox(height: t.space.xs),
        Text(
          'Cada documento que subes alimenta tu información personal y fiscal. '
          'Solo validas lo que ya dijeron.',
          style: t.text.bodySmall.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.55,
            color: tone.fgMuted,
          ),
        ),
        SizedBox(height: t.space.md),
        Wrap(
          spacing: t.space.md,
          runSpacing: t.space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SButton(
              label: 'Gestionar documentos',
              icon: Icons.description_outlined,
              onPressed: onGestionarDocumentos,
              fullWidth: false,
            ),
            Text(
              '${resumen.validadas} de ${resumen.total} secciones completadas',
              style: t.text.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: tone.fgMuted,
              ),
            ),
          ],
        ),
      ],
    );

    final tally = _CajaEstadoSecciones(resumen: resumen);

    return Container(
      padding: EdgeInsets.all(t.space.lg),
      decoration: BoxDecoration(
        color: tone.primarySoft,
        border: Border.all(color: tone.primaryBorder),
        borderRadius: t.radius.lgBorder,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 560) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: izquierda),
                SizedBox(width: t.space.lg),
                SizedBox(width: 210, child: tally),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              izquierda,
              SizedBox(height: t.space.md),
              tally,
            ],
          );
        },
      ),
    );
  }
}

/// Caja "ESTADO DE SECCIONES" con los tres renglones de conteo.
class _CajaEstadoSecciones extends StatelessWidget {
  final ResumenSecciones resumen;

  const _CajaEstadoSecciones({required this.resumen});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    final renglones = <({int n, String etiqueta, Color fondo, Color texto})>[
      (
        n: resumen.validadas,
        etiqueta: 'validadas',
        fondo: tone.primarySoftStrong,
        texto: tone.primaryHover,
      ),
      (
        n: resumen.enProceso,
        etiqueta: 'en proceso',
        fondo: tone.warningSoft,
        texto: tone.warningFg,
      ),
      (
        n: resumen.pendientes,
        etiqueta: 'pendientes',
        fondo: tone.surfaceAlt,
        texto: tone.fgMuted,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(t.space.md),
      decoration: BoxDecoration(
        color: tone.surface,
        border: Border.all(color: tone.border),
        borderRadius: t.radius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ESTADO DE SECCIONES',
            style: t.text.overline.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: tone.fgSubtle,
            ),
          ),
          SizedBox(height: t.space.sm),
          for (var i = 0; i < renglones.length; i++) ...[
            if (i > 0) SizedBox(height: t.space.sm),
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: renglones[i].fondo,
                    borderRadius: t.radius.smBorder,
                  ),
                  child: Text(
                    '${renglones[i].n}',
                    style: t.text.overline.copyWith(
                      fontWeight: FontWeight.w700,
                      color: renglones[i].texto,
                    ),
                  ),
                ),
                SizedBox(width: t.space.xs),
                Text(
                  renglones[i].etiqueta,
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fgMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
