import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/core/open_media.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/nota_html_vista.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/prospecto_modal.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/nota_html.dart';
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

/// Abre una nota propia. Con [soloLectura] se ve completa y con formato (el
/// "Ver detalle" de la web), y desde ahí se puede pasar a editarla o borrarla.
/// Devuelve `true` si cambió algo.
Future<bool?> abrirNota(
  BuildContext context, {
  required int idNota,
  required String texto,
  String html = '',
  List<AdjuntoNota> adjuntos = const [],
  bool soloLectura = false,
}) => mostrarHojaProspecto<bool>(
  context,
  _HojaNota(
    idNota: idNota,
    textoInicial: texto,
    html: html,
    adjuntosExistentes: adjuntos,
    soloLectura: soloLectura,
  ),
);

/// Nota interna: se lee con su formato y se edita como texto plano.
///
/// El editor es de TEXTO PLANO a propósito: no se mete un editor de HTML como
/// dependencia nueva. Lo que sí se respeta es lo ya escrito en el portal web: si
/// el texto no se toca, el contenido con formato se manda de vuelta tal cual, y
/// si se toca, la hoja avisa que se guardará como texto plano.
class _HojaNota extends ConsumerStatefulWidget {
  /// Prospecto al que se le agrega la nota; null cuando se edita una existente.
  final int? idPersona;

  final int? idRelacion;

  /// Nota existente que se está editando; null = nota nueva.
  final int? idNota;

  final String textoInicial;

  /// Contenido con formato de la nota existente, con sus URLs ya firmadas.
  final String html;

  final List<AdjuntoNota> adjuntosExistentes;

  /// Arranca en modo lectura (nota larga abierta desde "Ver detalle").
  final bool soloLectura;

  const _HojaNota({
    this.idPersona,
    this.idRelacion,
    this.idNota,
    this.textoInicial = '',
    this.html = '',
    this.adjuntosExistentes = const [],
    this.soloLectura = false,
  });

  @override
  ConsumerState<_HojaNota> createState() => _HojaNotaState();
}

class _HojaNotaState extends ConsumerState<_HojaNota> {
  late final TextEditingController _texto;

  /// Archivos que la nota conserva. Quitar uno de aquí lo desprende al guardar.
  late final List<AdjuntoNota> _adjuntos;

  final List<AdjuntoNuevo> _nuevos = [];
  late bool _soloLectura;
  bool _trabajando = false;
  String? _error;

  bool get _esEdicion => widget.idNota != null;

  /// El texto ya no es el que traía la nota, así que su formato se reescribe.
  bool get _textoCambio => _texto.text.trim() != widget.textoInicial.trim();

  @override
  void initState() {
    super.initState();
    _texto = TextEditingController(text: widget.textoInicial);
    _adjuntos = List.of(widget.adjuntosExistentes);
    _soloLectura = widget.soloLectura;
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  bool get _hayContenido =>
      _texto.text.trim().isNotEmpty ||
      _nuevos.isNotEmpty ||
      _adjuntos.isNotEmpty;

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
        final cuerpo = cuerpoDeNotaSinAdjuntos(widget.html);
        await port.editarNota(
          idNota: widget.idNota!,
          texto: _texto.text,
          // Sin tocar el texto se devuelve el contenido original: es lo único
          // que conserva negritas, listas y colores escritos en la web.
          cuerpoConFormato: _textoCambio || cuerpo.isEmpty ? null : cuerpo,
          adjuntos: _adjuntos,
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
      titulo: _soloLectura
          ? 'Nota interna'
          : _esEdicion
          ? 'Editar nota'
          : 'Nueva nota',
      subtitulo: 'Nota interna · solo visible para ti',
      acciones: _acciones(),
      children: _soloLectura ? _lectura(t, tone) : _edicion(t, tone),
    );
  }

  List<Widget> _acciones() => _soloLectura
      ? [
          SButton(
            label: 'Eliminar',
            variant: SButtonVariant.danger,
            fullWidth: false,
            onPressed: _trabajando ? null : _borrar,
          ),
          SButton.secondary(
            label: 'Editar',
            fullWidth: false,
            onPressed: _trabajando
                ? null
                : () => setState(() => _soloLectura = false),
          ),
        ]
      : [
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
        ];

  /// Nota completa, con su formato y sus imágenes.
  List<Widget> _lectura(SozuTheme t, SozuColorRoles tone) => [
    Container(
      width: double.infinity,
      padding: EdgeInsets.all(t.space.sm),
      decoration: BoxDecoration(
        color: tone.surfaceAlt,
        borderRadius: t.radius.mdBorder,
        border: Border.all(color: tone.borderSoft),
      ),
      child: NotaHtmlVista(
        html: widget.html,
        textoPlano: widget.textoInicial,
        onVerImagen: (url) => openMedia(context, url, titulo: 'Imagen'),
      ),
    ),
    if (_adjuntos.any((a) => !a.esImagen)) ...[
      SizedBox(height: t.space.sm),
      const SFieldLabel('Archivos de la nota'),
      Wrap(
        spacing: t.space.xs,
        runSpacing: t.space.xs,
        children: [
          for (final a in _adjuntos.where((a) => !a.esImagen))
            SPressable(
              onTap: () => openMedia(context, a.url, titulo: a.nombre),
              borderRadius: t.radius.fullBorder,
              semanticLabel: 'Ver ${a.nombre}',
              child: SBadge(
                label: a.nombre,
                icon: Icons.attach_file_outlined,
                size: SBadgeSize.sm,
              ),
            ),
        ],
      ),
    ],
    if (_error != null) ...[
      SizedBox(height: t.space.sm),
      Text(_error!, style: t.text.caption.copyWith(color: tone.danger)),
    ],
  ];

  List<Widget> _edicion(SozuTheme t, SozuColorRoles tone) => [
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

    // El editor del app es de texto plano: se avisa antes de aplastar el
    // formato que traía la nota, no después.
    if (_esEdicion && _textoCambio && notaTieneFormato(widget.html)) ...[
      SizedBox(height: t.space.xs),
      Container(
        padding: EdgeInsets.all(t.space.sm),
        decoration: BoxDecoration(
          color: tone.warningSoft,
          borderRadius: t.radius.mdBorder,
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, size: 18, color: tone.warningFg),
            SizedBox(width: t.space.xs),
            Expanded(
              child: Text(
                'Esta nota se escribió con formato en el portal web. Al guardar '
                'tu cambio se queda como texto plano.',
                style: t.text.caption.copyWith(color: tone.warningFg),
              ),
            ),
          ],
        ),
      ),
    ],
    SizedBox(height: t.space.sm),

    // Archivos que la nota ya traía: se pueden quitar uno por uno.
    if (_adjuntos.isNotEmpty) ...[
      const SFieldLabel('Archivos de la nota'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in _adjuntos)
            _FilaArchivo(
              nombre: a.esImagen ? 'Imagen' : a.nombre,
              icono: a.esImagen
                  ? Icons.image_outlined
                  : Icons.attach_file_outlined,
              onQuitar: _trabajando
                  ? null
                  : () => setState(() => _adjuntos.remove(a)),
            ),
        ],
      ),
      SizedBox(height: t.space.xxs),
      Text(
        // Agregar archivos al editar necesita que `nota_editar` los reciba, y
        // hoy solo acepta contenido.
        'Los que dejes aquí se conservan. Para agregar otro, escribe una nota '
        'nueva.',
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
                _FilaArchivo(
                  nombre: a.nombre,
                  icono: Icons.attach_file_outlined,
                  onQuitar: _trabajando
                      ? null
                      : () => setState(() => _nuevos.remove(a)),
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
  ];
}

/// Renglón de un archivo de la nota con su botón de quitar.
class _FilaArchivo extends StatelessWidget {
  final String nombre;
  final IconData icono;
  final VoidCallback? onQuitar;

  const _FilaArchivo({
    required this.nombre,
    required this.icono,
    this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.xxs),
      child: Row(
        children: [
          Icon(icono, size: 16, color: tone.fgMuted),
          SizedBox(width: t.space.xxs),
          Expanded(
            child: Text(
              nombre,
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
            onPressed: onQuitar,
          ),
        ],
      ),
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
