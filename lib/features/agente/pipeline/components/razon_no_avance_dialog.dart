import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/pipeline_modal.dart';
import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/features/agente/pipeline/providers/pipeline_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Largo máximo del detalle; el servidor recorta a 500.
const int _maxComentario = 500;

/// Captura de la razón por la que un negocio cerrado no avanzó.
///
/// Se abre desde la fila, la tarjeta y el detalle de la oferta. Si ya había una
/// razón, entra en modo corrección con el motivo y el detalle precargados.
///
/// Devuelve `true` al cerrarse si se guardó algo, para que la pantalla avise.
class RazonNoAvanceHoja extends ConsumerStatefulWidget {
  final Negocio negocio;
  final CatalogoRazones catalogo;

  /// Sin permiso de actualizar, la hoja queda en solo lectura.
  final bool puedeActualizar;

  const RazonNoAvanceHoja({
    super.key,
    required this.negocio,
    required this.catalogo,
    required this.puedeActualizar,
  });

  @override
  ConsumerState<RazonNoAvanceHoja> createState() => _RazonNoAvanceHojaState();
}

class _RazonNoAvanceHojaState extends ConsumerState<RazonNoAvanceHoja> {
  final _comentario = TextEditingController();
  int? _motivoId;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final registro = widget.negocio.razonNoAvance;
    _motivoId = registro?.idMotivo;
    _comentario.text = registro?.comentario ?? '';
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  MotivoNoAvance? get _motivo {
    for (final m in widget.catalogo.motivos) {
      if (m.id == _motivoId) return m;
    }
    return null;
  }

  bool get _faltaComentario =>
      (_motivo?.requiereComentario ?? false) && _comentario.text.trim().isEmpty;

  /// Por qué no se puede guardar. Sin esto, un botón apagado no dice si falta
  /// el motivo, el detalle, el permiso o el catálogo.
  String? get _bloqueo {
    if (!widget.puedeActualizar) {
      return 'No tienes permiso para editar el pipeline.';
    }
    if (!widget.catalogo.disponible) {
      return 'El catálogo de razones todavía no está habilitado en este ambiente.';
    }
    if (_motivoId == null) return 'Elige una razón para guardar.';
    if (_faltaComentario) return 'Este motivo necesita que escribas el detalle.';
    return null;
  }

  Future<void> _guardar() async {
    final id = _motivoId;
    if (_bloqueo != null || id == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(pipelineAccionesProvider).registrarRazon(
        idOferta: widget.negocio.idOferta,
        idMotivo: id,
        comentario: _comentario.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeDeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final registro = widget.negocio.razonNoAvance;
    final motivos = widget.catalogo.motivos;

    return HojaPipeline(
      icono: Icons.help_outline,
      titulo: '¿Por qué no avanzó este negocio?',
      subtitulo: '${widget.negocio.folio} · ${widget.negocio.unidad}',
      nota: _bloqueo,
      cuerpo: [
        if (!widget.catalogo.disponible)
          _Aviso(
            texto:
                'El catálogo de razones aún no está habilitado en este '
                'ambiente. Puedes revisar las opciones, pero el guardado se '
                'activa cuando el administrador ejecute la configuración '
                'pendiente.',
          ),
        Text(
          'Tu respuesta nos dice dónde se cae el pipeline y sirve para ajustar '
          'precios, esquemas de pago y producto. Elige la razón principal.',
          style: t.text.bodySmall.copyWith(color: tone.fgMuted),
        ),
        SizedBox(height: t.space.sm),
        if (motivos.isEmpty)
          _Aviso(
            texto:
                'No hay razones dadas de alta en el catálogo. Pide al '
                'administrador que lo configure.',
          )
        else
          for (final m in motivos) ...[
            _OpcionMotivo(
              motivo: m,
              seleccionado: m.id == _motivoId,
              habilitado: widget.puedeActualizar,
              onTap: () => setState(
                () => _motivoId = _motivoId == m.id ? null : m.id,
              ),
            ),
            SizedBox(height: t.space.xxs),
          ],
        SizedBox(height: t.space.xs),
        STextField(
          controller: _comentario,
          size: STextFieldSize.md,
          label: _motivo?.requiereComentario == true
              ? 'Detalle (obligatorio)'
              : 'Detalle (opcional)',
          hint: 'Qué pedía el prospecto, con qué comparó, qué le faltó',
          maxLines: 3,
          maxLength: _maxComentario,
          enabled: widget.puedeActualizar,
          errorText: _faltaComentario
              ? 'Este motivo requiere que escribas el detalle.'
              : null,
          onChanged: (_) => setState(() {}),
        ),
        if (registro?.fecha != null) ...[
          SizedBox(height: t.space.xs),
          Text(
            'Registrada por ${registro!.registradoPor ?? 'un usuario'} el '
            '${formatDateEsMX(registro.fecha)}.',
            style: t.text.caption.copyWith(color: tone.fgSubtle),
          ),
        ],
        if (_error != null) ...[
          SizedBox(height: t.space.xs),
          Text(
            _error!,
            style: t.text.bodySmall.copyWith(color: tone.danger),
          ),
        ],
      ],
      acciones: [
        SButton.secondary(
          label: 'Cerrar',
          fullWidth: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SButton(
          label: registro == null ? 'Guardar razón' : 'Actualizar razón',
          fullWidth: false,
          loading: _guardando,
          onPressed: _bloqueo == null ? _guardar : null,
        ),
      ],
    );
  }
}

/// Una opción del catálogo. El borde de marca marca la elegida; el badge avisa
/// cuando el motivo es un cierre definitivo (no se recupera el prospecto).
class _OpcionMotivo extends StatelessWidget {
  final MotivoNoAvance motivo;
  final bool seleccionado;
  final bool habilitado;
  final VoidCallback onTap;

  const _OpcionMotivo({
    required this.motivo,
    required this.seleccionado,
    required this.habilitado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    final contenido = SCard.outlined(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm,
        vertical: t.space.xs,
      ),
      borderColor: seleccionado ? tone.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (seleccionado) ...[
                Icon(Icons.check_circle, size: _icono, color: tone.primary),
                SizedBox(width: t.space.xxs),
              ],
              Expanded(
                child: Text(
                  motivo.nombre,
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fg,
                  ),
                ),
              ),
              if (!motivo.esRecuperable)
                const SBadge(
                  label: 'Definitiva',
                  tone: SBadgeTone.negative,
                  size: SBadgeSize.sm,
                ),
            ],
          ),
          if (motivo.descripcion != null)
            Text(
              motivo.descripcion!,
              style: t.text.caption.copyWith(color: tone.fgMuted),
            ),
        ],
      ),
    );

    if (!habilitado) return Opacity(opacity: 0.6, child: contenido);

    return SPressable(
      onTap: onTap,
      borderRadius: t.radius.lgBorder,
      child: contenido,
    );
  }
}

/// Cintillo de advertencia de la hoja.
class _Aviso extends StatelessWidget {
  final String texto;

  const _Aviso({required this.texto});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Container(
      margin: EdgeInsets.only(bottom: t.space.xs),
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm,
        vertical: t.space.xs,
      ),
      decoration: BoxDecoration(
        color: tone.warningSoft,
        borderRadius: t.radius.mdBorder,
        border: Border.all(color: tone.warningSoftStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: _icono, color: tone.warningFg),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(
              texto,
              style: t.text.caption.copyWith(color: tone.warningFg),
            ),
          ),
        ],
      ),
    );
  }
}

const double _icono = 16;
