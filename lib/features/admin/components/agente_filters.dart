import 'package:flutter/material.dart';
import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Filtro por rol del selector "Ver como agente": Todos · Agente Inmobiliario ·
/// Agente Interno.
///
/// Componente **tonto**: recibe el rol activo y el conteo por rol, y avisa por
/// callback. No lee providers.
///
/// Es excluyente (un solo rol activo) y `null` significa "Todos": los dos roles
/// son los ÚNICOS que entran al portal, así que "Todos" no es un tercer rol,
/// es la ausencia de filtro. Ver `PortalAccess.allows`.
///
/// Reemplazó a los filtros Proyecto + Unidad que venían portados del selector
/// de clientes: un agente no cuelga de una unidad, así que ese par no acotaba
/// nada aquí.
class AgenteRoleFilter extends StatelessWidget {
  const AgenteRoleFilter({
    super.key,
    required this.rol,
    required this.onRolChanged,
    this.conteos = const {},
    this.total,
  });

  /// Rol activo; null = sin filtro.
  final RolAgente? rol;

  final ValueChanged<RolAgente?> onRolChanged;

  /// Cuántos agentes hay por rol, para anotar cada pastilla. Vacío mientras
  /// carga: la pastilla sale sin número en vez de con un cero que miente.
  final Map<RolAgente, int> conteos;

  /// Total de agentes, para la pastilla "Todos".
  final int? total;

  String _label(String base, int? n) => n == null ? base : '$base ($n)';

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SFieldLabel('Rol'),
        Wrap(
          spacing: t.space.xs,
          runSpacing: t.space.xs,
          children: [
            SChoiceChip(
              label: _label('Todos', total),
              selected: rol == null,
              size: SChoiceChipSize.sm,
              onSelected: (_) => onRolChanged(null),
            ),
            for (final r in RolAgente.values)
              SChoiceChip(
                label: _label(r.label, conteos[r]),
                selected: rol == r,
                size: SChoiceChipSize.sm,
                onSelected: (_) => onRolChanged(r),
              ),
          ],
        ),
      ],
    );
  }
}
