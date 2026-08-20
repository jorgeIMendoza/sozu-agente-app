import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/core/portal_theme.dart';
import 'package:sozu_agente_app/features/app_download/components/app_download.dart';
import 'package:sozu_agente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/features/agente/providers/agente_providers.dart';
import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';

/// Iniciales para el avatar: 2 primeras palabras del nombre.
String _initialsOf(String? nombre) {
  final parts = (nombre ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase());
  final s = parts.join();
  return s.isEmpty ? '?' : s;
}

/// Avatar circular con las iniciales del nombre.
class PortalAvatarCircle extends StatelessWidget {
  final String? nombre;
  final double size;

  const PortalAvatarCircle({super.key, required this.nombre, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: PortalColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initialsOf(nombre),
        style: TextStyle(
          fontSize: size <= 32 ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buscador global
// ---------------------------------------------------------------------------

/// Campo de búsqueda de la topbar. Con ≥2 caracteres despliega los atajos que
/// el portal ya tiene ruta para atender.
///
/// La búsqueda de inventario y prospectos se conecta al portar esas pantallas:
/// hasta entonces el dropdown NO ofrece resultados de datos, porque los que
/// traía eran las propiedades compradas por el cliente y su historial de pagos,
/// que en el portal del agente no existen.
class PortalTopBarSearch extends ConsumerStatefulWidget {
  const PortalTopBarSearch({super.key});

  @override
  ConsumerState<PortalTopBarSearch> createState() => _PortalTopBarSearchState();
}

class _PortalTopBarSearchState extends ConsumerState<PortalTopBarSearch> {
  static const double _kWidth = 260;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final LayerLink _link = LayerLink();
  final OverlayPortalController _overlay = OverlayPortalController();

  Timer? _debounce;
  String _query = ''; // valor "debounced" en minúsculas

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _query = value.trim().toLowerCase());
      _syncOverlay();
    });
  }

  void _syncOverlay() {
    if (_query.length >= 2) {
      _overlay.show();
    } else {
      _overlay.hide();
    }
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
    _overlay.hide();
  }

  void _go(String route) {
    _clear();
    _focus.unfocus();
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlay,
      overlayChildBuilder: _buildDropdown,
      child: CompositedTransformTarget(
        link: _link,
        child: SizedBox(
          width: _kWidth,
          height: 32,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            onChanged: _onChanged,
            cursorColor: PortalColors.primary,
            style: const TextStyle(
              fontSize: 13,
              color: PortalColors.foreground,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: PortalColors.mutedHover,
              hintText: 'Buscar en el portal…',
              hintStyle: TextStyle(
                fontSize: 13,
                color: PortalColors.mutedForeground.withValues(alpha: .7),
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 16,
                color: PortalColors.mutedForeground.withValues(alpha: .7),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 34,
                minHeight: 32,
              ),
              contentPadding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kPortalRadiusSm),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kPortalRadiusSm),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kPortalRadiusSm),
                borderSide: const BorderSide(
                  color: PortalColors.primary,
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(BuildContext context) {
    final showDocs = _query.contains('doc') || _query.contains('exped');
    if (!showDocs) return const SizedBox.shrink();

    return Stack(
      children: [
        // Barrera invisible: un tap fuera cierra el dropdown.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _overlay.hide(),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: _kWidth,
                decoration: BoxDecoration(
                  color: PortalColors.surface,
                  border: Border.all(color: PortalColors.border, width: 1),
                  borderRadius: BorderRadius.circular(kPortalRadiusLg),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchResultRow(
                      onTap: () => _go('/perfil/expediente'),
                      child: const Text(
                        'Mi expediente',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: PortalColors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila del dropdown de búsqueda, con hover suave.
class _SearchResultRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _SearchResultRow({required this.child, required this.onTap});

  @override
  State<_SearchResultRow> createState() => _SearchResultRowState();
}

class _SearchResultRowState extends State<_SearchResultRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHover: (h) => setState(() => _hover = h),
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        color: _hover ? PortalColors.mutedHover : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Popover del avatar
// ---------------------------------------------------------------------------

/// Avatar de la topbar con popover: nombre, rol, "Ver perfil" y "Cerrar sesión".
///
/// Nombre y rol salen de `sesionProvider`, que ya los trae y los trae del agente
/// EFECTIVO: cuando un admin impersona, el encabezado muestra a quién se está
/// revisando y no al admin.
class PortalTopBarAvatarMenu extends ConsumerStatefulWidget {
  const PortalTopBarAvatarMenu({super.key});

  @override
  ConsumerState<PortalTopBarAvatarMenu> createState() =>
      _PortalTopBarAvatarMenuState();
}

class _PortalTopBarAvatarMenuState
    extends ConsumerState<PortalTopBarAvatarMenu> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _overlay = OverlayPortalController();

  Future<void> _confirmarSalir() async {
    _overlay.hide();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: PortalColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Con biometría activa solo bloquea; si no, cierra sesión de verdad.
    await ref.read(authProvider).lockOrSignOut();
    ref.read(impersonationProvider).clear();
    invalidateAllData(ref);
    if (mounted) context.go('/login');
  }

  /// Nombre del agente efectivo; cae al del usuario logueado mientras la sesión
  /// del portal no resuelve.
  String _nombre() {
    final header = ref.watch(sesionProvider).valueOrNull?.header.nombre?.trim();
    if (header != null && header.isNotEmpty) return header;
    final auth = ref.watch(authProvider);
    return auth.profile?.displayName ?? auth.profile?.email ?? 'Usuario';
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlay,
      overlayChildBuilder: _buildPopover,
      child: CompositedTransformTarget(
        link: _link,
        child: InkWell(
          onTap: _overlay.toggle,
          borderRadius: BorderRadius.circular(999),
          child: PortalAvatarCircle(nombre: _nombre(), size: 32),
        ),
      ),
    );
  }

  Widget _buildPopover(BuildContext context) {
    final nombre = _nombre();
    final rol =
        ref.watch(sesionProvider).valueOrNull?.header.rol ??
        ref.watch(authProvider).profile?.roleName ??
        'Agente';

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _overlay.hide(),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: Align(
            alignment: Alignment.topRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 240,
                decoration: BoxDecoration(
                  color: PortalColors.surface,
                  border: Border.all(color: PortalColors.border, width: 1),
                  borderRadius: BorderRadius.circular(kPortalRadiusLg),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Encabezado: avatar + nombre + rol + teléfono.
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: const BoxDecoration(
                        color: PortalColors.mutedSoft30,
                        border: Border(
                          bottom: BorderSide(
                            color: PortalColors.borderSoft,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PortalAvatarCircle(nombre: nombre, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: PortalColors.foreground,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  rol,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: PortalColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Acciones.
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AvatarMenuItem(
                            icon: Icons.person_outline,
                            label: 'Ver perfil',
                            onTap: () {
                              _overlay.hide();
                              context.go('/perfil');
                            },
                          ),
                          // "Descargar app" solo en web: en nativo no aplica.
                          if (kIsWeb)
                            _AvatarMenuItem(
                              icon: Icons.qr_code,
                              label: 'Descargar app',
                              onTap: () {
                                _overlay.hide();
                                showAppDownloadDialog(context);
                              },
                            ),
                          _AvatarMenuItem(
                            icon: Icons.logout,
                            label: 'Cerrar sesión',
                            destructive: true,
                            onTap: _confirmarSalir,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ítem del popover del avatar ("Ver perfil" / "Cerrar sesión").
class _AvatarMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const _AvatarMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  State<_AvatarMenuItem> createState() => _AvatarMenuItemState();
}

class _AvatarMenuItemState extends State<_AvatarMenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.destructive
        ? PortalColors.destructive
        : PortalColors.foreground;
    final Color bg = !_hover
        ? Colors.transparent
        : widget.destructive
        ? PortalColors.destructiveSoft10
        : PortalColors.mutedHover;

    return InkWell(
      onTap: widget.onTap,
      onHover: (h) => setState(() => _hover = h),
      borderRadius: BorderRadius.circular(kPortalRadiusSm),
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kPortalRadiusSm),
        ),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 16,
              color: widget.destructive
                  ? PortalColors.destructive
                  : PortalColors.mutedForeground,
            ),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
