import 'package:flutter/material.dart';

import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Diámetro del avatar de la fila. Público porque el skeleton de la lista lo
/// replica: si divergen, la lista brinca al terminar de cargar.
const double kAgenteRowAvatarSize = 36;

/// Fila de agente del selector "Ver como agente": nombre, correo, rol y estado.
///
/// Componente **tonto**: recibe el dato, si está isSelected y qué hacer al
/// tocar. No lee providers ni navega - eso lo decide la pantalla. Así se puede
/// montar en un test o en otra vista sin arrastrar Riverpod.
class AgenteRow extends StatelessWidget {
  final AdminAgente agente;

  /// El agente que el admin está viendo ahora mismo (impersonado).
  final bool isSelected;

  final VoidCallback onTap;

  const AgenteRow({
    super.key,
    required this.agente,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;

    return Material(
      color: isSelected ? c.primarySoft : c.surface,
      borderRadius: t.radius.mdBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: t.radius.mdBorder,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: t.radius.mdBorder,
            border: Border.all(color: isSelected ? c.primaryBorder : c.border),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: t.space.sm,
            vertical: t.space.sm,
          ),
          child: Row(
            children: [
              _Avatar(name: agente.nombre),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      agente.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.text.label.copyWith(color: c.fg),
                    ),
                    if (agente.email != null) ...[
                      SizedBox(height: t.space.xxs),
                      Text(
                        agente.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.text.caption.copyWith(color: c.fgMuted),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: t.space.xs),
              // El rol va en la fila y no solo en el filtro: con "Todos" activo
              // dos agentes con el mismo nombre de pila solo se distinguen por
              // aquí, y es lo que decide qué portal va a ver el admin.
              if (agente.rolEtiqueta != null) ...[
                _RolBadge(agente: agente),
                SizedBox(width: t.space.xs),
              ],
              if (isSelected)
                _ViewingBadge(label: 'Viendo')
              else
                Icon(Icons.chevron_right, size: 20, color: c.fgSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Iniciales sobre círculo teñido. Da anclaje visual a la lista sin pedir una
/// foto que el backend no manda en este endpoint.
class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      width: kAgenteRowAvatarSize,
      height: kAgenteRowAvatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.color.primarySoftStrong,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: t.text.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: t.color.primaryHover,
        ),
      ),
    );
  }
}

/// Insignia del rol. En pantalla angosta se abrevia: "Agente Inmobiliario"
/// completo empuja el correo a puntos suspensivos en un teléfono.
class _RolBadge extends StatelessWidget {
  final AdminAgente agente;

  const _RolBadge({required this.agente});

  @override
  Widget build(BuildContext context) {
    final corto = context.bp.isMobile;
    final label = switch (agente.rol) {
      RolAgente.inmobiliario => corto ? 'Inmobiliario' : 'Agente Inmobiliario',
      RolAgente.interno => corto ? 'Interno' : 'Agente Interno',
      null => agente.rolNombre!,
    };
    return SBadge(label: label, tone: SBadgeTone.neutral, size: SBadgeSize.sm);
  }
}

class _ViewingBadge extends StatelessWidget {
  final String label;

  const _ViewingBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.xs,
        vertical: t.space.xxs,
      ),
      decoration: BoxDecoration(
        color: t.color.primarySoftStrong,
        borderRadius: t.radius.fullBorder,
      ),
      child: Text(
        label,
        style: t.text.overline.copyWith(color: t.color.primaryHover),
      ),
    );
  }
}
