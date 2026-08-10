import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/prospectos/components/prospecto_modal.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/prospectos_reglas.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Tope por archivo que aplica el servidor.
const int _maxBytesAdjunto = 10 * 1024 * 1024;

/// Abre el editor de una nota nueva. Devuelve `true` si se guardó.
Future<bool?> escribirNota(
  BuildContext context, {
  required int idPersona,
  int? idRelacion,
}) => mostrarHojaProspecto<bool>(
  context,
  _HojaNota(idPersona: idPersona, idRelacion: idRelacion),
);

/// Abre una nota propia para editarla o borrarla. Devuelve `true` si cambió algo.
Future<bool?> abrirNota(
  BuildContext context, {
  required int idNota,
  required String texto,
  List<AdjuntoNota> adjuntos = const [],
}) => mostrarHojaProspecto<bool>(
  context,
  _HojaNota(idNota: idNota, textoInicial: texto, adjuntosExistentes: adjuntos),
);

/// Editor de nota interna.
///
/// En la web la nota es HTML enriquecido; aquí es TEXTO PLANO con archivos
/// pegados. No se mete un editor de HTML ni un visor de HTML como dependencia
/// nueva por dos razones: el 99% de las notas del portal son un párrafo y una
/// foto, y un visor de HTML de terceros en una pantalla que muestra datos de
/// clientes es superficie de ataque sin necesidad. Lo que ya venía escrito en
/// HTML se lee como texto (el servidor manda su versión plana) y sus archivos
/// siguen listados aparte.
class _HojaNota extends ConsumerStatefulWidget {
  /// Prospecto al que se le agrega la nota; null cuando se edita una existente.
  final int? idPersona;

  final int? idRelacion;

  /// Nota existente que se está editando; null = nota nueva.
  final int? idNota;

  final String textoInicial;
  final List<AdjuntoNota> adjuntosExistentes;

  const _HojaNota({
    this.idPersona,
    this.idRelacion,
    this.idNota,
    this.textoInicial = '',
    this.adjuntosExistentes = const [],
  });

  @override
  ConsumerState<_HojaNota> createState() => _HojaNotaState();
}

class _HojaNotaState extends ConsumerState<_HojaNota> {
  late final TextEditingController _texto;
  final List<AdjuntoNuevo> _nuevos = [];
  bool _trabajando = false;
  String? _error;

  bool get _esEdicion => widget.idNota != null;

  @override
  void initState() {
    super.initState();
    _texto = TextEditingController(text: widget.textoInicial);
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  bool get _hayContenido =>
      _texto.text.trim().isNotEmpty ||
      _nuevos.isNotEmpty ||
      widget.adjuntosExistentes.isNotEmpty;

  Future<void> _adjuntar() async {
    const grupo = XTypeGroup(
      label: 'Imagen o documento',
      extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
    );
    final archivo = await openFile(acceptedTypeGroups: const [grupo]);
    if (archivo == null) return;
    final bytes = await archivo.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxBytesAdjunto) {
      setState(() => _error = 'El archivo supera el límite de 10 MB.');
      return;
    }
    setState(() {
      _error = null;
      _nuevos.add(
        AdjuntoNuevo(
          nombre: archivo.name,
          contentType: _tipoDeContenido(archivo.name),
          bytes: Uint8List.fromList(bytes),
        ),
      );
    });
  }

  Future<void> _guardar() async {
    if (!_hayContenido) {
      setState(() => _error = 'Escribe algo o adjunta un archivo.');
      return;
    }
    setState(() {
      _trabajando = true;
      _error = null;
    });
    try {
      final port = ref.read(prospectosPortProvider);
      if (_esEdicion) {
        await port.editarNota(
          idNota: widget.idNota!,
          texto: _texto.text,
          adjuntos: widget.adjuntosExistentes,
        );
      } else {
        await port.agregarNota(
          idPersona: widget.idPersona!,
          idRelacion: widget.idRelacion,
          texto: _texto.text,
          adjuntos: _nuevos,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _trabajando = false;
        _error = mensajeDeErrorProspecto(
          e,
          porDefecto: 'No se pudo guardar la nota.',
        );
      });
    }
  }

  Future<void> _borrar() async {
    final ok = await showSConfirm(
      context,
      titulo: '¿Borrar esta nota?',
      mensaje: 'Dejará de aparecer en la actividad del prospecto.',
      etiquetaAceptar: 'Borrar',
      tono: SConfirmTone.warning,
    );
    if (ok != true || !mounted) return;
    setState(() {
      _trabajando = true;
      _error = null;
    });
    try {
      await ref.read(prospectosPortProvider).eliminarNota(widget.idNota!);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _trabajando = false;
        _error = mensajeDeErrorProspecto(
          e,
          porDefecto: 'No se pudo borrar la nota.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return HojaProspecto(
      icono: Icons.sticky_note_2_outlined,
      titulo: _esEdicion ? 'Editar nota' : 'Nueva nota',
      subtitulo: 'Nota interna · solo visible para ti',
      acciones: [
        if (_esEdicion)
          SButton(
            label: 'Borrar',
            variant: SButtonVariant.danger,
            fullWidth: false,
            onPressed: _trabajando ? null : _borrar,
          ),
        SButton.secondary(
          label: 'Cancelar',
          fullWidth: false,
          onPressed: _trabajando ? null : () => Navigator.of(context).pop(),
        ),
        SButton(
          label: 'Guardar',
          fullWidth: false,
          loading: _trabajando,
          loadingLabel: 'Guardando…',
          onPressed: _trabajando ? null : _guardar,
        ),
      ],
      children: [
        STextField(
          controller: _texto,
          hint: 'Qué pasó con este prospecto…',
          size: STextFieldSize.md,
          maxLines: 6,
          autofocus: true,
          enabled: !_trabajando,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: t.space.sm),

        // Archivos que la nota ya traía: se conservan al guardar.
        if (widget.adjuntosExistentes.isNotEmpty) ...[
          const SFieldLabel('Archivos de la nota'),
          Wrap(
            spacing: t.space.xs,
            runSpacing: t.space.xs,
            children: [
              for (final a in widget.adjuntosExistentes)
                SBadge(
                  label: a.esImagen ? 'Imagen' : a.nombre,
                  icon: a.esImagen
                      ? Icons.image_outlined
                      : Icons.attach_file_outlined,
                  size: SBadgeSize.sm,
                ),
            ],
          ),
          SizedBox(height: t.space.xxs),
          Text(
            'Se conservan tal cual. Para quitarlos, borra la nota y escribe otra.',
            style: t.text.caption.copyWith(color: tone.fgSubtle),
          ),
          SizedBox(height: t.space.sm),
        ],

        if (!_esEdicion) ...[
          if (_nuevos.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: t.space.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final a in _nuevos)
                    Padding(
                      padding: EdgeInsets.only(bottom: t.space.xxs),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file_outlined,
                            size: 16,
                            color: tone.fgMuted,
                          ),
                          SizedBox(width: t.space.xxs),
                          Expanded(
                            child: Text(
                              a.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.text.caption.copyWith(color: tone.fg),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Quitar',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 16),
                            color: tone.fgMuted,
                            onPressed: _trabajando
                                ? null
                                : () => setState(() => _nuevos.remove(a)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          SButton.secondary(
            label: 'Adjuntar archivo',
            icon: Icons.attach_file_outlined,
            fullWidth: false,
            onPressed: _trabajando ? null : _adjuntar,
          ),
        ],

        if (_error != null) ...[
          SizedBox(height: t.space.sm),
          Text(_error!, style: t.text.caption.copyWith(color: tone.danger)),
        ],
      ],
    );
  }
}

/// Tipo de contenido por extensión. El servidor lo usa para decidir si el
/// adjunto se pega como imagen o como enlace.
String _tipoDeContenido(String nombre) =>
    switch (nombre.split('.').last.toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'application/octet-stream',
    };
