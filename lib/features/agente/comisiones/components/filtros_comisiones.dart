import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/features/agente/comisiones/providers/comisiones_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Rótulo del orden que llega del backend (comisión más reciente primero).
const String _sinOrden = 'Más recientes';

/// Ancho del bloque de orden en pantalla ancha: al 100% del contenido (1040 px)
/// un desplegable de seis opciones se lee como si fuera un campo del formulario.
const double _anchoOrden = 300;

/// Filtros de Comisiones: Proyecto · Cliente · Estatus, y el orden del listado.
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

    // Se escribe en vez de desplegarse, como el `SearchableSelect` de la web: un
    // agente con veinte proyectos no encuentra el suyo en una lista larga.
    final elegido = ref.watch(filtroProyectoProvider);
    final proyecto = SAutocompleteField<String>(
      labelText: 'Proyecto',
      hintText: 'Buscar proyecto…',
      prefixIcon: Icons.apartment_outlined,
      options: widget.proyectos,
      labelOf: (p) => p,
      value: elegido == kFiltroTodos ? null : elegido,
      // Limpiar el campo equivale a la opción "Todos" de la web.
      onSelected: (p) =>
          ref.read(filtroProyectoProvider.notifier).state = p ?? kFiltroTodos,
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
          SizedBox(height: t.space.sm),
          const _Orden(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: proyecto),
            SizedBox(width: t.space.sm),
            Expanded(child: cliente),
            SizedBox(width: t.space.sm),
            Expanded(child: etapa),
          ],
        ),
        SizedBox(height: t.space.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: const SizedBox(width: _anchoOrden, child: _Orden()),
        ),
      ],
    );
  }
}

/// Llave de orden y dirección.
///
/// No es el encabezado de tabla de la web: seis columnas que se tocan para
/// ordenar necesitan la tabla, y en un teléfono la tabla no cabe. La llave y el
/// sentido son los mismos.
class _Orden extends ConsumerWidget {
  const _Orden();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final orden = ref.watch(ordenComisionesProvider);
    final ascendente = ref.watch(ordenAscendenteProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: SSelectField<OrdenComisiones?>(
            label: 'Ordenar por',
            hint: _sinOrden,
            value: orden,
            opciones: <SSelectOption<OrdenComisiones?>>[
              (value: null, label: _sinOrden),
              for (final o in OrdenComisiones.values)
                (value: o, label: o.etiqueta),
            ],
            onChanged: (v) =>
                ref.read(ordenComisionesProvider.notifier).state = v,
          ),
        ),
        SizedBox(width: t.space.xs),
        SButton.secondary(
          label: ascendente ? 'Asc' : 'Desc',
          icon: ascendente ? Icons.arrow_upward : Icons.arrow_downward,
          fullWidth: false,
          tooltip: 'Invertir el orden',
          // Sin llave elegida manda el orden del backend y la dirección no
          // aplica: un botón que no cambia nada se toca tres veces.
          onPressed: orden == null
              ? null
              : () => ref.read(ordenAscendenteProvider.notifier).state =
                    !ascendente,
        ),
      ],
    );
  }
}
