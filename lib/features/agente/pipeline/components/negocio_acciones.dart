import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Lo que se puede hacer con un negocio desde la tabla o la tarjeta.
///
/// Se pasa como un solo objeto para que agregar una acción no cambie la firma de
/// los tres componentes que las pintan.
class AccionesNegocio {
  final void Function(Negocio) verDetalle;
  final void Function(Negocio) compartir;
  final void Function(Negocio) abrirLink;

  /// `null` = no se ofrece registrar la razón (sin permiso de actualizar o con
  /// el catálogo de razones deshabilitado en el ambiente).
  final void Function(Negocio)? registrarRazon;

  const AccionesNegocio({
    required this.verDetalle,
    required this.compartir,
    required this.abrirLink,
    this.registrarRazon,
  });
}

/// Fila de acciones de un negocio. La razón de no avance solo aparece en los
/// cerrados perdidos, y resaltada mientras nadie la haya capturado.
class BarraAccionesNegocio extends StatelessWidget {
  final Negocio negocio;
  final AccionesNegocio acciones;

  /// El negocio está en cierre perdido: es el único caso que pide razón.
  final bool esPerdido;

  const BarraAccionesNegocio({
    super.key,
    required this.negocio,
    required this.acciones,
    required this.esPerdido,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final registrar = acciones.registrarRazon;
    final faltaRazon = negocio.razonNoAvance == null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconoAccion(
          icono: Icons.visibility_outlined,
          tooltip: 'Detalle del negocio',
          onTap: () => acciones.verDetalle(negocio),
        ),
        IconoAccion(
          icono: Icons.ios_share_outlined,
          tooltip: 'Compartir el link del cliente',
          onTap: () => acciones.compartir(negocio),
        ),
        IconoAccion(
          icono: Icons.open_in_new,
          tooltip: negocio.tieneLinkCliente
              ? 'Abrir el link del cliente'
              : 'Vista previa: esta oferta no tiene link de cliente',
          onTap: () => acciones.abrirLink(negocio),
        ),
        if (esPerdido && registrar != null)
          IconoAccion(
            icono: faltaRazon
                ? Icons.help_outline
                : Icons.chat_bubble_outline,
            tooltip: faltaRazon
                ? '¿Por qué no avanzó?'
                : 'Editar la razón por la que no avanzó',
            color: faltaRazon ? tone.warningFg : null,
            onTap: () => registrar(negocio),
          ),
      ],
    );
  }
}

/// Botón de icono de la pantalla: mismo tamaño y densidad en tabla, tarjeta y
/// tablero. `onTap` en null lo deja visible pero deshabilitado, para que el
/// tooltip pueda explicar por qué no se puede.
class IconoAccion extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const IconoAccion({
    super.key,
    required this.icono,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(
          width: _lado,
          height: _lado,
        ),
        padding: EdgeInsets.zero,
        iconSize: _icono,
        icon: Icon(
          icono,
          color: onTap == null ? tone.fgSubtle : (color ?? tone.fgMuted),
        ),
      ),
    );
  }
}

/// Caja del botón de icono. Por debajo del mínimo táctil a propósito: son
/// acciones secundarias de una fila densa y el destino principal (abrir el
/// detalle) es toda la fila.
const double _lado = 34;
const double _icono = 18;
