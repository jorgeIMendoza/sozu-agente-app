import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/ui/ui.dart';

/// Envoltorio de una subvista del Perfil (cuenta, identidad, fiscal, banco,
/// capacitación): ancho acotado, scroll, encabezado y el camino de vuelta.
///
/// Las subvistas son rutas propias del router, así que traen su propio `Scaffold`
/// con la barra superior; el shell del portal solo pinta el fondo.
class PerfilSubvista extends StatelessWidget {
  final String titulo;

  /// Qué es esta pantalla, en una línea. Null la omite.
  final String? descripcion;

  /// Acción a la derecha de la barra superior (p. ej. "Agregar cuenta").
  final Widget? accion;

  final List<Widget> children;

  const PerfilSubvista({
    super.key,
    required this.titulo,
    required this.children,
    this.descripcion,
    this.accion,
  });

  void _volver(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      // Entrada directa por URL (web): no hay pila que desapilar.
      context.go('/perfil');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver al Perfil',
          onPressed: () => _volver(context),
        ),
        actions: [
          if (accion != null)
            Padding(
              padding: EdgeInsets.only(right: t.space.sm),
              child: accion,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                t.space.md,
                t.space.sm,
                t.space.md,
                t.space.xxl,
              ),
              children: [
                if (descripcion != null) ...[
                  Text(
                    descripcion!,
                    style: t.text.bodySmall.copyWith(
                      color: t.color.fgMuted,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: t.space.md),
                ],
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Esqueleto de una subvista mientras carga el perfil. Con la forma de lo que va
/// a llegar: una tarjeta con encabezado y filas, para que el layout no salte.
class PerfilSubvistaCargando extends StatelessWidget {
  const PerfilSubvistaCargando({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SSkeleton(width: 140, height: 12),
          SizedBox(height: t.space.md),
          const SSkeleton.text(lines: 5),
        ],
      ),
    );
  }
}
