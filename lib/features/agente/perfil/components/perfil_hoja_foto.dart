import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/archivos_del_perfil.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/mensajes_del_perfil.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/network_image.dart';

/// Foto de perfil: cargar una nueva, verla antes de guardar, o quitarla.
///
/// Devuelve un mensaje de éxito cuando algo cambió (para que la pantalla lo
/// anuncie), o null si el agente cerró sin tocar nada.
Future<String?> mostrarHojaDeFoto(
  BuildContext context, {
  required String nombre,
  required String? fotoUrl,
}) => mostrarHojaDePerfil<String>(
  context,
  anchoMaximo: 420,
  child: _HojaDeFoto(nombre: nombre, fotoUrl: fotoUrl),
);

class _HojaDeFoto extends ConsumerStatefulWidget {
  final String nombre;
  final String? fotoUrl;

  const _HojaDeFoto({required this.nombre, required this.fotoUrl});

  @override
  ConsumerState<_HojaDeFoto> createState() => _HojaDeFotoState();
}

class _HojaDeFotoState extends ConsumerState<_HojaDeFoto> {
  Uint8List? _bytes;
  String? _nombreArchivo;
  bool _guardando = false;
  bool _borrando = false;
  String? _error;

  bool get _hayFoto => (widget.fotoUrl ?? '').isNotEmpty;

  Future<void> _elegir() async {
    setState(() => _error = null);
    final archivo = await elegirFoto();
    if (archivo == null || !mounted) return;
    final motivo = motivoFotoInvalida(archivo.nombre, archivo.bytes);
    if (motivo != null) {
      setState(() => _error = motivo);
      return;
    }
    setState(() {
      _bytes = archivo.bytes;
      _nombreArchivo = archivo.nombre;
    });
  }

  Future<void> _guardar() async {
    final bytes = _bytes;
    final nombreArchivo = _nombreArchivo;
    if (bytes == null || nombreArchivo == null) return;
    final mime = mimeDeFoto(nombreArchivo);
    if (mime == null) {
      setState(() => _error = 'Solo se aceptan imágenes JPG, PNG o WebP.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(perfilAgentePortProvider)
          .guardarFoto(base64: base64Encode(bytes), mime: mime);
      if (mounted) Navigator.of(context).pop('Foto de perfil actualizada');
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo subir la foto. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar() async {
    // Quitar la foto es reversible (basta volver a subirla), pero es un cambio
    // visible para sus prospectos: se confirma antes.
    final ok = await showSConfirm(
      context,
      titulo: '¿Quitar tu foto de perfil?',
      mensaje:
          'Volverás a mostrar tus iniciales ante tus prospectos. Puedes subir '
          'otra cuando quieras.',
      etiquetaAceptar: 'Quitar foto',
      tono: SConfirmTone.warning,
    );
    if (ok != true || !mounted) return;

    setState(() {
      _borrando = true;
      _error = null;
    });
    try {
      await ref.read(perfilAgentePortProvider).borrarFoto();
      if (mounted) Navigator.of(context).pop('Foto de perfil eliminada');
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo eliminar la foto.');
    } finally {
      if (mounted) setState(() => _borrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final ocupado = _guardando || _borrando;

    // Vista previa: lo que se va a guardar manda sobre lo que ya está.
    final Widget avatar = _bytes != null
        ? ClipOval(
            child: Image.memory(
              _bytes!,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          )
        : _hayFoto
        ? ClipOval(
            child: SizedBox(
              width: 96,
              height: 96,
              child: SozuNetworkImage(
                url: widget.fotoUrl,
                placeholderIcon: Icons.person_outline,
              ),
            ),
          )
        : SAvatar(initials: initials(widget.nombre), size: 96);

    return HojaDePerfil(
      titulo: _bytes != null ? 'Vista previa' : 'Foto de perfil',
      subtitulo: _bytes != null
          ? 'Así se verá tu foto de perfil'
          : widget.nombre,
      acciones: _bytes != null
          ? [
              SButton(
                label: 'Volver',
                onPressed: ocupado
                    ? null
                    : () => setState(() {
                        _bytes = null;
                        _nombreArchivo = null;
                      }),
                variant: SButtonVariant.secondary,
                size: SButtonSize.md,
                fullWidth: false,
              ),
              SButton(
                label: 'Guardar foto',
                icon: Icons.check,
                onPressed: _guardar,
                loading: _guardando,
                loadingLabel: 'Guardando…',
                size: SButtonSize.md,
                fullWidth: false,
              ),
            ]
          : [
              SButton(
                label: 'Cerrar',
                onPressed: ocupado
                    ? null
                    : () => Navigator.of(context).maybePop(),
                variant: SButtonVariant.secondary,
                size: SButtonSize.md,
                fullWidth: false,
              ),
            ],
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: avatar),
          SizedBox(height: t.space.lg),
          if (_bytes == null) ...[
            SButton(
              label: _hayFoto ? 'Cambiar foto' : 'Cargar foto',
              icon: Icons.upload_outlined,
              onPressed: ocupado ? null : _elegir,
              variant: SButtonVariant.secondary,
            ),
            SizedBox(height: t.space.xxs),
            Text(
              'JPG, PNG o WebP, hasta 10 MB.',
              textAlign: TextAlign.center,
              style: t.text.overline.copyWith(color: t.color.fgSubtle),
            ),
            if (_hayFoto) ...[
              SizedBox(height: t.space.sm),
              SButton(
                label: 'Eliminar foto',
                icon: Icons.delete_outline,
                onPressed: ocupado ? null : _borrar,
                loading: _borrando,
                loadingLabel: 'Eliminando…',
                variant: SButtonVariant.danger,
              ),
              SizedBox(height: t.space.xxs),
              Text(
                'Vuelves a mostrar tus iniciales.',
                textAlign: TextAlign.center,
                style: t.text.overline.copyWith(color: t.color.fgSubtle),
              ),
            ],
          ] else
            Text(
              _nombreArchivo ?? '',
              textAlign: TextAlign.center,
              style: t.text.overline.copyWith(color: t.color.fgSubtle),
            ),
          if (_error != null) ...[
            SizedBox(height: t.space.md),
            Text(
              _error!,
              style: t.text.caption.copyWith(color: t.color.danger),
            ),
          ],
        ],
      ),
    );
  }
}
