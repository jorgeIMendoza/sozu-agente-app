import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sozu_agente_app/core/file_download.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/pipeline_modal.dart';
import 'package:sozu_agente_app/features/agente/pipeline/providers/pipeline_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/whatsapp_icon.dart';

/// Compartir y abrir el link del cliente de una oferta.
///
/// Vive en `components/` y no en `services/` porque necesita el contexto para
/// avisar cuando el sistema no puede abrir nada (en web sin permiso de ventanas
/// emergentes es lo más común).

/// `personas.clave_pais_telefono` guarda el ISO del país ("MX"), no la lada.
/// Mismo mapa que el portal web (`ShareDigitalOfferDialog.tsx`).
const Map<String, String> _ladaPorIso = {
  'MX': '52',
  'US': '1',
  'CA': '1',
  'ES': '34',
  'AR': '54',
  'CO': '57',
  'PE': '51',
  'CL': '56',
};

/// Lada a partir de la clave de país. Un dato legacy ya numérico se respeta.
String ladaDeClavePais(String? clave) {
  final t = (clave ?? '').trim();
  if (t.isEmpty) return '52';
  if (RegExp(r'^\d+$').hasMatch(t)) return t;
  return _ladaPorIso[t.toUpperCase()] ?? '52';
}

/// Canales de compartir la oferta, los cuatro del portal web: WhatsApp, correo
/// enviado DESDE la plataforma, copiar el link y descargar el PDF.
///
/// [idOferta] es lo que habilita los dos canales que necesitan servidor
/// (`enviar_oferta_email` y `pdf_oferta`); los de link puro no lo usan.
Future<void> mostrarCompartirOferta(
  BuildContext context, {
  required int idOferta,
  required String titulo,
  required String urlCliente,
  required String urlPreview,
  required String mensaje,
  String? telefono,
  String? clavePais,
  String? email,
}) {
  return mostrarHojaPipeline<void>(
    context,
    _CompartirOfertaHoja(
      idOferta: idOferta,
      titulo: titulo,
      urlCliente: urlCliente,
      urlPreview: urlPreview,
      mensaje: mensaje,
      telefono: telefono,
      clavePais: clavePais,
      email: email,
    ),
  );
}

class _CompartirOfertaHoja extends ConsumerStatefulWidget {
  final int idOferta;
  final String titulo;
  final String urlCliente;
  final String urlPreview;
  final String mensaje;
  final String? telefono;
  final String? clavePais;
  final String? email;

  const _CompartirOfertaHoja({
    required this.idOferta,
    required this.titulo,
    required this.urlCliente,
    required this.urlPreview,
    required this.mensaje,
    this.telefono,
    this.clavePais,
    this.email,
  });

  @override
  ConsumerState<_CompartirOfertaHoja> createState() =>
      _CompartirOfertaHojaState();
}

class _CompartirOfertaHojaState extends ConsumerState<_CompartirOfertaHoja> {
  late final TextEditingController _correo = TextEditingController(
    text: (widget.email ?? '').trim(),
  );

  /// Apagado por omisión, igual que la web: el correo lleva el link y generar
  /// el PDF cuesta, así que solo se adjunta si el agente lo pide.
  bool _adjuntarPdf = false;

  bool _enviando = false;
  bool _generandoPdf = false;

  /// Fallo de la última acción con servidor. Se pinta DENTRO de la hoja: un
  /// toast se va antes de que el agente lo lea y la hoja no se cierra al fallar.
  String? _error;

  /// Confirmación de la última acción con servidor.
  String? _aviso;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  bool get _ocupado => _enviando || _generandoPdf;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final hayCliente = widget.urlCliente.isNotEmpty;
    final hayPreview =
        widget.urlPreview.isNotEmpty && widget.urlPreview != widget.urlCliente;

    return HojaPipeline(
      icono: Icons.ios_share_outlined,
      titulo: 'Compartir la oferta',
      subtitulo: widget.titulo,
      cuerpo: [
        Text(
          hayCliente
              ? 'El link del cliente es el que permite apartar: mándalo solo a '
                    'tu prospecto.'
              : 'Esta oferta todavía no tiene link de cliente: lo que se '
                    'comparte es la vista previa y no permite apartar.',
          style: t.text.caption.copyWith(color: tone.fgMuted),
        ),
        SizedBox(height: t.space.sm),
        BotonWhatsApp(
          onPressed: () => compartirPorWhatsApp(
            context,
            mensaje: widget.mensaje,
            telefono: widget.telefono,
            clavePais: widget.clavePais,
          ),
        ),
        SizedBox(height: t.space.xs),
        SButton.secondary(
          label: 'Copiar el link del cliente',
          icon: Icons.copy_outlined,
          onPressed: hayCliente
              ? () => copiarLink(context, widget.urlCliente)
              : null,
        ),
        if (hayPreview) ...[
          SizedBox(height: t.space.xs),
          SButton.secondary(
            label: 'Copiar el link de vista previa',
            icon: Icons.visibility_outlined,
            onPressed: () => copiarLink(
              context,
              widget.urlPreview,
              aviso:
                  'Link de vista previa copiado. Sirve para mostrar la '
                  'oferta, no para apartar.',
            ),
          ),
        ],
        SizedBox(height: t.space.xs),
        SButton.secondary(
          label: 'Abrir en el navegador',
          icon: Icons.open_in_new,
          onPressed: () => abrirLinkCliente(
            context,
            hayCliente ? widget.urlCliente : widget.urlPreview,
          ),
        ),
        SizedBox(height: t.space.xs),
        SButton.secondary(
          label: 'Descargar el PDF de la oferta',
          icon: Icons.download_outlined,
          loading: _generandoPdf,
          loadingLabel: 'Generando el PDF...',
          onPressed: _ocupado ? null : _descargarPdf,
        ),
        SizedBox(height: t.space.md),
        const SSectionLabel(text: 'Enviar por correo'),
        SizedBox(height: t.space.xs),
        STextField(
          controller: _correo,
          label: 'Correo del prospecto',
          hint: 'prospecto@dominio.com',
          size: STextFieldSize.md,
          enabled: !_ocupado,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) {
            if (_error != null || _aviso != null) {
              setState(() {
                _error = null;
                _aviso = null;
              });
            }
          },
        ),
        Row(
          children: [
            Checkbox(
              value: _adjuntarPdf,
              onChanged: _ocupado
                  ? null
                  : (v) => setState(() => _adjuntarPdf = v ?? false),
            ),
            Expanded(
              child: Text(
                'Adjuntar el PDF de la oferta',
                style: t.text.caption.copyWith(color: tone.fgMuted),
              ),
            ),
          ],
        ),
        SButton(
          label: 'Enviar desde la plataforma',
          icon: Icons.send_outlined,
          loading: _enviando,
          loadingLabel: 'Enviando el correo...',
          onPressed: _ocupado ? null : _enviarCorreo,
        ),
        SizedBox(height: t.space.xs),
        SButton.ghost(
          label: 'Abrir mi app de correo',
          icon: Icons.mail_outline,
          fullWidth: true,
          onPressed: () => compartirPorCorreo(
            context,
            asunto: widget.titulo,
            cuerpo: widget.mensaje,
            email: _correo.text,
          ),
        ),
        SButton.ghost(
          label: 'Más opciones del sistema',
          icon: Icons.more_horiz,
          fullWidth: true,
          onPressed: () => compartirLinkCliente(
            context,
            url: hayCliente ? widget.urlCliente : widget.urlPreview,
            titulo: widget.titulo,
          ),
        ),
        if (_error != null) ...[
          SizedBox(height: t.space.xs),
          Text(_error!, style: t.text.bodySmall.copyWith(color: tone.danger)),
        ],
        if (_aviso != null) ...[
          SizedBox(height: t.space.xs),
          Text(_aviso!, style: t.text.bodySmall.copyWith(color: tone.positive)),
        ],
      ],
      nota:
          'El correo sale de la plataforma con el link de la oferta. El PDF se '
          'genera al momento y su enlace caduca en un minuto, así que se '
          'entrega en el acto.',
    );
  }

  /// Envía la oferta por correo desde la plataforma.
  ///
  /// El `@` se exige aquí igual que en el servidor, para no gastar una llamada
  /// que va a volver como `email_invalido`.
  Future<void> _enviarCorreo() async {
    final destino = _correo.text.trim();
    if (!destino.contains('@')) {
      setState(() {
        _error =
            'Captura el correo del prospecto: hace falta un correo completo '
            'para poder enviarlo.';
        _aviso = null;
      });
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
      _aviso = null;
    });
    try {
      final envio = await ref
          .read(pipelineAccionesProvider)
          .enviarPorCorreo(
            idOferta: widget.idOferta,
            email: destino,
            adjuntarPdf: _adjuntarPdf,
          );
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _aviso = envio.conPdf
            ? 'Oferta enviada por correo, con el PDF adjunto.'
            : 'Oferta enviada por correo.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = mensajeDeError(e);
      });
    }
  }

  /// Pide el PDF y lo entrega en el acto.
  ///
  /// El enlace muere al minuto, así que no se guarda en el estado ni se ofrece
  /// para compartir: en web `downloadFile` lo baja con su nombre y en móvil lo
  /// abre en el visor del sistema, desde donde el agente lo guarda.
  Future<void> _descargarPdf() async {
    setState(() {
      _generandoPdf = true;
      _error = null;
      _aviso = null;
    });
    try {
      final pdf = await ref
          .read(pipelineAccionesProvider)
          .pdfDeOferta(widget.idOferta);
      final entregado = await downloadFile(pdf.url, pdf.nombreArchivo);
      if (!mounted) return;
      setState(() {
        _generandoPdf = false;
        _aviso = entregado
            ? 'PDF listo: se descarga o se abre en el visor del sistema.'
            : null;
        _error = entregado
            ? null
            : 'El PDF se generó pero el sistema no pudo abrirlo. Vuelve a '
                  'intentarlo: el enlace caduca al minuto.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generandoPdf = false;
        _error = mensajeDeError(e);
      });
    }
  }
}

/// Abre el cliente de correo del dispositivo con el asunto y el cuerpo listos.
///
/// Sin [email] abre el redactor sin destinatario, para que el agente lo elija.
/// Convive con el envío desde la plataforma: es la única vía para escribir un
/// cuerpo propio, copiar a alguien más o mandar la oferta cuando el envío del
/// servidor se cae.
Future<void> compartirPorCorreo(
  BuildContext context, {
  required String asunto,
  required String cuerpo,
  String? email,
}) async {
  final destino = Uri(
    scheme: 'mailto',
    path: (email ?? '').trim(),
    queryParameters: {'subject': asunto, 'body': cuerpo},
  );
  final abrio = await launchUrl(destino, mode: LaunchMode.externalApplication);
  if (!abrio && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No pudimos abrir tu app de correo.')),
    );
  }
}

/// Abre WhatsApp con el mensaje ya escrito. Sin teléfono abre el selector de
/// contacto de WhatsApp, igual que la web: el agente elige a quién mandarlo.
Future<void> compartirPorWhatsApp(
  BuildContext context, {
  required String mensaje,
  String? telefono,
  String? clavePais,
}) async {
  final digitos = (telefono ?? '').replaceAll(RegExp(r'\D'), '');
  final destino = digitos.isEmpty
      ? ''
      : '${ladaDeClavePais(clavePais)}$digitos';
  final uri = Uri.parse(
    'https://wa.me/$destino?text=${Uri.encodeComponent(mensaje)}',
  );
  final ok = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  if (!ok && context.mounted) _avisar(context, 'No se pudo abrir WhatsApp.');
}

/// Abre la hoja de compartir del sistema con el link del cliente.
Future<void> compartirLinkCliente(
  BuildContext context, {
  required String url,
  required String titulo,
}) async {
  if (url.isEmpty) {
    _avisar(context, 'Esta oferta todavía no tiene link para compartir.');
    return;
  }
  try {
    await Share.share('$titulo\n$url', subject: titulo);
  } catch (_) {
    // Plataforma sin hoja de compartir: queda el portapapeles.
    if (context.mounted) await copiarLink(context, url);
  }
}

/// Abre el link en el navegador (pestaña nueva en web).
Future<void> abrirLinkCliente(BuildContext context, String url) async {
  if (url.isEmpty) {
    _avisar(context, 'Esta oferta todavía no tiene link.');
    return;
  }
  final uri = Uri.tryParse(url);
  if (uri == null) {
    _avisar(context, 'El link de la oferta no es válido.');
    return;
  }
  final ok = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  if (!ok && context.mounted) _avisar(context, 'No se pudo abrir el link.');
}

/// Copia el link al portapapeles. [aviso] distingue el link del cliente del de
/// vista previa: los dos se copian igual y solo uno permite apartar.
Future<void> copiarLink(
  BuildContext context,
  String url, {
  String aviso = 'Link copiado.',
}) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) _avisar(context, aviso);
}

/// Botón de WhatsApp con el glifo de marca.
///
/// No es un `SButton` porque el primitivo solo acepta `IconData` y el logo es un
/// [WhatsAppIcon] pintado con `CustomPaint`.
class BotonWhatsApp extends StatelessWidget {
  final VoidCallback onPressed;

  const BotonWhatsApp({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return SPressable(
      onTap: onPressed,
      borderRadius: t.radius.mdBorder,
      semanticLabel: 'Compartir por WhatsApp',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.sm,
        ),
        decoration: BoxDecoration(
          color: kWhatsAppGreen,
          borderRadius: t.radius.mdBorder,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const WhatsAppIcon(color: Colors.white),
            SizedBox(width: t.space.xs),
            Flexible(
              child: Text(
                'WhatsApp',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.text.button.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _avisar(BuildContext context, String mensaje) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
}
