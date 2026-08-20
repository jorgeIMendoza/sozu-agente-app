import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/core/portal_theme.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/features/app_download/components/app_download.dart';
import 'package:sozu_agente_app/features/agente/home/components/modo_presentacion_boton.dart';
import 'package:sozu_agente_app/features/agente/home/components/notification_bell.dart';
// Botón "Referir" oculto por ahora (a petición); restaurar junto con su uso.
// import 'package:sozu_agente_app/features/agente/perfil/perfil_screen.dart';

/// Encabezado de sección: título + campana con contador de no leídas.
///
/// Con [vista] el nombre sale del catálogo de la BD, igual que el título del
/// topbar de escritorio: así un renombre en Administrar Menús cambia los dos y
/// el móvil no acaba diciendo "Pipeline" mientras el menú dice "Negocios".
///
/// Se pide la vista y no se deduce de la ruta a propósito: leerla del router
/// obligaría a montar un `GoRouter` para probar cualquier pantalla.
class PortalTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;

  /// Vista de la BD ([VistaAgente]) de la que sale el nombre cuando no hay
  /// [title].
  final String? vista;

  const PortalTopBar({super.key, this.title, this.vista});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // En modo portal (web ≥1024px) el shell ya pinta el título de la sección
    // y la campana en su topbar: este AppBar se colapsa para no duplicarse
    // (Scaffold usa la altura real del appBar, no preferredSize).
    if (isPortalMode(context)) return const SizedBox.shrink();
    final titulo = title ?? _nombreDeVista(ref, vista);
    return AppBar(
      title: Text(titulo),
      // Botón "Referir" oculto por ahora (a petición). Restaurar:
      //   Padding(padding: EdgeInsets.symmetric(vertical: 8),
      //           child: ReferralButton()),
      //   SizedBox(width: 4),
      actions: [
        // "Descargar app" solo en web (móvil): lleva a la tienda por SO.
        if (kIsWeb)
          IconButton(
            tooltip: 'Descargar app',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => openAppStore(context),
          ),
        // Modo presentación en TODAS las secciones, como la píldora del header
        // web: si vive dentro de cada pantalla, en las que no lo montan (p. ej.
        // Inventario) el agente se queda sin interruptor.
        const ModoPresentacionBoton(),
        const NotificationBell(),
      ],
    );
  }
}

/// Nombre del tab en la BD, con el catálogo de respaldo si aún no llega o si la
/// vista no está listada.
String _nombreDeVista(WidgetRef ref, String? vista) {
  if (vista == null) return '';
  for (final catalogo in [
    ref.watch(catalogoTabsProvider),
    tabsAgenteRespaldo,
  ]) {
    for (final tab in catalogo) {
      if (tab.ruta == vista) return tab.nombre;
    }
  }
  return '';
}
