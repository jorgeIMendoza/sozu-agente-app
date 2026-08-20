import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sozu_agente_app/ui/ui.dart';

/// Presenta una hoja del Perfil: diálogo centrado en pantalla ancha, hoja de
/// pantalla completa en teléfono. Reusa el envoltorio del design system para que
/// todas las hojas de la app se abran igual (incluido `Esc` en escritorio).
Future<T?> mostrarHojaDePerfil<T>(
  BuildContext context, {
  required Widget child,
  double anchoMaximo = 560,
}) => showSDocModal<T>(context, child: child, maxWidth: anchoMaximo);

/// Estructura de una hoja del Perfil: encabezado, contenido con scroll y las
/// acciones pegadas abajo.
///
/// El contenido va en un scroll propio porque en teléfono el teclado se come la
/// mitad de la pantalla y un formulario de seis campos deja de caber.
class HojaDePerfil extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget contenido;

  /// Botones de la hoja, de izquierda a derecha.
  final List<Widget> acciones;

  const HojaDePerfil({
    super.key,
    required this.titulo,
    required this.contenido,
    this.subtitulo,
    this.acciones = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.space.lg,
            t.space.lg,
            t.space.sm,
            t.space.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: t.text.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tone.fg,
                      ),
                    ),
                    if (subtitulo != null) ...[
                      SizedBox(height: t.space.xxs),
                      Text(
                        subtitulo!,
                        style: t.text.caption.copyWith(
                          color: tone.fgMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Cerrar',
              ),
            ],
          ),
        ),
        Divider(height: 1, color: tone.borderSoft),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(t.space.lg),
            child: contenido,
          ),
        ),
        if (acciones.isNotEmpty) ...[
          Divider(height: 1, color: tone.borderSoft),
          Padding(
            padding: EdgeInsets.all(t.space.md),
            // Wrap y no Row: dos etiquetas largas no caben en el ancho de un
            // teléfono y un `Row` las desborda en vez de bajar la segunda.
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: t.space.xs,
              runSpacing: t.space.xs,
              children: acciones,
            ),
          ),
        ],
      ],
    );
  }
}

/// Fuerza mayúsculas mientras se escribe. Lo usan el CURP y el RFC, que se
/// guardan en mayúsculas: así el agente ve exactamente lo que se va a mandar.
class MayusculasAlEscribir extends TextInputFormatter {
  const MayusculasAlEscribir();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) => TextEditingValue(
    text: nuevo.text.toUpperCase(),
    selection: nuevo.selection,
    composing: TextRange.empty,
  );
}
