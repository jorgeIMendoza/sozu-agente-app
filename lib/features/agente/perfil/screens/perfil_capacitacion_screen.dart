import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_fila_seccion.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_subvista.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/mensajes_del_perfil.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Capacitación del agente: su avance y sus citas.
///
/// Solo consulta. Agendar la cita se hace desde el portal web (y llegará al app
/// con el módulo de Citas): ofrecer aquí un botón que no agenda nada sería peor
/// que no ofrecerlo, así que se le dice a quién acudir.
class PerfilCapacitacionScreen extends ConsumerWidget {
  const PerfilCapacitacionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final asyncPerfil = ref.watch(perfilAgenteProvider);

    return PerfilSubvista(
      titulo: 'Capacitación',
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
            final capacitacion = perfil.capacitacion;
            final paso = perfil.activacion.paso('training');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Avance de tu capacitación',
                            style: t.text.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: t.color.fgMuted,
                            ),
                          ),
                          Text(
                            '${capacitacion.porcentaje}%',
                            style: t.text.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: t.color.primaryHover,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: t.space.xs),
                      SProgressBar(
                        percent: capacitacion.porcentaje.toDouble(),
                        thickness: SProgressBarThickness.thick,
                        semanticsLabel: 'Avance de tu capacitación',
                      ),
                      if (paso != null && paso.faltantes.isNotEmpty) ...[
                        SizedBox(height: t.space.sm),
                        Text(
                          paso.faltantes.join(' · '),
                          style: t.text.caption.copyWith(
                            color: t.color.fgMuted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: t.space.md),
                const SSectionLabel(text: 'Tus citas'),
                SizedBox(height: t.space.xs),
                if (capacitacion.citas.isEmpty)
                  const SEmptyState.card(
                    icon: Icons.school_outlined,
                    title: 'Aún no tienes capacitaciones agendadas.',
                    message:
                        'Tu contacto en SOZU agenda tu capacitación; en cuanto '
                        'quede, la verás aquí.',
                  )
                else
                  for (final cita in capacitacion.citas) ...[
                    _Cita(cita: cita),
                    SizedBox(height: t.space.xs),
                  ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Cita extends StatelessWidget {
  final CitaDeCapacitacion cita;

  const _Cita({required this.cita});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final cuando = [
      if (cita.fecha != null) formatDateEsMX(cita.fecha),
      if (cita.hora != null) cita.hora!,
    ].join(' · ');

    return SCard.outlined(
      padding: EdgeInsets.all(t.space.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.color.surfaceAlt,
              borderRadius: t.radius.mdBorder,
            ),
            child: Icon(Icons.event_outlined, size: 17, color: t.color.fgMuted),
          ),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: t.space.xs,
                  runSpacing: t.space.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      cita.nombre,
                      style: t.text.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: t.color.fg,
                      ),
                    ),
                    SBadge(
                      label: cita.etiqueta,
                      tone: tonoDeCita(cita.tono),
                      size: SBadgeSize.sm,
                    ),
                  ],
                ),
                if (cuando.isNotEmpty) ...[
                  SizedBox(height: t.space.xxs),
                  Text(
                    cuando,
                    style: t.text.caption.copyWith(color: t.color.fgSubtle),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
