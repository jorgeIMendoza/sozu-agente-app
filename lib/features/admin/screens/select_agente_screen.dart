import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_agente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/ui/ui.dart';
// Import directo mientras el export de la primitiva no está en ui/ui.dart.
import 'package:sozu_agente_app/features/admin/components/admin_header_bar.dart';
import 'package:sozu_agente_app/features/admin/layouts/admin_layout.dart';
import 'package:sozu_agente_app/features/admin/components/agente_row.dart';
import 'package:sozu_agente_app/features/admin/components/agente_filters.dart';

/// Selector de agente para administradores de la app. El admin elige un agente
/// y navega el portal viendo exactamente lo que ese agente vería al entrar.
///
/// Sirve en web Y en móvil: es el destino post-login de cualquier rol con
/// `canManageAgentApp`, sin importar la plataforma.
///
/// Dos formas de acotar, y se combinan: el filtro de **rol** ([AgenteRoleFilter],
/// Agente Inmobiliario 3 / Agente Interno 9) y el **buscador** por nombre o
/// correo. Sin nada seleccionado se lista todo: los agentes son decenas, así que
/// la lista completa es útil, a diferencia del selector de clientes (miles) del
/// que esta pantalla venía portada y que exigía escribir antes de mostrar algo.
///
/// El filtrado es LOCAL sobre la respuesta de `admin-agentes`: un endpoint por
/// combinación de filtros no compra nada a esta escala y sí agrega latencia por
/// cada tecla.
///
/// ## Estructura
///
/// Esta pantalla **solo compone y orquesta**: lee providers, mantiene el estado
/// de los filtros y decide qué mostrar. Todo lo visual vive en componentes:
///
/// * [AdminHeaderBar] / [AdminHeaderAction] - encabezado y acciones
/// * [AgenteRoleFilter] - pastillas de rol
/// * [SSearchField] - buscador
/// * [AgenteRow] - fila de agente
/// * [SEmptyState] - vacíos e instrucciones
class SelectAgenteScreen extends ConsumerStatefulWidget {
  const SelectAgenteScreen({super.key});

  @override
  ConsumerState<SelectAgenteScreen> createState() => _SelectAgenteScreenState();
}

class _SelectAgenteScreenState extends ConsumerState<SelectAgenteScreen> {
  final _search = TextEditingController();

  String _query = '';
  RolAgente? _rol;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Agentes del rol activo, luego los que coinciden con la búsqueda. El orden
  /// lo manda el backend (alfabético) y no se reordena.
  List<AdminAgente> _filterBy(List<AdminAgente> agentes) {
    final q = _query.trim().toLowerCase();
    return agentes.where((a) {
      if (_rol != null && a.rol != _rol) return false;
      if (q.isEmpty) return true;
      return a.nombre.toLowerCase().contains(q) ||
          (a.email ?? '').toLowerCase().contains(q);
    }).toList();
  }

  /// Cuántos agentes hay por rol, para anotar las pastillas. Se cuenta sobre la
  /// lista completa a propósito: si contara sobre lo ya filtrado, el número de
  /// cada pastilla cambiaría al tocar otra.
  Map<RolAgente, int> _conteos(List<AdminAgente> agentes) {
    final out = <RolAgente, int>{};
    for (final a in agentes) {
      final rol = a.rol;
      if (rol != null) out[rol] = (out[rol] ?? 0) + 1;
    }
    return out;
  }

  void _viewAs(AdminAgente a) {
    ref.read(impersonationProvider).select(a.idPersona, a.nombre, a.email);
    context.go('/inicio');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final auth = ref.watch(authProvider);
    final imp = ref.watch(impersonationProvider);
    final agentes = ref.watch(adminAgentesProvider);
    final todos = agentes.asData?.value.agentes;

    return AdminLayout(
      // 880 y no el default: con el encabezado y las acciones dentro del mismo
      // contenedor, menos ancho aprieta la fila de acciones.
      maxWidth: 880,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminHeaderBar(
            title: 'Selecciona un agente',
            subtitle:
                'Acceso administrador · '
                '${auth.profile?.displayName ?? auth.profile?.email ?? ''}',
            actions: [
              AdminHeaderAction(
                label: 'Enviar avisos',
                icon: Icons.campaign_outlined,
                onPressed: () => context.push('/admin-avisos'),
              ),
              if (imp.active)
                AdminHeaderAction(
                  label: 'Volver al portal',
                  onPressed: () => context.go('/inicio'),
                ),
              AdminHeaderAction(
                label: 'Cerrar sesión',
                isDanger: true,
                onPressed: () => ref.read(authProvider).signOut(),
              ),
            ],
          ),
          SizedBox(height: t.space.md),
          _FiltersPanel(
            rol: _rol,
            onRolChanged: (v) => setState(() => _rol = v),
            conteos: todos == null ? const {} : _conteos(todos),
            total: todos?.length,
            searchController: _search,
            onQueryChanged: (v) => setState(() => _query = v),
          ),
          SizedBox(height: t.space.md),
          _results(agentes),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Resultados
  // -------------------------------------------------------------------------

  /// El contenido NO trae scroll propio: el de la página lo da [AdminLayout].
  /// Por eso las listas van como `Column` y no como `ListView`.
  Widget _results(AsyncValue<AdminAgentes> agentes) {
    final t = context.s;

    return agentes.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 4; i++) ...[
            const _AgenteRowSkeleton(),
            SizedBox(height: t.space.xs),
          ],
        ],
      ),
      error: (_, __) => SErrorState(
        title: 'No pudimos cargar la lista de agentes',
        onRetry: () => ref.invalidate(adminAgentesProvider),
      ),
      data: (data) {
        if (data.agentes.isEmpty) {
          return const SEmptyState(
            icon: Icons.person_search_outlined,
            title: 'Sin agentes',
            message:
                'Ningún usuario con rol de agente puede entrar al portal '
                'todavía.',
          );
        }
        final items = _filterBy(data.agentes);
        if (items.isEmpty) {
          return SEmptyState(
            icon: Icons.search_off_outlined,
            title: 'Sin resultados',
            message: _query.trim().isEmpty
                ? 'Ningún agente tiene ese rol.'
                : 'No encontramos agentes para "$_query".',
          );
        }
        return _AgenteList(agentes: items, onTap: _viewAs);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Partes locales
// ---------------------------------------------------------------------------

/// Tarjeta que agrupa el filtro de rol + el buscador.
///
/// Es una superficie propia sobre el fondo de página: agrupar los dos controles
/// en una card los lee como un solo bloque de "acotar la búsqueda", en vez de
/// dos controles sueltos flotando.
class _FiltersPanel extends StatelessWidget {
  final RolAgente? rol;
  final ValueChanged<RolAgente?> onRolChanged;
  final Map<RolAgente, int> conteos;
  final int? total;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;

  const _FiltersPanel({
    required this.rol,
    required this.onRolChanged,
    required this.conteos,
    required this.total,
    required this.searchController,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // `SCard` y no un Container a mano: repetia su decoracion (surface, radio lg,
    // borde) y con `space.sm` el contenido quedaba pegado al borde. El padding
    // por defecto de la primitiva es `space.md`.
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AgenteRoleFilter(
            rol: rol,
            onRolChanged: onRolChanged,
            conteos: conteos,
            total: total,
          ),
          SizedBox(height: t.space.sm),
          SSearchField(
            controller: searchController,
            label: 'Agente',
            hintText: 'Alex Hernández o alex@example.com',
            // Solo donde hay teclado físico: en teléfono, abrirlo al entrar tapa
            // media pantalla antes de que el usuario pida escribir.
            autofocus: context.bp.isDesktop,
            onChanged: onQueryChanged,
          ),
        ],
      ),
    );
  }
}

class _AgenteList extends StatelessWidget {
  final List<AdminAgente> agentes;
  final void Function(AdminAgente) onTap;

  const _AgenteList({required this.agentes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // `shrinkWrap` + sin physics: el scroll es el de la pagina (AdminLayout).
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: agentes.length,
      separatorBuilder: (_, __) => SizedBox(height: t.space.xs),
      // Entrada escalonada: cada fila entra un poco después de la anterior, así
      // la lista se lee como algo que llega y no como un parpadeo del skeleton
      // al contenido. El retardo lo satura `delayForIndex`, que es lo que evita
      // que una búsqueda con 50 resultados tarde 2 s en terminar de aparecer.
      itemBuilder: (context, i) => SFadeInUp(
        delay: SStaggered.delayForIndex(i),
        child: Consumer(
          builder: (context, ref, _) => AgenteRow(
            agente: agentes[i],
            isSelected:
                ref.watch(impersonationProvider).personaId ==
                agentes[i].idPersona,
            onTap: () => onTap(agentes[i]),
          ),
        ),
      ),
    );
  }
}

/// Ancho del renglón del correo en el skeleton. El correo es más corto que el
/// nombre: dos renglones del mismo ancho se leen como un solo bloque gris.
const double _emailSkeletonWidth = 180;

/// Réplica en gris de [AgenteRow]. Las medidas salen de los mismos tokens que
/// la fila real ([kAgenteRowAvatarSize], `text.label`, `text.caption`) para que
/// la lista no brinque al llegar los datos.
class _AgenteRowSkeleton extends StatelessWidget {
  const _AgenteRowSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      padding: EdgeInsets.all(t.space.sm),
      decoration: BoxDecoration(
        color: t.color.surface,
        borderRadius: t.radius.mdBorder,
        border: Border.all(color: t.color.border),
      ),
      child: Row(
        children: [
          const SSkeleton(
            width: kAgenteRowAvatarSize,
            height: kAgenteRowAvatarSize,
          ),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SSkeleton(height: t.text.label.fontSize!),
                SizedBox(height: t.space.xxs),
                SSkeleton(
                  width: _emailSkeletonWidth,
                  height: t.text.caption.fontSize!,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
