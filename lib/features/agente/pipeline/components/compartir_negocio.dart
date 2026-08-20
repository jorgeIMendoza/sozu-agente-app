import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sozu_agente_app/features/agente/pipeline/components/pipeline_modal.dart';
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

/// Canales de compartir que el app puede abrir hoy.
///
/// El correo con el PDF adjunto y la descarga del PDF NO están: los arma el
/// portal web con su generador. El pie de la hoja lo dice, para que el agente no
/// los busque aquí.
Future<void> mostrarCompartirOferta(
  BuildContext context, {
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

class _CompartirOfertaHoja extends StatelessWidget {
  final String titulo;
  final String urlCliente;
  final String urlPreview;
  final String mensaje;
  final String? telefono;
  final String? clavePais;
  final String? email;

  const _CompartirOfertaHoja({
    required this.titulo,
    required this.urlCliente,
    required this.urlPreview,
    required this.mensaje,
    this.telefono,
    this.clavePais,
    this.email,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final hayCliente = urlCliente.isNotEmpty;
    final hayPreview = urlPreview.isNotEmpty && urlPreview != urlCliente;

    return HojaPipeline(
      icono: Icons.ios_share_outlined,
      titulo: 'Compartir la oferta',
      subtitulo: titulo,
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
            mensaje: mensaje,
            telefono: telefono,
            clavePais: clavePais,
          ),
        ),
        SizedBox(height: t.space.xs),
        SButton.secondary(
          label: 'Copiar el link del cliente',
          icon: Icons.copy_outlined,
          onPressed: hayCliente ? () => copiarLink(context, urlCliente) : null,
        ),
        if (hayPreview) ...[
          SizedBox(height: t.space.xs),
          SButton.secondary(
            label: 'Copiar el link de vista previa',
            icon: Icons.visibility_outlined,
            onPressed: () => copiarLink(
              context,
              urlPreview,
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
          onPressed: () =>
              abrirLinkCliente(context, hayCliente ? urlCliente : urlPreview),
        ),
        SizedBox(height: t.space.xs),
        // Respaldo de correo: abre el cliente de correo del dispositivo con
        // el asunto y el cuerpo ya escritos. NO es el envío desde la
        // plataforma (eso necesita backend y no existe todavía), pero es lo
        // que la web usa cuando no puede mandarlo ella, así que el canal
        // deja de estar ausente.
        SButton.secondary(
          label: 'Correo',
          icon: Icons.mail_outline,
          fullWidth: true,
          onPressed: () => compartirPorCorreo(
            context,
            asunto: titulo,
            cuerpo: mensaje,
            email: email,
          ),
        ),
        SButton.ghost(
          label: 'Más opciones del sistema',
          icon: Icons.more_horiz,
          fullWidth: true,
          onPressed: () => compartirLinkCliente(
            context,
            url: hayCliente ? urlCliente : urlPreview,
            titulo: titulo,
          ),
        ),
      ],
      nota:
          'El correo se abre en tu app de correo. Mandarlo desde la '
          'plataforma y descargar el PDF de la oferta todavía se hacen desde '
          'el portal web.',
    );
  }
}

/// Abre el cliente de correo del dispositivo con el asunto y el cuerpo listos.
///
/// Sin [email] abre el redactor sin destinatario, para que el agente lo elija.
/// Es el respaldo que usa la web cuando no puede enviar desde la plataforma.
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
