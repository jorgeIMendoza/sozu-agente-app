import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/inventario/components/rejilla_inventario.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/network_image.dart';

/// Amenidades del desarrollo, con tope de [tope] y un "Ver todas (N)" que
/// despliega el resto.
///
/// Un desarrollo con 30 amenidades pintadas de golpe empuja avance de obra y
/// ubicación fuera de la pantalla, y esas dos son las que el agente le enseña al
/// cliente. Mismo tope que el portal web.
class AmenidadesGrid extends StatefulWidget {
  final List<Amenidad> amenidades;

  /// Columnas de la rejilla; las decide la pantalla por breakpoint.
  final int columnas;

  /// Cuántas se ven antes de desplegar.
  final int tope;

  const AmenidadesGrid({
    super.key,
    required this.amenidades,
    required this.columnas,
    this.tope = 8,
  });

  @override
  State<AmenidadesGrid> createState() => _AmenidadesGridState();
}

class _AmenidadesGridState extends State<AmenidadesGrid> {
  bool _verTodas = false;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final total = widget.amenidades.length;
    final hayMas = total > widget.tope;
    final visibles = _verTodas || !hayMas
        ? widget.amenidades
        : widget.amenidades.take(widget.tope).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RejillaInventario(
          columnas: widget.columnas,
          children: [for (final a in visibles) _AmenidadTile(amenidad: a)],
        ),
        if (hayMas) ...[
          SizedBox(height: t.space.xs),
          SButton.ghost(
            label: _verTodas ? 'Ver menos' : 'Ver todas ($total)',
            trailingIcon: _verTodas
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            size: SButtonSize.sm,
            fullWidth: false,
            onPressed: () => setState(() => _verTodas = !_verTodas),
          ),
        ],
      ],
    );
  }
}

/// Amenidad: foto con su nombre encima, o solo el nombre si no tiene foto.
class _AmenidadTile extends StatelessWidget {
  final Amenidad amenidad;

  const _AmenidadTile({required this.amenidad});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    if (amenidad.foto == null) {
      return SCard.outlined(
        child: Center(
          child: Text(
            amenidad.nombre,
            textAlign: TextAlign.center,
            style: t.text.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: tone.fg,
            ),
          ),
        ),
      );
    }
    return SCard.outlined(
      padding: EdgeInsets.zero,
      clip: true,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: _aspectoFoto,
            child: SozuNetworkImage(url: amenidad.foto!),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: tone.overlay,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: t.space.xs,
                  vertical: t.space.xxs,
                ),
                child: Text(
                  amenidad.nombre,
                  maxLines: 2,
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    // Sobre el velo oscuro: blanco fijo, no un rol de tema.
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const double _aspectoFoto = 4 / 3;
