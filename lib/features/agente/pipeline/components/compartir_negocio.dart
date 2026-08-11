import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compartir y abrir el link del cliente de una oferta.
///
/// Vive en `components/` y no en `services/` porque necesita el contexto para
/// avisar cuando el sistema no puede abrir nada (en web sin permiso de ventanas
/// emergentes es lo más común).

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

/// Copia el link al portapapeles.
Future<void> copiarLink(BuildContext context, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) _avisar(context, 'Link copiado.');
}

void _avisar(BuildContext context, String mensaje) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(mensaje)));
}
