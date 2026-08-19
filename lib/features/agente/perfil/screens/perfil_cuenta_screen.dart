import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_bloque_datos.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_subvista.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/mensajes_del_perfil.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// "Datos de tu cuenta": lo que SOZU define sobre la relación con el agente.
///
/// Toda la pantalla es de consulta a propósito: el rol, el esquema de comisión y
/// el líder los asigna SOZU, y un campo editable aquí prometería algo que el
/// backend rechazaría.
class PerfilCuentaScreen extends ConsumerWidget {
  const PerfilCuentaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final asyncPerfil = ref.watch(perfilAgenteProvider);

    return PerfilSubvista(
      titulo: 'Datos de tu cuenta',
      onRefrescar: () => refrescarPerfilDelAgente(ref),
      children: [
        asyncPerfil.when(
          loading: () => const PerfilSubvistaCargando(),
          error: (e, _) => SErrorState(
            title: tituloDeErrorDeCarga(e),
            message: mensajeDeErrorDeCarga(e),
            onRetry: () => ref.invalidate(perfilAgenteProvider),
          ),
          data: (perfil) {
            final cuenta = perfil.cuentaSozu;
            if (cuenta == null) {
              return const SEmptyState.card(
                icon: Icons.badge_outlined,
                title: 'Todavía no tenemos registrada tu relación con SOZU.',
                message:
                    'Avísale a tu contacto interno para que dé de alta tu '
                    'esquema de comisión.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PerfilBloqueDatos(
                  titulo: 'Datos de tu cuenta',
                  filas: [
                    PerfilDato(etiqueta: 'Rol / Puesto', valor: cuenta.rol),
                    PerfilDato(
                      etiqueta: 'Tipo de relación',
                      valor: cuenta.tipoRelacion,
                    ),
                    PerfilDato(
                      etiqueta: 'Esquema de comisión',
                      valor: cuenta.porcentajeComision == null
                          ? null
                          : '${_sinCerosSobrantes(cuenta.porcentajeComision!)}% '
                                'sobre precio de lista',
                    ),
                    PerfilDato(
                      etiqueta: 'Estatus',
                      trailing: SBadge(
                        label: cuenta.activo ? 'Activo' : 'Inactivo',
                        tone: cuenta.activo
                            ? SBadgeTone.positive
                            : SBadgeTone.neutral,
                        size: SBadgeSize.sm,
                      ),
                    ),
                    PerfilDato(etiqueta: 'Equipo / Líder', valor: cuenta.lider),
                    PerfilDato(
                      etiqueta: 'Fecha de alta',
                      valor: cuenta.fechaAlta == null
                          ? null
                          : formatDateEsMX(cuenta.fechaAlta),
                      ultima: true,
                    ),
                  ],
                  pie:
                      'Estos datos los administra SOZU. Si algo no coincide, '
                      'avísale a tu contacto interno.',
                ),
                SizedBox(height: t.space.md),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// "3" en vez de "3.0", pero "2.5" se conserva: el esquema de comisión se lee
/// como lo pactaron, sin decimales inventados ni recortados.
String _sinCerosSobrantes(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString();
}
