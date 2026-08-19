import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/shared/providers/modo_presentacion_provider.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Interruptor del modo presentación: un ojo tachado cuando los montos están
/// ocultos, un ojo abierto cuando se ven.
///
/// Lo monta la barra superior (móvil) y el shell (web), no cada pantalla: el
/// agente que está enseñando la pantalla necesita el interruptor en todas las
/// secciones, incluidas las que no enmascaran nada.
class ModoPresentacionBoton extends ConsumerWidget {
  const ModoPresentacionBoton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(modoPresentacionProvider);
    final tone = context.s.color;
    final oculto = modo.activo;

    return IconButton(
      onPressed: modo.alternar,
      tooltip: oculto
          ? 'Mostrar mis montos (modo presentación activo)'
          : 'Ocultar mis montos (modo presentación)',
      icon: Icon(
        oculto ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        // Ámbar mientras oculta: el estado por defecto es "oculto", y en gris
        // nadie nota que los ceros de la pantalla no son sus números reales.
        color: oculto ? tone.warningFg : tone.fgMuted,
      ),
    );
  }
}

/// El mismo interruptor con la etiqueta a la vista, como la píldora del header
/// del portal web.
///
/// Es un ESTADO, no una acción puntual: en un tooltip el agente no puede saber
/// de un golpe si está activo. Para barras anchas; en móvil no cabe y va
/// [ModoPresentacionBoton].
class ModoPresentacionPildora extends ConsumerWidget {
  const ModoPresentacionPildora({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(modoPresentacionProvider);
    final t = context.s;
    final tone = t.color;
    final oculto = modo.activo;
    final fg = oculto ? tone.warningFg : tone.fgMuted;

    return SPressable(
      onTap: modo.alternar,
      borderRadius: t.radius.fullBorder,
      semanticLabel: oculto
          ? 'Modo presentación activo. Mostrar mis montos'
          : 'Ocultar mis montos (modo presentación)',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.sm,
          vertical: t.space.xxs,
        ),
        decoration: BoxDecoration(
          color: oculto ? tone.warningSoft : tone.surface,
          borderRadius: t.radius.fullBorder,
          border: Border.all(
            color: oculto ? tone.warningSoftStrong : tone.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              oculto
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: fg,
            ),
            SizedBox(width: t.space.xxs),
            Text(
              'Presentación',
              style: t.text.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso mínimo de que lo que se está viendo está enmascarado, para colgarlo del
/// encabezado de una sección donde no cabe el cintillo completo.
class ModoPresentacionInsignia extends ConsumerWidget {
  const ModoPresentacionInsignia({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(modoPresentacionProvider).activo) {
      return const SizedBox.shrink();
    }
    return const SBadge(
      // Mismo texto que la web: "Ocultos" solo dice que hay algo tapado, no
      // dónde se destapa.
      label: 'Ocultos · desactiva Modo presentación',
      tone: SBadgeTone.pending,
      icon: Icons.visibility_off_outlined,
      size: SBadgeSize.sm,
    );
  }
}

/// Cintillo que explica por qué los montos aparecen enmascarados, con el
/// interruptor a la mano.
///
/// Solo se pinta con el modo activo: es una explicación, y explicar algo que no
/// está pasando es ruido.
class ModoPresentacionCintillo extends ConsumerWidget {
  /// Qué es lo que está oculto en esta pantalla ("tus ingresos", "tus números").
  final String queSeOculta;

  const ModoPresentacionCintillo({super.key, required this.queSeOculta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(modoPresentacionProvider);
    if (!modo.activo) return const SizedBox.shrink();

    final t = context.s;
    final tone = t.color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm,
        vertical: t.space.xxs,
      ),
      decoration: BoxDecoration(
        color: tone.warningSoft,
        borderRadius: t.radius.mdBorder,
        border: Border.all(color: tone.warningSoftStrong),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_off_outlined, size: 16, color: tone.warningFg),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(
              'Modo presentación activo · $queSeOculta está oculto.',
              style: t.text.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: tone.warningFg,
              ),
            ),
          ),
          SButton.link(
            label: 'Mostrar',
            onPressed: modo.alternar,
            color: tone.warningFg,
            size: SButtonSize.sm,
          ),
        ],
      ),
    );
  }
}
