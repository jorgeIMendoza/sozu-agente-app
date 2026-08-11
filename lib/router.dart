import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/core/portal_theme.dart';
import 'package:sozu_agente_app/core/version.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/admin/screens/announcements_screen.dart';
import 'package:sozu_agente_app/features/auth/screens/change_password_screen.dart';
import 'package:sozu_agente_app/features/agente/comisiones/screens/comisiones_screen.dart';
import 'package:sozu_agente_app/features/agente/perfil/screens/perfil_expediente_screen.dart';
import 'package:sozu_agente_app/features/auth/screens/confirmacion_email_screen.dart';
import 'package:sozu_agente_app/features/auth/screens/email_not_confirmed_screen.dart';
import 'package:sozu_agente_app/features/auth/screens/forgot_password_screen.dart';
import 'package:sozu_agente_app/features/agente/home/screens/inicio_screen.dart';
import 'package:sozu_agente_app/features/agente/inventario/screens/inventario_screen.dart';
import 'package:sozu_agente_app/features/agente/inventario/screens/proyecto_detalle_screen.dart';
import 'package:sozu_agente_app/features/agente/inventario/screens/unidades_screen.dart';
import 'package:sozu_agente_app/features/auth/screens/login_screen.dart';
import 'package:sozu_agente_app/features/agente/home/screens/notificaciones_screen.dart';
import 'package:sozu_agente_app/features/agente/perfil/screens/perfil_capacitacion_screen.dart';
import 'package:sozu_agente_app/features/agente/perfil/screens/perfil_cuenta_screen.dart';
import 'package:sozu_agente_app/features/agente/perfil/screens/perfil_detalle_screens.dart';
import 'package:sozu_agente_app/features/agente/perfil/screens/perfil_screen.dart';
import 'package:sozu_agente_app/features/agente/pipeline/screens/pipeline_screen.dart';
import 'package:sozu_agente_app/features/agente/prospectos/screens/prospecto_detalle_screen.dart';
import 'package:sozu_agente_app/features/agente/prospectos/screens/prospectos_screen.dart';
import 'package:sozu_agente_app/features/admin/screens/select_agente_screen.dart';
import 'package:sozu_agente_app/widgets/fx.dart';
import 'package:sozu_agente_app/features/agente/home/components/notificaciones_fx.dart';
import 'package:sozu_agente_app/features/agente/layouts/portal_shell.dart';

/// Página secundaria con la transición del design system
/// ([sozuPageTransition]: fade + escala en escritorio, fade + deslizamiento en
/// móvil) y contenido responsive (WebFrame) para web/desktop.
///
/// Recibe el [context] del `pageBuilder` porque duración y curva salen de
/// `context.s.motion` y la forma de la transición del breakpoint: sin contexto no
/// hay tokens y volveríamos a los milisegundos cocidos.
///
/// [portalFullWidth]: pantallas con layout de portal propio (p.ej. estado de
/// cuenta) no se limitan a los 900px del WebFrame en modo portal - el shell
/// ya acota el contenido a 1280px; fuera del portal se comportan igual que
/// siempre.
///
/// [sinMarco]: pantallas que ocupan el viewport completo y traen su propio
/// layout responsive (las de acceso). El WebFrame les hacía daño: las metía en
/// una caja de 900 px pintada con `scaffoldBackgroundColor`, que en tema
/// oscuro es `slate900` - de ahí el marco navy alrededor del login.
CustomTransitionPage<void> _slidePage(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  bool portalFullWidth = false,
  bool sinMarco = false,
}) {
  final duracion = sozuPageTransitionDuration(context);
  return CustomTransitionPage(
    key: state.pageKey,
    child: sinMarco
        ? child
        : portalFullWidth
        ? _PortalAwareFrame(child: child)
        : WebFrame(child: child),
    transitionDuration: duracion,
    // También la de regreso: su valor por defecto son 300 ms cocidos, así que
    // sin esto el "atrás" seguiría animando con "reducir animaciones" activo.
    reverseTransitionDuration: duracion,
    transitionsBuilder: sozuPageTransition,
  );
}

/// Navegación (espejo de `/admin/agent/*` del portal web, sin el prefijo):
/// - Guards: sin sesión → /login; contraseña temporal → /change-password.
/// - Shell con 6 tabs: Inicio · Inventario · Pipeline · Prospectos ·
///   Comisiones · Perfil.
/// - Secundarias: inventario/proyecto/:id, inventario/unidades, prospectos/:id,
///   notificaciones y las de perfil (cuenta, expediente, identidad, fiscal,
///   banco, capacitación).
final routerProvider = Provider<GoRouter>((ref) {
  // read (NO watch) para ambos: Listenable.merge ya re-evalúa el redirect en
  // cada notify; watch reconstruiría el GoRouter completo en cada cambio de
  // sesión/perfil, remontando las pantallas (p.ej. el login perdería su
  // estado y el mensaje de error al validar rol).
  final auth = ref.read(authProvider);
  final imp = ref.read(impersonationProvider);

  return GoRouter(
    initialLocation: '/inicio',
    refreshListenable: Listenable.merge([auth, imp]),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final inAuthArea =
          loc == '/login' ||
          loc == '/forgot-password' ||
          loc == _rutaConfirmacion ||
          loc == emailNotConfirmedPath;

      // Pantalla de autenticación aún trabajando: no sacarla (ni a /splash)
      // hasta que ella decida. En /login evita que el signOut por rol inválido
      // desmonte la pantalla y pierda el mensaje de error; en /change-password,
      // que el perfil ya sin `debe_cambiar_password` se lleve el sheet de
      // biometría antes de que el usuario conteste.
      if (auth.authFlowInProgress &&
          (loc == '/login' ||
              loc == '/change-password' ||
              loc == _rutaConfirmacion)) {
        return null;
      }
      if (auth.isLoading) return loc == '/splash' ? null : '/splash';
      // Gate de correo sin confirmar (roles de portal): pantalla dedicada. Va
      // antes que todo lo demás para atrapar también la rehidratación de una
      // sesión guardada al abrir la app, no solo el login. El gate ya cerró la
      // sesión, así que sin esta regla el usuario caería en /login sin
      // explicación.
      if (auth.blockedAccess == AccessBlock.emailNotConfirmed) {
        return loc == emailNotConfirmedPath ? null : emailNotConfirmedPath;
      }
      if (loc == '/splash') {
        // Sesión resuelta: salir del splash.
        if (auth.session == null || auth.locked) return '/login';
        if (auth.mustChangePassword) return '/change-password';
        if (auth.isSuperAdmin && !imp.active) return '/seleccionar-agente';
        return '/inicio';
      }
      // Candado biométrico puesto: la sesión sigue viva por debajo pero la
      // app se comporta como deslogueada hasta desbloquear.
      if (auth.session == null || auth.locked) {
        // Bloqueo ya limpiado ("Volver al inicio de sesión"): la pantalla de
        // confirmación deja de tener sentido.
        if (loc == emailNotConfirmedPath) return '/login';
        return inAuthArea ? null : '/login';
      }
      if (auth.mustChangePassword) {
        return loc == '/change-password' ? null : '/change-password';
      }
      // Super admin: sin agente seleccionado solo selector o envío de avisos.
      if (auth.isSuperAdmin) {
        if (!imp.active) {
          const permitidas = {'/seleccionar-agente', '/admin-avisos'};
          return permitidas.contains(loc) ? null : '/seleccionar-agente';
        }
        if (loc == '/seleccionar-agente' || loc == '/admin-avisos') {
          return null; // cambiar de agente / enviar avisos
        }
        if (inAuthArea || loc == '/change-password') return '/inicio';
        return null;
      }
      if (loc == '/seleccionar-agente' || loc == '/admin-avisos') {
        return '/inicio';
      }
      if (inAuthArea || loc == '/change-password') return '/inicio';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      // Las pantallas de acceso van a sangre: su propio AuthScaffold
      // resuelve el responsive y fuerza el tema claro.
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _slidePage(context, state, const LoginScreen(), sinMarco: true),
      ),
      // La fija la Edge Function en el correo: cambiarla deja muertos los
      // enlaces ya enviados. Este host servia el portal legacy y ahora sirve
      // Flutter, asi que sin esta ruta el enlace caia en el fallback SPA y
      // terminaba en /login sin confirmar nada.
      GoRoute(
        path: _rutaConfirmacion,
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters;
          return _slidePage(
            context,
            state,
            ConfirmacionEmailScreen(
              tokenHash: q['token_hash'],
              type: q['type'],
              email: q['email'],
              nombre: q['nombre'],
            ),
            sinMarco: true,
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          const ForgotPasswordScreen(),
          sinMarco: true,
        ),
      ),
      GoRoute(
        path: emailNotConfirmedPath,
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          const EmailNotConfirmedScreen(),
          sinMarco: true,
        ),
      ),
      GoRoute(
        path: '/change-password',
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          const ChangePasswordScreen(),
          sinMarco: true,
        ),
      ),
      // Admin sin cliente seleccionado (fuera del shell del portal).
      // `sinMarco` como las de acceso: AdminLayout ya trae su propio Scaffold,
      // ancho maximo y scroll de viewport completo. Con el WebFrame, fuera de sus
      // 900 px solo quedaba un ColoredBox y la rueda del raton no hacia nada en
      // los laterales.
      GoRoute(
        path: '/seleccionar-agente',
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          const SelectClientScreen(),
          sinMarco: true,
        ),
      ),
      GoRoute(
        path: '/admin-avisos',
        pageBuilder: (context, state) => _slidePage(
          context,
          state,
          const AnnouncementsScreen(),
          sinMarco: true,
        ),
      ),
      // Modo portal (web ≥1024px): PortalShellWrapper envuelve TODAS las
      // pantallas del agente con el shell del portal (sidebar 256 + topbar
      // 64, ruta activa marcada); en móvil/angosto devuelve el hijo tal cual
      // y el layout actual no cambia.
      ShellRoute(
        // En móvil (<1024) el wrapper añade la barra inferior flotante a TODAS
        // las pantallas del agente (tabs + secundarias), de modo que el menú
        // NUNCA desaparezca; en modo portal (web ≥1024) o escritorio nativo el
        // _AgenteMobileChrome es un pass-through y manda el sidebar/_SideNav.
        builder: (context, state, child) {
          final path = state.uri.path;
          // NotificacionesFx envuelve TODAS las pantallas del agente (móvil,
          // portal y escritorio): observa la campana a nivel app y dispara la
          // animación de llegada hacia el destino visible de cada pantalla, sin
          // depender de que una campana concreta esté montada/visible.
          // WebSelectable habilita seleccionar/copiar texto con el mouse en web.
          // Va AQUÍ y no en el builder de MaterialApp porque SelectionArea
          // necesita un Overlay ancestro (lo crea el Navigator) y el builder de
          // MaterialApp está por encima de él. Un solo montaje cubre todas las
          // pantallas del agente: tabs y secundarias.
          return WebSelectable(
            child: NotificacionesFx(
              child: PortalShellWrapper(
                currentPath: path,
                child: _AgenteMobileChrome(currentPath: path, child: child),
              ),
            ),
          );
        },
        routes: [
          // Secundarias (con back; en modo portal se muestran dentro del shell).
          GoRoute(
            path: '/inventario/proyecto/:id',
            pageBuilder: (context, state) => _slidePage(
              context,
              state,
              ProyectoDetalleScreen(
                idProyecto: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              ),
              // Ficha ancha (galería + tabla de modelos): sin el tope de 900px
              // del WebFrame en modo portal.
              portalFullWidth: true,
            ),
          ),
          GoRoute(
            path: '/inventario/unidades',
            pageBuilder: (context, state) {
              final q = state.uri.queryParameters;
              return _slidePage(
                context,
                state,
                UnidadesScreen(
                  idProyecto: int.tryParse(q['proyecto'] ?? ''),
                  idModelo: int.tryParse(q['modelo'] ?? ''),
                  abrirFiltros: q['openFilters'] == 'true',
                ),
                // Tabla de disponibilidad: mismo criterio que el proyecto.
                portalFullWidth: true,
              );
            },
          ),
          GoRoute(
            path: '/prospectos/:id',
            pageBuilder: (context, state) => _slidePage(
              context,
              state,
              ProspectoDetalleScreen(
                idPersona: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              ),
            ),
          ),
          GoRoute(
            path: '/notificaciones',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const NotificacionesScreen()),
          ),
          GoRoute(
            path: '/perfil/cuenta',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const PerfilCuentaScreen()),
          ),
          GoRoute(
            path: '/perfil/expediente',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const PerfilExpedienteScreen()),
          ),
          GoRoute(
            path: '/perfil/identidad',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const PerfilPersonalScreen()),
          ),
          GoRoute(
            path: '/perfil/fiscal',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const PerfilFiscalScreen()),
          ),
          GoRoute(
            path: '/perfil/banco',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const PerfilCuentasScreen()),
          ),
          GoRoute(
            path: '/perfil/capacitacion',
            pageBuilder: (context, state) =>
                _slidePage(context, state, const PerfilCapacitacionScreen()),
          ),
          // Shell de tabs.
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => _TabsShell(shell: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/inicio',
                    builder: (context, state) => const InicioScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/inventario',
                    builder: (context, state) => const InventarioScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/pipeline',
                    builder: (context, state) => const PipelineScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/prospectos',
                    builder: (context, state) => const ProspectosScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/comisiones',
                    builder: (context, state) => const ComisionesScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/perfil',
                    builder: (context, state) => const PerfilScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Aterrizaje del enlace de confirmacion de correo. La ruta la fija
/// `reset-user-password` en el correo; aqui solo se atiende.
const _rutaConfirmacion = '/auth/confirmacion-email';

/// Tabs del shell, EN EL ORDEN DE LAS RAMAS: el índice de esta lista es el
/// índice de rama que espera `goBranch`, así que no se filtra ni se reordena.
/// Quién se pinta lo decide [_SideNav] con el menú visible.
const _navItems = [
  (Icons.home_outlined, 'Inicio', '/inicio'),
  (Icons.apartment_outlined, 'Inventario', '/inventario'),
  (Icons.view_kanban_outlined, 'Pipeline', '/pipeline'),
  (Icons.groups_outlined, 'Prospectos', '/prospectos'),
  (Icons.payments_outlined, 'Comisiones', '/comisiones'),
  (Icons.person_outline, 'Perfil', '/perfil'),
];

/// Shell de las 6 ramas: en escritorio pinta la sidebar (`_SideNav`); en móvil
/// solo entrega el contenido (la barra inferior flotante la añade
/// [_AgenteMobileChrome] a nivel del ShellRoute, para que persista también en
/// las pantallas secundarias). Si un super admin impersona a un agente,
/// muestra la franja "Viendo como" sobre el layout.
class _TabsShell extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const _TabsShell({required this.shell});

  void _go(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Modo portal (web ≥1024px): el PortalShellWrapper del router ya pinta
    // sidebar, topbar e impersonación; aquí solo va el contenido de las tabs,
    // sin bottom nav ni _SideNav.
    if (isPortalMode(context)) {
      return Scaffold(body: shell);
    }
    final auth = ref.watch(authProvider);
    final imp = ref.watch(impersonationProvider);
    final banner = auth.isSuperAdmin && imp.active
        ? _ImpersonationBanner(nombre: imp.nombre ?? 'Agente')
        : null;

    if (isDesktop(context)) {
      // Escritorio nativo: la sidebar muestra solo las ramas visibles, con su
      // índice REAL de rama - filtrar la lista sin conservar el índice mandaría
      // a goBranch a la rama de al lado.
      final visibles = ref
          .watch(menuAgenteProvider)
          .map((t) => t.route)
          .toSet();
      final items = [
        for (var i = 0; i < _navItems.length; i++)
          if (visibles.contains(_navItems[i].$3))
            (indice: i, icon: _navItems[i].$1, label: _navItems[i].$2),
      ];
      final layout = Row(
        children: [
          _SideNav(
            items: items,
            currentIndex: shell.currentIndex,
            onSelect: _go,
          ),
          Expanded(child: shell),
        ],
      );
      return Scaffold(
        body: banner == null
            ? layout
            : Column(
                children: [
                  banner,
                  Expanded(child: layout),
                ],
              ),
      );
    }
    // Móvil (<1024): la barra inferior flotante la provee _AgenteMobileChrome
    // (envuelve tabs + secundarias). Aquí solo el contenido (+ franja de
    // impersonación cuando aplica).
    return Scaffold(
      body: banner == null
          ? shell
          : Column(
              children: [
                banner,
                Expanded(child: shell),
              ],
            ),
    );
  }
}

/// Envoltorio móvil (<1024) común a TODAS las pantallas del agente: añade la
/// barra inferior flotante ([_AgenteBottomNav]) tanto sobre las tabs como
/// sobre las pantallas secundarias (proyecto, unidades, prospecto,
/// notificaciones, las de perfil), de modo que el menú nunca desaparezca
/// y siempre haya cómo moverse. En modo portal (web ≥1024) o escritorio nativo
/// es un pass-through: el sidebar del portal / `_SideNav` ya navegan.
class _AgenteMobileChrome extends StatelessWidget {
  final String currentPath;
  final Widget child;

  const _AgenteMobileChrome({required this.currentPath, required this.child});

  @override
  Widget build(BuildContext context) {
    if (isPortalMode(context) || isDesktop(context)) return child;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: child,
      bottomNavigationBar: _AgenteBottomNav(currentPath: currentPath),
    );
  }
}

/// Barra inferior flotante del agente (móvil): tarjeta redondeada con sombra
/// suave, respetando SafeArea. Muestra los primeros ítems del menú y agrupa el
/// resto tras el botón "Más" (…). El ítem activo se resuelve por la ruta actual
/// (un detalle como `/prospectos/:id` resalta su tab padre). Los tabs cambian de
/// sección con `context.go` (preservan el estado del IndexedStack); las
/// secundarias del menú "Más" se abren con `context.push` para que quede stack
/// y aparezca la flecha de regresar.
class _AgenteBottomNav extends ConsumerWidget {
  final String currentPath;

  const _AgenteBottomNav({required this.currentPath});

  /// Rutas que corresponden a ramas del StatefulShellRoute: siempre se navegan
  /// con `context.go` (nunca push) para conservar el estado de la rama.
  static const _branchRoutes = {
    '/inicio',
    '/inventario',
    '/pipeline',
    '/prospectos',
    '/comisiones',
    '/perfil',
  };

  /// Activo por prefijo de ruta; "Inicio" solo con match exacto.
  bool _isActive(String route, String path) {
    if (route == '/inicio') return path == '/inicio';
    return path == route || path.startsWith('$route/');
  }

  String _shortLabel(String label) =>
      label == 'Notificaciones' ? 'Avisos' : label;

  void _navigateTo(BuildContext context, String route, {required bool push}) {
    if (_branchRoutes.contains(route)) {
      context.go(route); // preserva el estado de la rama
    } else if (push) {
      context.push(route); // stack → flecha de regresar
    } else {
      context.go(route);
    }
  }

  void _mostrarMasMenu(BuildContext context, List<AgenteMenuTab> items) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final it in items)
              ListTile(
                leading: Icon(it.icon),
                title: Text(it.label),
                selected: _isActive(it.route, currentPath),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  // Secundarias con push (stack); ramas con go.
                  _navigateTo(context, it.route, push: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = context.s.color;
    // Menú visible del portal (mismo orden y mismos permisos que el sidebar, vía
    // `menuAgenteProvider`). Los primeros ítems como tabs; el resto tras "Más"
    // (…) para que TODOS sean alcanzables aunque no quepan.
    final menu = ref.watch(menuAgenteProvider);
    const maxTabs = 4; // 4 tabs + "Más" cuando hay más de 5 ítems
    final hasOverflow = menu.length > 5;
    final tabs = hasOverflow ? menu.take(maxTabs).toList() : menu;
    final overflow = hasOverflow
        ? menu.skip(maxTabs).toList()
        : <AgenteMenuTab>[];

    final selected = tabs.indexWhere((t) => _isActive(t.route, currentPath));
    // "Más" resaltado cuando la pantalla actual no es ninguno de los tabs
    // visibles (estás en una secundaria o en un ítem del overflow).
    final masActive = hasOverflow && selected < 0;
    // Destino de la animación de llegada (NotificacionesFx) cuando no hay
    // campana visible: el ítem "Notificaciones" si es una pestaña visible, o
    // el botón "Más" (…) si vive dentro del overflow.
    final notifTabIdx = tabs.indexWhere((t) => t.route == '/notificaciones');
    final notifEnMas =
        notifTabIdx < 0 && overflow.any((t) => t.route == '/notificaciones');

    return Container(
      color: tone.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              color: tone.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: tone.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _NavBarItem(
                      key: i == notifTabIdx ? notifNavKey : null,
                      icon: tabs[i].icon,
                      label: _shortLabel(tabs[i].label),
                      active: i == selected,
                      onTap: () =>
                          _navigateTo(context, tabs[i].route, push: false),
                    ),
                  if (hasOverflow)
                    _NavBarItem(
                      key: notifEnMas ? notifNavKey : null,
                      icon: Icons.more_horiz,
                      label: 'Más',
                      active: masActive,
                      onTap: () => _mostrarMasMenu(context, overflow),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ítem de la barra inferior flotante: icono + etiqueta, resaltado en verde
/// cuando está activo.
class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final color = active ? tone.primary : tone.fgSubtle;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Franja de impersonación: "Super admin {admin} · Viendo como: {agente}"
/// + cambiar / salir.
class _ImpersonationBanner extends ConsumerWidget {
  final String nombre;

  const _ImpersonationBanner({required this.nombre});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = context.s.color;
    final admin = ref.watch(authProvider).profile;
    final adminNombre = admin?.displayName ?? admin?.email ?? '';
    return Material(
      color: tone.primarySoft,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 18,
                color: tone.primaryHover,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            'Super admin'
                            '${adminNombre.isEmpty ? '' : ' ($adminNombre)'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '  ·  '),
                      TextSpan(text: 'Viendo como: $nombre'),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tone.primaryHover,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/seleccionar-agente'),
                child: Text(
                  'Cambiar agente',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tone.primaryHover,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(impersonationProvider).clear(),
                child: Text(
                  'Salir',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tone.primaryHover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra lateral de escritorio: wordmark SOZU + navegación.
///
/// [items] llega ya filtrado por permisos y cada ítem trae su `indice` de rama:
/// el resaltado y `onSelect` van por ese índice, no por la posición en la lista.
class _SideNav extends StatelessWidget {
  final List<({int indice, IconData icon, String label})> items;
  final int currentIndex;
  final void Function(int) onSelect;

  const _SideNav({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Container(
      width: 248,
      color: tone.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sozu',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: tone.fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PORTAL DEL AGENTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                    color: tone.fgSubtle,
                  ),
                ),
              ],
            ),
          ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: InkWell(
                onTap: () => onSelect(item.indice),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: item.indice == currentIndex
                        ? tone.primarySoft
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 20,
                        color: item.indice == currentIndex
                            ? tone.primaryHover
                            : tone.fgMuted,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: item.indice == currentIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: item.indice == currentIndex
                              ? tone.primaryHover
                              : tone.fgMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              appVersionLabel,
              style: TextStyle(fontSize: 11, color: tone.fgSubtle),
            ),
          ),
        ],
      ),
    );
  }
}

/// En modo portal devuelve el hijo tal cual (el shell ya limita el ancho a
/// 1280px); en cualquier otro caso aplica el WebFrame de 900px de siempre.
class _PortalAwareFrame extends StatelessWidget {
  final Widget child;

  const _PortalAwareFrame({required this.child});

  @override
  Widget build(BuildContext context) =>
      isPortalMode(context) ? child : WebFrame(child: child);
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: SozuBrand.green500)),
    );
  }
}
