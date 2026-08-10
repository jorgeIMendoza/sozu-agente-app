import 'package:flutter/material.dart';

import 'package:sozu_agente_app/ui/ui.dart';

/// Lo que se muestra cuando un dato del perfil todavía no existe. Igual que el
/// portal web: nunca se deja el renglón en blanco, porque un hueco parece un
/// error de carga y no un dato pendiente.
const String kSinRegistro = 'Sin registro';

/// Fila etiqueta → valor de una tarjeta del perfil.
///
/// El valor se alinea a la derecha y se apoya sobre el separador inferior, que es
/// como se leen los datos del portal web.
class PerfilDato extends StatelessWidget {
  final String etiqueta;

  /// Valor ya formateado; vacío o null pinta [kSinRegistro] en cursiva.
  final String? valor;

  /// Widget libre a la derecha, para valores que no son texto (un punto de
  /// estatus, una insignia). Gana sobre [valor].
  final Widget? trailing;

  /// Detalle bajo el valor (una nota, una unidad).
  final String? nota;

  /// Última fila de la tarjeta: sin separador.
  final bool ultima;

  const PerfilDato({
    super.key,
    required this.etiqueta,
    this.valor,
    this.trailing,
    this.nota,
    this.ultima = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final hayValor = (valor ?? '').trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.symmetric(vertical: t.space.sm),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : Border(bottom: BorderSide(color: tone.borderSoft)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: t.text.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: tone.fgMuted,
              ),
            ),
          ),
          SizedBox(width: t.space.sm),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (trailing != null)
                  trailing!
                else
                  Text(
                    hayValor ? valor!.trim() : kSinRegistro,
                    textAlign: TextAlign.right,
                    style: t.text.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      fontStyle: hayValor ? FontStyle.normal : FontStyle.italic,
                      color: hayValor ? tone.fg : tone.fgSubtle,
                    ),
                  ),
                if (nota != null) ...[
                  SizedBox(height: t.space.xxs),
                  Text(
                    nota!,
                    textAlign: TextAlign.right,
                    style: t.text.overline.copyWith(color: tone.fgSubtle),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de un bloque de datos del perfil: encabezado, acción opcional y las
/// filas de [PerfilDato].
class PerfilBloqueDatos extends StatelessWidget {
  final String titulo;

  /// Acción del encabezado (normalmente "Editar"); null la omite.
  final Widget? accion;

  /// Contenido antes de las filas (un aviso de solo lectura, un campo editable).
  final Widget? encabezado;
  final List<Widget> filas;

  /// Nota al pie de la tarjeta.
  final String? pie;

  const PerfilBloqueDatos({
    super.key,
    required this.titulo,
    required this.filas,
    this.accion,
    this.encabezado,
    this.pie,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return SCard(
      padding: EdgeInsets.all(t.space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  style: t.text.overline.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: t.color.fgSubtle,
                  ),
                ),
              ),
              if (accion != null) accion!,
            ],
          ),
          if (encabezado != null) ...[
            SizedBox(height: t.space.sm),
            encabezado!,
          ],
          SizedBox(height: t.space.xs),
          for (var i = 0; i < filas.length; i++) filas[i],
          if (pie != null) ...[
            SizedBox(height: t.space.sm),
            Text(
              pie!,
              style: t.text.overline.copyWith(
                color: t.color.fgSubtle,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
