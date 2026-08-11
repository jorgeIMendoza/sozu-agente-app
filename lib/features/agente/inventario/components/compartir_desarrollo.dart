import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sozu_agente_app/features/agente/inventario/components/hoja_inventario.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Compartir un desarrollo con el cliente: su ficha pública en sozu.com.
///
/// Es la única salida del inventario hacia afuera del app, y siempre comparte la
/// URL PÚBLICA: nunca una URL firmada del portal, que caduca y además está
/// emitida a nombre del agente.
Future<void> mostrarCompartirDesarrollo(
  BuildContext context, {
  required String nombre,
  required String urlPublica,
  String? ubicacion,
}) {
  final mensaje = [
    nombre,
    if ((ubicacion ?? '').trim().isNotEmpty) ubicacion!.trim(),
    urlPublica,
  ].join('\n');

  return mostrarHojaInventario<void>(
    context,
    titulo: 'Compartir',
    subtitulo: nombre,
    cuerpo: (ctx) => _OpcionesCompartir(
      nombre: nombre,
      urlPublica: urlPublica,
      mensaje: mensaje,
    ),
  );
}

class _OpcionesCompartir extends StatelessWidget {
  final String nombre;
  final String urlPublica;
  final String mensaje;

  const _OpcionesCompartir({
    required this.nombre,
    required this.urlPublica,
    required this.mensaje,
  });

  /// Abre una liga externa y cierra la hoja. El `messenger` y el `navigator` se
  /// toman ANTES del await: después de él este contexto puede estar desmontado.
  Future<void> _abrir(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (navigator.canPop()) navigator.pop();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No pudimos abrir el enlace.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SButton(
          label: 'Ver página web',
          icon: Icons.public,
          isNavigation: true,
          onPressed: () => _abrir(context, Uri.parse(urlPublica)),
        ),
        SizedBox(height: t.space.xs),
        SButton.secondary(
          label: 'Enviar por WhatsApp',
          icon: Icons.chat_outlined,
          onPressed: () => _abrir(
            context,
            Uri.parse('https://wa.me/?text=${Uri.encodeComponent(mensaje)}'),
          ),
        ),
        SizedBox(height: t.space.xs),
        Row(
          children: [
            Expanded(
              child: SButton.secondary(
                label: 'Compartir',
                icon: Icons.ios_share,
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await Share.share(mensaje, subject: nombre);
                  if (navigator.canPop()) navigator.pop();
                },
              ),
            ),
            SizedBox(width: t.space.xs),
            Expanded(
              child: SButton.secondary(
                label: 'Copiar liga',
                icon: Icons.link,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  await Clipboard.setData(ClipboardData(text: urlPublica));
                  if (navigator.canPop()) navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Liga copiada al portapapeles.'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: t.space.sm),
        Text(
          'El cliente recibe la ficha pública del desarrollo, sin datos internos '
          'del portal.',
          style: t.text.caption.copyWith(color: t.color.fgMuted),
        ),
      ],
    );
  }
}
