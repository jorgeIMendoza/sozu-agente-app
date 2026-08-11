import 'package:flutter/material.dart';

import 'package:sozu_agente_app/ui/ui.dart';

/// Avance de activación del perfil del agente, con lo que le falta desbloquear.
///
/// El porcentaje solo no mueve a nadie: lo que hace que el agente termine su
/// expediente es leer qué pierde mientras no lo termina (no puede generar
/// ofertas, no puede cobrar), así que el mensaje cambia según el paso pendiente.
class BannerActivacion extends StatelessWidget {
  final int porcentaje;
  final bool capacitacionCompleta;
  final bool identidadBasicaCompleta;

  /// El agente dependiente no captura datos bancarios: su inmobiliaria le paga,
  /// y prometerle lo contrario lo manda a buscar una sección que no tiene.
  final bool esDependiente;

  final VoidCallback onCompletar;

  const BannerActivacion({
    super.key,
    required this.porcentaje,
    required this.capacitacionCompleta,
    required this.identidadBasicaCompleta,
    required this.esDependiente,
    required this.onCompletar,
  });

  String get _mensaje {
    if (!capacitacionCompleta) {
      return 'Completa tu capacitación para generar ofertas.';
    }
    if (!identidadBasicaCompleta) {
      return esDependiente
          ? 'Completa tu identidad para generar ofertas.'
          : 'Completa tu identidad para incluir datos bancarios en tus ofertas.';
    }
    return 'Completa tu perfil para recibir comisiones.';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Activa tu perfil profesional',
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone.fg,
                  ),
                ),
              ),
              Text(
                '$porcentaje%',
                style: t.text.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tone.warningFg,
                  fontFeatures: SozuType.tabular,
                ),
              ),
            ],
          ),
          SizedBox(height: t.space.xxs),
          Text(
            _mensaje,
            style: t.text.caption.copyWith(color: tone.fgMuted),
          ),
          SizedBox(height: t.space.sm),
          SProgressBar(
            percent: porcentaje.toDouble(),
            semanticsLabel: 'Avance de activación del perfil',
          ),
          SizedBox(height: t.space.xxs),
          Align(
            alignment: Alignment.centerLeft,
            child: SButton.link(
              label: 'Completar ahora',
              trailingIcon: Icons.chevron_right,
              onPressed: onCompletar,
              isNavigation: true,
              size: SButtonSize.sm,
            ),
          ),
        ],
      ),
    );
  }
}
