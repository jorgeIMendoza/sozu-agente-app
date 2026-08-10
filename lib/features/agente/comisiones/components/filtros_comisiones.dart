import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/features/agente/comisiones/providers/comisiones_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Filtros de Comisiones: Proyecto · Cliente · Estatus.
///
/// Las opciones salen de las comisiones que el agente REALMENTE tiene: ofrecer un
/// catálogo completo llevaría a filtrar por un proyecto que él no vende y leer un
/// listado vacío como si fuera una falla.
class FiltrosComisiones extends ConsumerStatefulWidget {
  final List<String> proyectos;
  final List<OpcionFiltro> etapas;

  const FiltrosComisiones({
    super.key,
    required this.proyectos,
    required this.etapas,
  });

  @override
  ConsumerState<FiltrosComisiones> createState() => _FiltrosComisionesState();
}

class _FiltrosComisionesState extends ConsumerState<FiltrosComisiones> {
  final _cliente = TextEditingController();

  @override
  void initState() {
    super.initState();
    // El texto vive en el provider (sobrevive a que la fila se reconstruya); el
    // controller solo lo refleja al montarse.
    _cliente.text = ref.read(filtroClienteProvider);
  }

  @override
  void dispose() {
    _cliente.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;

    final proyecto = SSelectField<String>(
      label: 'Proyecto',
      hint: 'Todos',
      value: ref.watch(filtroProyectoProvider),
      opciones: [
        (value: kFiltroTodos, label: 'Todos'),
        for (final p in widget.proyectos) (value: p, label: p),
      ],
      onChanged: (v) =>
          ref.read(filtroProyectoProvider.notifier).state = v ?? kFiltroTodos,
    );

    final cliente = SSearchField(
      controller: _cliente,
      label: 'Cliente',
      hintText: 'Nombre o correo',
      onChanged: (v) => ref.read(filtroClienteProvider.notifier).state = v,
    );

    final etapa = SSelectField<String>(
      label: 'Estatus',
      hint: 'Todos',
      value: ref.watch(filtroEtapaProvider),
      opciones: [
        (value: kFiltroTodos, label: 'Todos los estatus'),
        for (final e in widget.etapas) (value: e.valor, label: e.etiqueta),
      ],
      onChanged: (v) =>
          ref.read(filtroEtapaProvider.notifier).state = v ?? kFiltroTodos,
    );

    // En teléfono los tres van apilados: un desplegable de proyectos a un tercio
    // del ancho corta los nombres largos, que es justo lo que hay que leer.
    if (!context.bp.hasTwoColumns) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          proyecto,
          SizedBox(height: t.space.sm),
          cliente,
          SizedBox(height: t.space.sm),
          etapa,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: proyecto),
        SizedBox(width: t.space.sm),
        Expanded(child: cliente),
        SizedBox(width: t.space.sm),
        Expanded(child: etapa),
      ],
    );
  }
}
