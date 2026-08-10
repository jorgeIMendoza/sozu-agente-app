import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/portal_theme.dart';
import 'package:sozu_agente_app/features/agente/layouts/portal_top_bar.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/fx.dart';
import 'package:sozu_agente_app/widgets/portal_widgets.dart';

/// Envoltorio de las pantallas del portal del agente que ya son un destino de
/// ruta pero todavía no tienen datos: pinta el encabezado de la sección y el
/// aviso de "En construcción".
///
/// Vive en `layouts/` porque es estructura compartida por las pantallas de
/// varios dominios (inventario, pipeline, prospectos, comisiones, perfil), igual
/// que `PortalShell`. Se borra cuando ya no la use ninguna pantalla.
class EnConstruccionLayout extends StatelessWidget {
  final String titulo;
  final String? subtitulo;

  /// Aparece bajo el aviso; sirve para dejar visible el contexto que la pantalla
  /// ya recibe por parámetro (ids de proyecto, modelo, prospecto…).
  final String? detalle;

  const EnConstruccionLayout({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final aviso = SEmptyState.card(
      icon: Icons.construction_outlined,
      title: 'En construcción',
      message: detalle == null
          ? 'Esta sección del portal del agente todavía se está armando.'
          : 'Esta sección del portal del agente todavía se está armando.\n'
                '$detalle',
    );

    // Modo portal (web ≥1024): la topbar y el marco los pinta el shell, aquí
    // solo va el encabezado de página.
    if (isPortalMode(context)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: EdgeInsets.only(top: t.space.lg, bottom: t.space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PortalPageHeader(title: titulo, subtitle: subtitulo),
              SizedBox(height: t.space.lg),
              aviso,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: PortalTopBar(title: titulo),
      body: ContentFrame(
        child: ListView(padding: EdgeInsets.all(t.space.md), children: [aviso]),
      ),
    );
  }
}
