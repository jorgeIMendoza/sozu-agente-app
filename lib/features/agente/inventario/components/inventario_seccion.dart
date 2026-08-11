import 'package:flutter/material.dart';

import 'package:sozu_agente_app/ui/ui.dart';

/// Sección de la ficha de un desarrollo: encabezado con icono y su tarjeta.
///
/// Equivale al `SectionCard` del panel web y existe para que las ocho secciones
/// de la ficha (concepto, vistas, modelos, amenidades, avance, ubicación,
/// puntos de interés, material) no repitan el mismo par
/// `SSectionLabel.heading` + `SCard`.
class InventarioSeccion extends StatelessWidget {
  final IconData icon;
  final String titulo;

  /// Contenido a la derecha del encabezado (contador, acción).
  final Widget? trailing;

  /// `EdgeInsets.zero` cuando el contenido pinta hasta el filo (carruseles).
  final EdgeInsetsGeometry? padding;

  final Widget child;

  const InventarioSeccion({
    super.key,
    required this.icon,
    required this.titulo,
    required this.child,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SSectionLabel.heading(text: titulo, icon: icon, trailing: trailing),
        SizedBox(height: t.space.xs),
        SCard(padding: padding, child: child),
      ],
    );
  }
}

/// Fila de dato con etiqueta arriba y valor abajo, para los bloques de cifras
/// (disponibles / total, metraje / recámaras).
class InventarioDato extends StatelessWidget {
  final String etiqueta;
  final String valor;

  /// Tiñe el valor con el color de marca: se usa en la cifra protagonista.
  final bool destacado;

  const InventarioDato({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: t.text.overline.copyWith(color: tone.fgMuted),
        ),
        SizedBox(height: t.space.xxs),
        Text(
          valor,
          style: t.text.label.copyWith(
            fontWeight: FontWeight.w700,
            color: destacado ? tone.primaryHover : tone.fg,
          ),
        ),
      ],
    );
  }
}

/// Especificación de una unidad o modelo: icono de marca + texto.
class InventarioEspec extends StatelessWidget {
  final IconData icon;
  final String texto;

  const InventarioEspec({super.key, required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: _iconoEspec, color: t.color.primaryHover),
        SizedBox(width: t.space.xxs),
        Text(texto, style: t.text.bodySmall.copyWith(color: t.color.fgMuted)),
      ],
    );
  }
}

/// Tamaño del icono de una especificación: acompaña al texto, no lo domina.
const double _iconoEspec = 16;
