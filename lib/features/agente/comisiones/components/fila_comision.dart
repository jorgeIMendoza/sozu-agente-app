import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// El selector de PDF y su validación son genéricos: viven en `core/` porque los
// comparten la factura de comisión y el expediente, en vez de duplicar la firma
// `%PDF-` y el tope de 10 MB.
import 'package:sozu_agente_app/core/archivo_pdf.dart';
import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/core/open_media.dart';
import 'package:sozu_agente_app/features/agente/comisiones/components/hoja_clientes.dart';
import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/features/agente/comisiones/providers/comisiones_providers.dart';
import 'package:sozu_agente_app/features/agente/home/components/estado_error_agente.dart';
import 'package:sozu_agente_app/shared/providers/modo_presentacion_provider.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Insignia de la etapa de la comisión.
///
/// "Aprobado" y "Pendiente" comparten el tono neutro porque el design system no
/// tiene un tono informativo; el icono es lo que los separa de un vistazo.
({SBadgeTone tono, IconData icono}) insigniaDeEtapa(EtapaComision etapa) =>
    switch (etapa) {
      EtapaComision.pagada => (
        tono: SBadgeTone.positive,
        icono: Icons.check_circle_outline,
      ),
      EtapaComision.aprobado => (
        tono: SBadgeTone.neutral,
        icono: Icons.verified_outlined,
      ),
      EtapaComision.enRevision => (
        tono: SBadgeTone.pending,
        icono: Icons.hourglass_empty,
      ),
      EtapaComision.pendiente => (
        tono: SBadgeTone.neutral,
        icono: Icons.schedule_outlined,
      ),
    };

/// Una comisión del agente: la operación, cuánto le toca, cómo va y sus dos
/// documentos (el comprobante que sube SOZU y la factura que sube él).
///
/// Es una tarjeta y no una fila de tabla: la tabla del portal web mide 1200 px y
/// en un teléfono se convierte en scroll horizontal, donde el monto —la columna
/// que importa— queda fuera de la pantalla.
class FilaComision extends ConsumerStatefulWidget {
  final Comision comision;

  const FilaComision({super.key, required this.comision});

  @override
  ConsumerState<FilaComision> createState() => _FilaComisionState();
}

class _FilaComisionState extends ConsumerState<FilaComision> {
  bool _subiendo = false;

  Future<void> _subirFactura() async {
    final comision = widget.comision;
    final archivo = await showSDocUpload(
      context,
      titulo: 'Factura de comisión',
      descripcion: 'Sube el PDF de tu factura de ${comision.folio}',
      // El tipo de documento lo fija el backend: aquí solo hace falta un valor
      // para que la hoja habilite Guardar, no se manda a ninguna parte.
      tipoId: 0,
      onSeleccionar: abrirPdf,
      validar: motivoArchivoInvalido,
      etiquetaGuardar: 'Subir factura',
    );
    if (archivo == null || !mounted) return;

    setState(() => _subiendo = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(comisionesPortProvider)
          .subirFactura(
            idCuentaCobranza: comision.idCuentaCobranza,
            nombreArchivo: archivo.nombre,
            archivo: archivo.bytes,
          );
      if (!mounted) return;
      setState(() => _subiendo = false);
      // Recargar y no parchear la fila en memoria: la factura cambia la etapa de
      // la comisión y los totales, y eso lo decide el backend.
      ref.invalidate(comisionesProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Factura subida.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _subiendo = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            mensajeAccionFallida(
              e,
              porCodigo: const {
                'formato_no_permitido': 'La factura debe ser un PDF.',
                'archivo_muy_grande': 'El archivo supera los 10 MB.',
                'estatus_no_permite_factura':
                    'Todavía no puedes facturar esta comisión.',
              },
              generico: 'No pudimos subir tu factura. Intenta de nuevo.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final c = widget.comision;
    final modo = ref.watch(modoPresentacionProvider);
    final insignia = insigniaDeEtapa(c.etapa);
    final unidad = c.unidad;

    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.folio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.text.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tone.fgMuted,
                        fontFeatures: SozuType.tabular,
                      ),
                    ),
                    Text(
                      c.proyecto.isEmpty ? 'Sin proyecto' : c.proyecto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.text.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tone.fg,
                      ),
                    ),
                    if (unidad.isNotEmpty)
                      Text(
                        unidad,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.text.caption.copyWith(color: tone.fgMuted),
                      ),
                  ],
                ),
              ),
              SizedBox(width: t.space.xs),
              SBadge(
                label: c.etapaEtiqueta,
                tone: insignia.tono,
                icon: insignia.icono,
                size: SBadgeSize.sm,
              ),
            ],
          ),
          SizedBox(height: t.space.sm),
          _Clientes(comision: c, enmascarar: modo.enmascarar),
          SizedBox(height: t.space.sm),
          Divider(height: 1, thickness: 1, color: tone.borderSoft),
          SizedBox(height: t.space.sm),
          // Venta y comisión juntas: el porcentaje sin el precio no se puede
          // verificar, y el monto sin el porcentaje no se puede explicar.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Cifra(
                  etiqueta: 'Venta',
                  valor: modo.enmascarar(formatMXN(c.precioFinal)),
                ),
              ),
              SizedBox(width: t.space.xs),
              Expanded(
                child: _Cifra(
                  etiqueta:
                      'Comisión +IVA · ${c.porcentajeComision.toStringAsFixed(2)}%',
                  valor: modo.enmascarar(formatMXN(c.montoComision)),
                  destacado: true,
                ),
              ),
            ],
          ),
          if (c.fechaPago != null) ...[
            SizedBox(height: t.space.xs),
            Text(
              'Pagada el ${formatDateEsMX(c.fechaPago)}',
              style: t.text.caption.copyWith(color: tone.fgSubtle),
            ),
          ],
          SizedBox(height: t.space.sm),
          _Documentos(
            comision: c,
            subiendo: _subiendo,
            onSubirFactura: _subirFactura,
          ),
        ],
      ),
    );
  }
}

/// Cliente único con su correo, o el acceso al listado cuando hay copropiedad.
class _Clientes extends StatelessWidget {
  final Comision comision;
  final String Function(String) enmascarar;

  const _Clientes({required this.comision, required this.enmascarar});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final clientes = comision.clientes;

    if (clientes.isEmpty) {
      return Text(
        'Sin cliente',
        style: t.text.caption.copyWith(color: tone.fgSubtle),
      );
    }
    if (clientes.length == 1) {
      final cliente = clientes.first;
      return Row(
        children: [
          Icon(Icons.person_outline, size: 14, color: tone.fgSubtle),
          SizedBox(width: t.space.xxs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente.nombre.isEmpty
                      ? 'Sin nombre'
                      : enmascarar(cliente.nombre),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fg,
                  ),
                ),
                if (cliente.email.isNotEmpty)
                  Text(
                    enmascarar(cliente.email),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.caption.copyWith(color: tone.fgMuted),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: SButton.link(
        label: '${clientes.length} compradores',
        icon: Icons.groups_outlined,
        size: SButtonSize.sm,
        onPressed: () => mostrarClientesComision(
          context,
          folio: comision.folio,
          clientes: clientes,
          enmascarar: enmascarar,
        ),
      ),
    );
  }
}

/// Etiqueta chica sobre una cifra.
class _Cifra extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool destacado;

  const _Cifra({
    required this.etiqueta,
    required this.valor,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: t.text.overline.copyWith(color: tone.fgMuted),
        ),
        SizedBox(height: t.space.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            valor,
            style: t.text.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: destacado ? tone.positive : tone.fg,
              fontFeatures: SozuType.tabular,
            ),
          ),
        ),
      ],
    );
  }
}

/// Los dos documentos de la comisión: el comprobante de pago (solo lectura) y la
/// factura del agente (ver o subir).
class _Documentos extends StatelessWidget {
  final Comision comision;
  final bool subiendo;
  final VoidCallback onSubirFactura;

  const _Documentos({
    required this.comision,
    required this.subiendo,
    required this.onSubirFactura,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final comprobante = comision.comprobanteUrl;
    final factura = comision.facturaUrl;

    return Wrap(
      spacing: t.space.xs,
      runSpacing: t.space.xxs,
      children: [
        if (comprobante != null && comprobante.isNotEmpty)
          SButton.ghost(
            label: 'Comprobante',
            icon: Icons.receipt_long_outlined,
            size: SButtonSize.sm,
            onPressed: () => openMedia(
              context,
              comprobante,
              titulo: 'Comprobante de pago · ${comision.folio}',
            ),
          ),
        if (factura != null && factura.isNotEmpty)
          SButton.ghost(
            label: 'Mi factura',
            icon: Icons.description_outlined,
            size: SButtonSize.sm,
            onPressed: () => openMedia(
              context,
              factura,
              titulo: 'Factura · ${comision.folio}',
            ),
          )
        else if (comision.puedeSubirFactura)
          SButton.secondary(
            label: 'Subir factura',
            icon: Icons.upload_file_outlined,
            size: SButtonSize.sm,
            fullWidth: false,
            loading: subiendo,
            loadingLabel: 'Subiendo…',
            onPressed: onSubirFactura,
          )
        else
          // Ni factura ni permiso de subirla: se dice cuándo podrá, en vez de
          // dejar la celda vacía o un botón muerto que se toca tres veces.
          Text(
            'Podrás facturar cuando se apruebe tu comisión.',
            style: t.text.caption.copyWith(color: tone.fgSubtle),
          ),
      ],
    );
  }
}
