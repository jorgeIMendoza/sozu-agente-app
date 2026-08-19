import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/features/agente/comisiones/components/fila_comision.dart';
import 'package:sozu_agente_app/features/agente/comisiones/components/filtros_comisiones.dart';
import 'package:sozu_agente_app/features/agente/comisiones/components/tarjeta_bloqueo.dart';
import 'package:sozu_agente_app/features/agente/comisiones/components/tarjetas_totales.dart';
import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/features/agente/comisiones/providers/comisiones_providers.dart';
import 'package:sozu_agente_app/features/agente/home/components/estado_error_agente.dart';
import 'package:sozu_agente_app/features/agente/home/components/modo_presentacion_boton.dart';
import 'package:sozu_agente_app/shared/providers/modo_presentacion_provider.dart';
import 'package:sozu_agente_app/features/agente/layouts/portal_top_bar.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/fx.dart';

/// Mismo ancho de lectura que Inicio (`max-w-[1040px]` del portal web).
const double _anchoContenido = 1040;

/// Comisiones del agente: lo que ya cobró, lo que tiene por cobrar, y por cada
/// operación su estatus y sus documentos.
///
/// El agente dependiente no llega aquí: la vista la esconde
/// `tabsVisiblesProvider` y el backend le responde 403, porque su comisión la
/// cobra y factura su inmobiliaria.
class ComisionesScreen extends ConsumerWidget {
  const ComisionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final comisiones = ref.watch(comisionesProvider);

    return Scaffold(
      // Sin `backgroundColor`: el del tema es el mismo neutro que pinta el shell
      // del portal (ver Inicio). La barra se colapsa sola en modo portal.
      appBar: const PortalTopBar(title: 'Comisiones'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(comisionesProvider);
            try {
              await ref.read(comisionesProvider.future);
            } catch (_) {
              // El error ya lo pinta la pantalla.
            }
          },
          child: ContentFrame(
            maxWidth: _anchoContenido,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                t.space.md,
                t.space.sm,
                t.space.md,
                t.space.xxl,
              ),
              children: comisiones.when(
                loading: () => const [_Cargando()],
                error: (e, _) => [
                  EstadoErrorAgente(
                    error: e,
                    onReintentar: () => ref.invalidate(comisionesProvider),
                  ),
                ],
                data: (datos) {
                  final bloqueo = datos.bloqueo;
                  // El bloqueo sustituye la pantalla entera: mostrar totales en
                  // cero junto al aviso se lee como "no tienes comisiones", que
                  // es otra cosa.
                  if (bloqueo != null) {
                    return [
                      TarjetaBloqueo(
                        bloqueo: bloqueo,
                        onCompletarPerfil: () => context.go('/perfil'),
                      ),
                    ];
                  }
                  return _contenido(context, ref, datos);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contenido(
    BuildContext context,
    WidgetRef ref,
    ComisionesAgente datos,
  ) {
    final t = context.s;
    final modo = ref.watch(modoPresentacionProvider);
    final filtradas = ref.watch(comisionesFiltradasProvider);
    final hayFiltros = ref.watch(hayFiltrosActivosProvider);

    return [
      const ModoPresentacionCintillo(queSeOculta: 'tu ingreso'),
      SizedBox(height: t.space.sm),
      TarjetasTotales(totales: datos.totales, enmascarar: modo.enmascarar),
      SizedBox(height: t.space.md),
      FiltrosComisiones(
        proyectos: datos.filtros.proyectos,
        etapas: datos.filtros.estatus,
      ),
      SSectionLabel(
        text: filtradas.length == 1
            ? '1 comisión'
            : '${filtradas.length} comisiones',
        trailing: const ModoPresentacionBoton(),
      ),
      if (filtradas.isEmpty)
        _vacio(ref, sinComisiones: datos.comisiones.isEmpty, hayFiltros: hayFiltros)
      else
        SStaggered(
          children: [
            for (final comision in filtradas)
              Padding(
                padding: EdgeInsets.only(bottom: t.space.sm),
                child: FilaComision(comision: comision),
              ),
          ],
        ),
    ];
  }

  /// Dos vacíos distintos: el agente que todavía no vende nada y el filtro que no
  /// encuentra nada. Confundirlos hace que un filtro olvidado se lea como "no
  /// tengo comisiones".
  Widget _vacio(
    WidgetRef ref, {
    required bool sinComisiones,
    required bool hayFiltros,
  }) {
    if (sinComisiones) {
      return const SEmptyState.card(
        icon: Icons.payments_outlined,
        title: 'Aún no tienes comisiones',
        message:
            'Cuando se registre tu primera venta aparecerá aquí con su monto '
            'y su estatus.',
      );
    }
    return SEmptyState.card(
      icon: Icons.filter_alt_off_outlined,
      title: 'Ninguna comisión coincide',
      message: 'Prueba con otro proyecto, otro estatus u otro cliente.',
      action: hayFiltros
          ? SButton.secondary(
              label: 'Limpiar filtros',
              fullWidth: false,
              onPressed: () {
                ref.read(filtroProyectoProvider.notifier).state = kFiltroTodos;
                ref.read(filtroEtapaProvider.notifier).state = kFiltroTodos;
                ref.read(filtroClienteProvider.notifier).state = '';
              },
            )
          : null,
    );
  }
}

/// Placeholder de la pantalla completa mientras carga: totales, filtros y tres
/// tarjetas. Reserva el mismo alto que el contenido real para que la lista no
/// salte al llegar los datos.
class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SSkeleton(height: 104, radius: t.radius.lg)),
            SizedBox(width: t.space.sm),
            Expanded(child: SSkeleton(height: 104, radius: t.radius.lg)),
          ],
        ),
        SizedBox(height: t.space.md),
        SSkeleton(height: 68, radius: t.radius.md),
        SizedBox(height: t.space.md),
        for (var i = 0; i < 3; i++) ...[
          SSkeleton(height: 168, radius: t.radius.lg),
          SizedBox(height: t.space.sm),
        ],
      ],
    );
  }
}
