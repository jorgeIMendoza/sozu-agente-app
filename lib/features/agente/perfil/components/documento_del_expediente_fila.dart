import 'package:flutter/material.dart';

import 'package:sozu_agente_app/features/agente/perfil/components/perfil_fila_seccion.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Fila de un documento del expediente del agente: nombre, emisor, estatus, la
/// nota que lo explica y las acciones de entregar y consultar.
///
/// Tonta: recibe el documento y qué hacer. Ni providers ni red.
class DocumentoDelExpedienteFila extends StatelessWidget {
  final DocumentoDelExpediente documento;

  /// Este documento se está subiendo.
  final bool ocupado;

  /// Hay otra subida en curso: se bloquean las demás para no dejar el expediente
  /// a medias si el agente toca dos filas seguidas.
  final bool bloqueado;

  /// Entrega el documento (subir, o firmar cuando es la carta).
  final VoidCallback onEntregar;

  /// Abre el archivo ya entregado; null si todavía no hay ninguno.
  final VoidCallback? onVer;

  /// Posición del documento en la lista (1, 2, 3...). Null la omite.
  final int? numero;

  const DocumentoDelExpedienteFila({
    super.key,
    required this.documento,
    required this.onEntregar,
    this.ocupado = false,
    this.bloqueado = false,
    this.onVer,
    this.numero,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final d = documento;
    final puedeActuar = !d.soloLectura && !ocupado && !bloqueado;

    // Segunda línea: emisor + si ya está entregado + qué se espera del archivo.
    final detalle = <String>[
      if (d.emisor.isNotEmpty) d.emisor,
      if (d.soloLectura)
        d.tieneArchivo ? 'Cargado · solo consulta' : 'Aún sin cargar'
      else
        d.tieneArchivo ? 'Cargado' : 'Sin cargar',
      if (!d.tieneArchivo && d.ayuda.isNotEmpty) d.ayuda,
    ].join(' · ');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.md,
        vertical: t.space.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: tone.border),
        borderRadius: t.radius.mdBorder,
        color: d.soloLectura ? tone.surfaceAlt : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (numero != null) ...[
                _Numero(valor: numero!),
                SizedBox(width: t.space.xs),
              ],
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.surfaceAlt,
                  borderRadius: t.radius.mdBorder,
                ),
                child: Icon(
                  d.seFirma ? Icons.draw_outlined : Icons.description_outlined,
                  size: 17,
                  color: tone.fgMuted,
                ),
              ),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: t.space.xs,
                      runSpacing: t.space.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          d.nombre,
                          style: t.text.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tone.fg,
                          ),
                        ),
                        SBadge(
                          label: d.estado.etiqueta,
                          tone: tonoDeDocumento(d.estado),
                          size: SBadgeSize.sm,
                        ),
                        if (d.soloLectura)
                          const SBadge(
                            label: 'Solo lectura',
                            tone: SBadgeTone.neutral,
                            size: SBadgeSize.sm,
                            icon: Icons.lock_outline,
                          ),
                      ],
                    ),
                    SizedBox(height: t.space.xxs),
                    Text(
                      detalle,
                      style: t.text.overline.copyWith(
                        fontWeight: FontWeight.w500,
                        color: tone.fgSubtle,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: t.space.xs),
              _Accion(
                tooltip: d.seFirma
                    ? 'Firmar documento'
                    : d.tieneArchivo
                    ? 'Reemplazar documento'
                    : 'Subir documento',
                onTap: puedeActuar ? onEntregar : null,
                icono: d.seFirma
                    ? Icons.draw_outlined
                    : d.tieneArchivo
                    ? Icons.edit_outlined
                    : Icons.upload_outlined,
                ocupado: ocupado,
              ),
              if (onVer != null) ...[
                SizedBox(width: t.space.xxs),
                _Accion(
                  tooltip: 'Ver documento',
                  onTap: onVer,
                  icono: Icons.visibility_outlined,
                ),
              ],
            ],
          ),
          // La nota explica POR QUÉ el agente no puede tocarlo. Sin ella, un
          // renglón gris parece un error de la app.
          if (d.soloLectura && (d.nota ?? '').isNotEmpty) ...[
            SizedBox(height: t.space.xs),
            _Nota(
              icono: Icons.lock_outline,
              texto: d.tieneArchivo
                  ? d.nota!
                  : '${d.nota!}. Cuando la carguen podrás consultarla aquí.',
            ),
          ],
          // Estado de la firma: qué sigue, en su idioma.
          if (d.firma != null) ...[
            SizedBox(height: t.space.xs),
            _Nota(icono: Icons.info_outline, texto: d.firma!.ayuda),
          ],
          if (d.estado == EstadoDocumento.rechazado) ...[
            SizedBox(height: t.space.xs),
            _Nota(
              icono: Icons.replay_outlined,
              texto:
                  'Verificación lo rechazó. Vuelve a cargarlo completo y '
                  'legible para que podamos validarlo.',
              alerta: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Posición del documento en la lista, a la izquierda de la fila. Le da al
/// agente cómo referirse a uno ("el 3") cuando pide ayuda.
class _Numero extends StatelessWidget {
  final int valor;

  const _Numero({required this.valor});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.color.muted,
        borderRadius: t.radius.smBorder,
      ),
      child: Text(
        '$valor',
        style: t.text.overline.copyWith(
          fontWeight: FontWeight.w700,
          color: t.color.fgMuted,
        ),
      ),
    );
  }
}

class _Accion extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onTap;
  final IconData icono;
  final bool ocupado;

  const _Accion({
    required this.tooltip,
    required this.onTap,
    required this.icono,
    this.ocupado = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final habilitado = onTap != null && !ocupado;

    return SPressable(
      onTap: habilitado ? onTap : null,
      tooltip: tooltip,
      semanticLabel: tooltip,
      borderRadius: t.radius.smBorder,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tone.surface,
          border: Border.all(color: tone.border),
          borderRadius: t.radius.smBorder,
        ),
        child: ocupado
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                icono,
                size: 17,
                color: habilitado
                    ? tone.fgMuted
                    : tone.fgSubtle.withValues(alpha: 0.4),
              ),
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool alerta;

  const _Nota({required this.icono, required this.texto, this.alerta = false});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final color = alerta ? t.color.danger : t.color.fgMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 14, color: color),
        SizedBox(width: t.space.xxs),
        Expanded(
          child: Text(
            texto,
            style: t.text.overline.copyWith(color: color, height: 1.5),
          ),
        ),
      ],
    );
  }
}
