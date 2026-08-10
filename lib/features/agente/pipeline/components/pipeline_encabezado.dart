import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/features/agente/pipeline/providers/pipeline_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Barra de la pantalla: cifras del periodo, cambio de vista, modo presentación,
/// buscador de prospecto y filtro de etapa.
class PipelineEncabezado extends StatelessWidget {
  final ResumenPipeline resumen;
  final bool cargando;

  final VistaPipeline vista;
  final ValueChanged<VistaPipeline> onVista;

  final bool modoPresentacion;
  final VoidCallback onAlternarPresentacion;

  final TextEditingController buscador;
  final ValueChanged<String> onBuscar;

  final String etapaFiltro;
  final List<SSelectOption<String>> opcionesEtapa;
  final ValueChanged<String> onEtapa;

  /// Permiso de generar oferta en el pipeline.
  final bool puedeCrear;

  /// Sin capacitación terminada no se puede generar oferta, aunque haya permiso.
  final bool capacitacionCompleta;

  final VoidCallback onNuevaOferta;

  /// El tablero no tiene arrastre vertical libre para el pull-to-refresh, así
  /// que ahí la recarga es un botón.
  final VoidCallback? onRefrescar;

  const PipelineEncabezado({
    super.key,
    required this.resumen,
    required this.cargando,
    required this.vista,
    required this.onVista,
    required this.modoPresentacion,
    required this.onAlternarPresentacion,
    required this.buscador,
    required this.onBuscar,
    required this.etapaFiltro,
    required this.opcionesEtapa,
    required this.onEtapa,
    required this.puedeCrear,
    required this.capacitacionCompleta,
    required this.onNuevaOferta,
    this.onRefrescar,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: t.space.xs,
          runSpacing: t.space.xs,
          children: [
            if (cargando)
              const SSkeleton(width: 280, height: 12)
            else
              Text(
                [
                  '${resumen.negocios} '
                      '${resumen.negocios == 1 ? 'negocio' : 'negocios'}',
                  '${resumen.ofertas} ofertas',
                  '${mascara(formatMXN(resumen.montoAbierto), activo: modoPresentacion)} abiertos',
                  'últimos 30 días',
                ].join(' · '),
                style: t.text.overline.copyWith(color: tone.fgMuted),
              ),
            // Wrap y no Row: en teléfono el selector, los iconos y el botón no
            // caben en una línea y un Row los desbordaría.
            Wrap(
              spacing: t.space.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SelectorVista(vista: vista, onVista: onVista),
                IconButton(
                  tooltip: modoPresentacion
                      ? 'Desactivar modo presentación'
                      : 'Activar modo presentación',
                  onPressed: onAlternarPresentacion,
                  icon: Icon(
                    modoPresentacion
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: modoPresentacion ? tone.warningFg : tone.fgMuted,
                  ),
                ),
                if (onRefrescar != null)
                  IconButton(
                    tooltip: 'Recargar',
                    onPressed: onRefrescar,
                    icon: Icon(Icons.refresh, color: tone.fgMuted),
                  ),
                if (puedeCrear) ...[
                  if (!capacitacionCompleta)
                    Tooltip(
                      message:
                          'Termina tu capacitación para poder generar ofertas.',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: _icono,
                            color: tone.fgSubtle,
                          ),
                          SizedBox(width: t.space.xxs),
                          Text(
                            'Completa tu capacitación',
                            style: t.text.caption.copyWith(color: tone.fgMuted),
                          ),
                        ],
                      ),
                    )
                  else
                    SButton(
                      label: 'Nueva oferta',
                      icon: Icons.add,
                      size: SButtonSize.sm,
                      fullWidth: false,
                      onPressed: onNuevaOferta,
                    ),
                ],
              ],
            ),
          ],
        ),
        SizedBox(height: t.space.xs),
        LayoutBuilder(
          builder: (context, limites) {
            final buscadorWidget = SSearchField(
              controller: buscador,
              hintText: 'Buscar prospecto',
              onChanged: onBuscar,
              onCleared: () => onBuscar(''),
            );
            final filtro = SSelectField<String>(
              value: etapaFiltro,
              opciones: opcionesEtapa,
              hint: 'Todas las etapas',
              onChanged: (v) => onEtapa(v ?? kTodasLasEtapas),
            );

            // En angosto los dos controles se apilan: uno al lado del otro deja
            // el select con la etiqueta cortada.
            if (limites.maxWidth < _anchoDosControles) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buscadorWidget,
                  SizedBox(height: t.space.xs),
                  filtro,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: buscadorWidget),
                SizedBox(width: t.space.xs),
                SizedBox(width: _anchoFiltro, child: filtro),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Avisos del pipeline: modo presentación activo y negocios cerrados sin razón.
class PipelineAvisos extends StatelessWidget {
  final bool modoPresentacion;
  final int cerradosSinRazon;

  /// `null` cuando ya se está filtrando por cerrados: el botón no llevaría a
  /// ningún lado.
  final VoidCallback? onVerCerrados;

  const PipelineAvisos({
    super.key,
    required this.modoPresentacion,
    required this.cerradosSinRazon,
    this.onVerCerrados,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    if (!modoPresentacion && cerradosSinRazon == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (modoPresentacion)
          _Cintillo(
            icono: Icons.visibility_off_outlined,
            fondo: tone.infoSoft,
            borde: tone.infoSoftStrong,
            texto: tone.infoFg,
            mensaje:
                'Modo presentación: nombres, correos y montos ocultos. '
                'Desactívalo arriba para verlos.',
          ),
        if (cerradosSinRazon > 0)
          _Cintillo(
            icono: Icons.report_problem_outlined,
            fondo: tone.warningSoft,
            borde: tone.warningSoftStrong,
            texto: tone.warningFg,
            mensaje: cerradosSinRazon == 1
                ? '1 negocio cerrado sin razón registrada. Cuéntanos por qué no '
                      'avanzó para mejorar precio, esquemas y producto.'
                : '$cerradosSinRazon negocios cerrados sin razón registrada. '
                      'Cuéntanos por qué no avanzaron para mejorar precio, '
                      'esquemas y producto.',
            accion: onVerCerrados == null
                ? null
                : SButton.secondary(
                    label: 'Ver cerrados',
                    size: SButtonSize.sm,
                    fullWidth: false,
                    onPressed: onVerCerrados,
                  ),
          ),
        SizedBox(height: t.space.xs),
      ],
    );
  }
}

class _Cintillo extends StatelessWidget {
  final IconData icono;
  final Color fondo;
  final Color borde;
  final Color texto;
  final String mensaje;
  final Widget? accion;

  const _Cintillo({
    required this.icono,
    required this.fondo,
    required this.borde,
    required this.texto,
    required this.mensaje,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      margin: EdgeInsets.only(top: t.space.xs),
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm,
        vertical: t.space.xs,
      ),
      decoration: BoxDecoration(
        color: fondo,
        border: Border.all(color: borde),
        borderRadius: t.radius.mdBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icono, size: _icono, color: texto),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(
              mensaje,
              style: t.text.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: texto,
              ),
            ),
          ),
          if (accion != null) ...[SizedBox(width: t.space.xs), accion!],
        ],
      ),
    );
  }
}

/// Cambio entre tabla, tarjetas y tablero.
class _SelectorVista extends StatelessWidget {
  final VistaPipeline vista;
  final ValueChanged<VistaPipeline> onVista;

  const _SelectorVista({required this.vista, required this.onVista});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    const opciones = <(VistaPipeline, IconData, String)>[
      (VistaPipeline.tabla, Icons.table_rows_outlined, 'Tabla'),
      (VistaPipeline.tarjetas, Icons.grid_view_outlined, 'Tarjetas'),
      (VistaPipeline.tablero, Icons.view_kanban_outlined, 'Tablero'),
    ];

    return Wrap(
      spacing: t.space.xxs,
      children: [
        for (final (v, icono, etiqueta) in opciones)
          SChoiceChip(
            label: etiqueta,
            icon: icono,
            size: SChoiceChipSize.sm,
            selected: vista == v,
            onSelected: (_) => onVista(v),
          ),
      ],
    );
  }
}

/// Ancho a partir del cual buscador y filtro caben en la misma línea.
const double _anchoDosControles = 520;

/// Ancho del filtro de etapa cuando comparte línea con el buscador.
const double _anchoFiltro = 240;

const double _icono = 16;
