import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/hoja_inventario.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Hoja de filtros de la búsqueda de unidades.
///
/// Devuelve los filtros elegidos al cerrar con "Aplicar", o null si se cerró sin
/// aplicar. Se resuelve sobre una copia local: mover un selector NO dispara una
/// consulta por cada toque, que con inventarios de miles de unidades era la
/// diferencia entre una petición y quince.
Future<FiltrosUnidades?> mostrarFiltrosUnidades(
  BuildContext context, {
  required FiltrosUnidades actuales,
  required OpcionesFiltro opciones,

  /// Unidades disponibles por desarrollo, para escribirlo junto a su nombre.
  Map<String, int> conteoPorDesarrollo = const {},

  /// Precios mínimo y máximo del inventario visible, para acotar el rango.
  required double precioMin,
  required double precioMax,
}) {
  return mostrarHojaInventario<FiltrosUnidades>(
    context,
    titulo: 'Filtros',
    subtitulo: 'Los cambios se aplican al confirmar',
    cuerpo: (ctx) => _FormularioFiltros(
      actuales: actuales,
      opciones: opciones,
      conteoPorDesarrollo: conteoPorDesarrollo,
      precioMin: precioMin,
      precioMax: precioMax,
    ),
  );
}

class _FormularioFiltros extends StatefulWidget {
  final FiltrosUnidades actuales;
  final OpcionesFiltro opciones;
  final Map<String, int> conteoPorDesarrollo;
  final double precioMin;
  final double precioMax;

  const _FormularioFiltros({
    required this.actuales,
    required this.opciones,
    required this.conteoPorDesarrollo,
    required this.precioMin,
    required this.precioMax,
  });

  @override
  State<_FormularioFiltros> createState() => _FormularioFiltrosState();
}

class _FormularioFiltrosState extends State<_FormularioFiltros> {
  late FiltrosUnidades _f = widget.actuales;
  RangeValues? _rango;

  /// Opciones de recámaras: 1, 2, 3 y "4+" (arriba de 3 se agrupa, igual que la
  /// web: pedir "7 recámaras" no es una búsqueda real).
  List<String> get _opcionesRecamaras {
    final delInventario = widget.opciones.recamaras;
    if (delInventario.isEmpty) return const ['1', '2', '3', '4+'];
    return {for (final n in delInventario) n <= 3 ? '$n' : '4+'}.toList()
      ..sort();
  }

  double get _min => widget.precioMin;

  /// El máximo nunca puede ser igual o menor al mínimo: un `RangeSlider` con
  /// extremos iguales revienta.
  double get _max =>
      widget.precioMax > widget.precioMin ? widget.precioMax : widget.precioMin + 1;

  RangeValues get _rangoVigente =>
      _rango ??
      RangeValues(
        // `.toDouble()` explícito: `clamp` sobre `num` devuelve `num` y
        // `RangeValues` pide `double`.
        (_f.precioMin ?? _min).clamp(_min, _max).toDouble(),
        (_f.precioMax ?? _max).clamp(_min, _max).toDouble(),
      );

  /// Selector de un solo valor con la opción "Todos" al frente.
  Widget _selector({
    required String etiqueta,
    required List<String> valores,
    required List<String> elegido,
    required String textoTodos,
    required ValueChanged<List<String>> onCambio,
    String Function(String)? rotular,
  }) {
    return SSelectField<String>(
      label: etiqueta,
      hint: textoTodos,
      value: elegido.isEmpty ? _todos : elegido.first,
      opciones: [
        (value: _todos, label: textoTodos),
        for (final v in valores) (value: v, label: rotular?.call(v) ?? v),
      ],
      onChanged: (v) =>
          onCambio(v == null || v == _todos ? const [] : [v]),
    );
  }

  /// Selector de sí / no / todos, para bodega y estacionamiento.
  Widget _triEstado({
    required String etiqueta,
    required bool? valor,
    required ValueChanged<bool?> onCambio,
  }) {
    return SSelectField<String>(
      label: etiqueta,
      value: valor == null
          ? _todos
          : valor
          ? 'si'
          : 'no',
      opciones: const [
        (value: _todos, label: 'Todos'),
        (value: 'si', label: 'Sí'),
        (value: 'no', label: 'No'),
      ],
      onChanged: (v) => onCambio(v == 'si' ? true : (v == 'no' ? false : null)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final o = widget.opciones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (o.desarrollos.isNotEmpty) ...[
          _selector(
            etiqueta: 'Desarrollo',
            valores: o.desarrollos,
            elegido: _f.desarrollos,
            textoTodos: 'Todos los desarrollos',
            rotular: (n) {
              final n2 = widget.conteoPorDesarrollo[n];
              return n2 == null ? n : '$n ($n2)';
            },
            // Cambiar de desarrollo tira el modelo: los nombres de modelo son de
            // ese desarrollo y dejarlo puesto devuelve cero resultados sin que se
            // vea por qué.
            onCambio: (v) =>
                setState(() => _f = _f.copyWith(desarrollos: v, modelos: const [])),
          ),
          SizedBox(height: t.space.sm),
        ],
        if (o.modelos.isNotEmpty) ...[
          _selector(
            etiqueta: 'Modelo',
            valores: o.modelos,
            elegido: _f.modelos,
            textoTodos: 'Todos los modelos',
            onCambio: (v) => setState(() => _f = _f.copyWith(modelos: v)),
          ),
          SizedBox(height: t.space.sm),
        ],
        if (o.niveles.isNotEmpty) ...[
          _selector(
            etiqueta: 'Nivel',
            valores: o.niveles,
            elegido: _f.niveles,
            textoTodos: 'Todos los niveles',
            rotular: (n) => 'Nivel $n',
            onCambio: (v) => setState(() => _f = _f.copyWith(niveles: v)),
          ),
          SizedBox(height: t.space.sm),
        ],
        _selector(
          etiqueta: 'Recámaras',
          valores: _opcionesRecamaras,
          elegido: _f.recamaras,
          textoTodos: 'Todas',
          rotular: (r) => r == '1' ? '1 recámara' : '$r recámaras',
          onCambio: (v) => setState(() => _f = _f.copyWith(recamaras: v)),
        ),
        SizedBox(height: t.space.sm),
        Row(
          children: [
            Expanded(
              child: _triEstado(
                etiqueta: 'Bodega',
                valor: _f.conBodega,
                onCambio: (v) => setState(
                  () => _f = v == null
                      ? _f.copyWith(limpiarBodega: true)
                      : _f.copyWith(conBodega: v),
                ),
              ),
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: _triEstado(
                etiqueta: 'Estacionamiento',
                valor: _f.conEstacionamiento,
                onCambio: (v) => setState(
                  () => _f = v == null
                      ? _f.copyWith(limpiarEstacionamiento: true)
                      : _f.copyWith(conEstacionamiento: v),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: t.space.md),
        Row(
          children: [
            Expanded(
              child: Text(
                'Rango de precio',
                style: t.text.label.copyWith(color: tone.fg),
              ),
            ),
            if (_f.precioMin != null || _f.precioMax != null)
              SButton.link(
                label: 'Restablecer',
                fullWidth: false,
                onPressed: () => setState(() {
                  _rango = null;
                  _f = _f.copyWith(limpiarPrecio: true);
                }),
              ),
          ],
        ),
        RangeSlider(
          min: _min,
          max: _max,
          divisions: _divisiones,
          values: _rangoVigente,
          labels: RangeLabels(
            formatMXNCompact(_rangoVigente.start),
            formatMXNCompact(_rangoVigente.end),
          ),
          onChanged: (v) => setState(() => _rango = v),
          onChangeEnd: (v) => setState(
            () => _f = _f.copyWith(precioMin: v.start, precioMax: v.end),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                formatMXN(_rangoVigente.start),
                style: t.text.caption.copyWith(color: tone.fgMuted),
              ),
            ),
            Text(
              formatMXN(_rangoVigente.end),
              style: t.text.caption.copyWith(color: tone.fgMuted),
            ),
          ],
        ),
        SizedBox(height: t.space.md),
        Row(
          children: [
            Expanded(
              child: SButton.secondary(
                label: 'Limpiar',
                onPressed: _f.hayFiltros
                    ? () => setState(() {
                        _rango = null;
                        _f = const FiltrosUnidades();
                      })
                    : null,
              ),
            ),
            SizedBox(width: t.space.xs),
            Expanded(
              child: SButton(
                label: 'Aplicar',
                onPressed: () => Navigator.of(context).pop(_f),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Valor centinela de "sin filtrar" en los selectores. No viaja al backend: se
/// traduce a lista vacía.
const String _todos = '__todos__';

/// Pasos del rango de precio. Con el slider continuo el gesto pide una consulta
/// por pixel; 40 pasos alcanzan para acotar sin ese ruido.
const int _divisiones = 40;
