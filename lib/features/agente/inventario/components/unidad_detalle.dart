import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/esquema_pago_card.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/galeria_imagenes.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/hoja_inventario.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/unidad_card.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/features/agente/inventario/providers/inventario_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Detalle de una unidad: galería, contexto, especificaciones, planos, precio de
/// lista y los esquemas de pago con sus montos.
///
/// Recibe todo por parámetro (incluidos los permisos ya resueltos): quien la
/// abre es la pantalla, que sí lee providers.
Future<void> mostrarDetalleUnidad(
  BuildContext context, {
  required Unidad unidad,
  required List<EsquemaPago> esquemas,
  required int mesesEfectivos,

  /// Abre el visor de planos de la unidad.
  required VoidCallback onVerPlanos,

  /// Permiso de generar oferta del rol (`generar_oferta`).
  required bool puedeGenerarOferta,

  /// Capacitación del agente terminada. Sin ella el botón queda deshabilitado
  /// con el motivo escrito: un botón gris sin explicación se reporta como bug.
  required bool capacitacionCompleta,

  /// Punto de entrada de la configuración de oferta, con el esquema elegido.
  required void Function(EsquemaPago? esquema) onConfigurarOferta,
}) {
  return mostrarHojaInventario<void>(
    context,
    titulo: 'Departamento ${unidad.etiqueta}',
    subtitulo: unidad.desarrolloNombre,
    cuerpo: (ctx) => _DetalleUnidad(
      unidad: unidad,
      esquemas: esquemas,
      mesesEfectivos: mesesEfectivos,
      onVerPlanos: onVerPlanos,
      puedeGenerarOferta: puedeGenerarOferta,
      capacitacionCompleta: capacitacionCompleta,
      onConfigurarOferta: onConfigurarOferta,
    ),
  );
}

class _DetalleUnidad extends ConsumerStatefulWidget {
  final Unidad unidad;
  final List<EsquemaPago> esquemas;
  final int mesesEfectivos;
  final VoidCallback onVerPlanos;
  final bool puedeGenerarOferta;
  final bool capacitacionCompleta;
  final void Function(EsquemaPago? esquema) onConfigurarOferta;

  const _DetalleUnidad({
    required this.unidad,
    required this.esquemas,
    required this.mesesEfectivos,
    required this.onVerPlanos,
    required this.puedeGenerarOferta,
    required this.capacitacionCompleta,
    required this.onConfigurarOferta,
  });

  @override
  ConsumerState<_DetalleUnidad> createState() => _DetalleUnidadState();
}

class _DetalleUnidadState extends ConsumerState<_DetalleUnidad> {
  int? _idEsquema;

  EsquemaPago? get _esquema =>
      widget.esquemas.where((e) => e.id == _idEsquema).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final u = widget.unidad;
    // Los planos se piden aquí y no en la pantalla: el botón solo existe si la
    // unidad tiene alguno, y eso lo dice el servidor. Ofrecerlo siempre manda al
    // agente a una pantalla vacía delante del cliente.
    final planos = ref.watch(planosUnidadProvider(u.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (u.imagenes.isNotEmpty)
          ClipRRect(
            borderRadius: t.radius.lgBorder,
            child: CarruselImagenes(
              imagenes: u.imagenes,
              conFlechas: true,
              ajuste: BoxFit.cover,
              onTocar: (i) => mostrarVisorImagenes(
                context,
                u.imagenes,
                indice: i,
                titulo: 'Departamento ${u.etiqueta}',
              ),
            ),
          ),
        SizedBox(height: t.space.sm),

        // Contexto: edificio, modelo y nivel.
        Wrap(
          spacing: t.space.xxs,
          runSpacing: t.space.xxs,
          children: [
            if ((u.edificioNombre ?? '').isNotEmpty)
              SBadge(label: u.edificioNombre!, size: SBadgeSize.sm),
            if ((u.modeloNombre ?? '').isNotEmpty)
              SBadge(label: u.modeloNombre!, size: SBadgeSize.sm),
            if ((u.nivel ?? '').isNotEmpty)
              SBadge(label: 'Nivel ${u.nivel}', size: SBadgeSize.sm),
          ],
        ),
        SizedBox(height: t.space.sm),

        SCard.outlined(
          child: Wrap(
            spacing: t.space.md,
            runSpacing: t.space.xs,
            children: especificacionesDeUnidad(u),
          ),
        ),

        if (planos.isLoading) ...[
          SizedBox(height: t.space.sm),
          SButton.secondary(
            label: 'Ver planos',
            icon: Icons.architecture_outlined,
            loading: true,
            onPressed: null,
          ),
        ] else if (planos.valueOrNull?.vacio == false) ...[
          SizedBox(height: t.space.sm),
          SButton.secondary(
            label: 'Ver planos',
            icon: Icons.architecture_outlined,
            onPressed: widget.onVerPlanos,
          ),
        ],

        if (u.precioLista > 0) ...[
          SizedBox(height: t.space.sm),
          Container(
            padding: EdgeInsets.all(t.space.md),
            decoration: BoxDecoration(
              color: tone.primarySoft,
              borderRadius: t.radius.lgBorder,
              border: Border.all(color: tone.primaryBorder),
            ),
            child: Column(
              children: [
                Text(
                  'PRECIO DE LISTA',
                  style: t.text.overline.copyWith(color: tone.primaryHover),
                ),
                SizedBox(height: t.space.xxs),
                Text(
                  formatMXN(u.precioLista),
                  style: t.text.h2.copyWith(color: tone.primaryHover),
                ),
              ],
            ),
          ),
        ],

        if (widget.esquemas.isNotEmpty) ...[
          SizedBox(height: t.space.md),
          SSectionLabel(
            text: 'Esquemas de pago',
            trailing: SBadge(
              label: '${widget.esquemas.length}',
              size: SBadgeSize.sm,
            ),
          ),
          SizedBox(height: t.space.xs),
          for (final e in widget.esquemas) ...[
            EsquemaPagoCard(
              esquema: e,
              precioLista: u.precioLista,
              mesesEfectivos: widget.mesesEfectivos,
              seleccionado: _idEsquema == e.id,
              onSeleccionar: () =>
                  setState(() => _idEsquema = _idEsquema == e.id ? null : e.id),
            ),
            SizedBox(height: t.space.xs),
          ],
        ],

        if (widget.puedeGenerarOferta) ...[
          SizedBox(height: t.space.xs),
          if (!widget.capacitacionCompleta)
            SButton(
              label: 'Completa tu capacitación',
              icon: Icons.school_outlined,
              onPressed: null,
            )
          else
            SButton(
              label: _esquema == null
                  ? 'Configurar oferta'
                  : 'Configurar oferta (${_esquema!.nombre})',
              icon: Icons.request_quote_outlined,
              onPressed: () => widget.onConfigurarOferta(_esquema),
            ),
          if (!widget.capacitacionCompleta) ...[
            SizedBox(height: t.space.xxs),
            Text(
              'Para generar ofertas necesitas terminar la capacitación en tu '
              'perfil.',
              style: t.text.caption.copyWith(color: tone.fgMuted),
            ),
          ],
        ],
      ],
    );
  }
}
