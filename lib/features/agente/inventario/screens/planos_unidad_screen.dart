import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/core/open_media.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/plano_nivel.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/features/agente/inventario/providers/inventario_providers.dart';
import 'package:sozu_agente_app/features/agente/inventario/services/mensajes_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/network_image.dart';

/// Abre los planos de una unidad. Va por `Navigator` (no por hoja modal) porque
/// se abre DESDE el detalle de la unidad, que ya es una hoja: apilar dos hojas
/// deja la de abajo inerte y sin forma de volver.
Future<void> abrirPlanosUnidad(
  BuildContext context, {
  required int idUnidad,
  String? titulo,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PlanosUnidadScreen(idUnidad: idUnidad, titulo: titulo),
    ),
  );
}

/// Planos de una unidad: el de ubicación (con la unidad resaltada dentro de su
/// nivel) y el arquitectónico de su modelo.
class PlanosUnidadScreen extends ConsumerWidget {
  final int idUnidad;

  /// Encabezado; si falta, se arma con lo que devuelva el servidor.
  final String? titulo;

  const PlanosUnidadScreen({super.key, required this.idUnidad, this.titulo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planos = ref.watch(planosUnidadProvider(idUnidad));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titulo ?? planos.valueOrNull?.modelo ?? 'Planos',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: planos.when(
          loading: () => Padding(
            padding: EdgeInsets.all(context.s.space.md),
            child: const AspectRatio(
              aspectRatio: 4 / 3,
              child: SSkeleton(height: double.infinity),
            ),
          ),
          error: (e, _) => Padding(
            padding: EdgeInsets.all(context.s.space.md),
            child: SErrorState(
              title: 'No pudimos cargar los planos',
              message: mensajeErrorInventario(e),
              onRetry: () => ref.invalidate(planosUnidadProvider(idUnidad)),
            ),
          ),
          data: (p) => _Planos(planos: p),
        ),
      ),
    );
  }
}

class _Planos extends StatelessWidget {
  final PlanosUnidad planos;

  const _Planos({required this.planos});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final p = planos;

    if (p.vacio) {
      return Padding(
        padding: EdgeInsets.all(t.space.md),
        child: const SEmptyState.card(
          icon: Icons.architecture_outlined,
          title: 'Esta unidad todavía no tiene planos',
          message:
              'Los planos se cargan por nivel y por modelo. En cuanto SOZU los '
              'publique aparecerán aquí.',
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(t.space.md),
      children: [
        SCard(
          child: Wrap(
            spacing: t.space.lg,
            runSpacing: t.space.xs,
            children: [
              if (p.desarrollo != null)
                _Dato(etiqueta: 'Desarrollo', valor: p.desarrollo!),
              if (p.edificio != null)
                _Dato(etiqueta: 'Edificio', valor: p.edificio!),
              if (p.nivel != null) _Dato(etiqueta: 'Nivel', valor: p.nivel!),
              if (p.numeroDepa.isNotEmpty)
                _Dato(etiqueta: 'Departamento', valor: p.numeroDepa),
              if (p.modelo != null) _Dato(etiqueta: 'Modelo', valor: p.modelo!),
              if (p.m2Total != null)
                _Dato(
                  etiqueta: 'Metraje',
                  valor: '${p.m2Total!.toStringAsFixed(2)} m²',
                ),
            ],
          ),
        ),
        SizedBox(height: t.space.md),

        if (p.planoUbicacionUrl != null) ...[
          SSectionLabel.heading(
            text: 'Ubicación en el nivel',
            icon: Icons.map_outlined,
          ),
          SizedBox(height: t.space.xs),
          SCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlanoNivel(
                  url: p.planoUbicacionUrl!,
                  regiones: p.regiones,
                  numeroDepa: p.numeroDepa,
                  numeroUnidad: p.numeroUnidad,
                ),
                SizedBox(height: t.space.xs),
                Text(
                  p.regiones.isEmpty
                      ? 'Este nivel no tiene unidades marcadas en el plano.'
                      : 'Departamento ${p.numeroDepa} resaltado. Pellizca para '
                            'acercar.',
                  style: t.text.caption.copyWith(color: tone.fgMuted),
                ),
              ],
            ),
          ),
          SizedBox(height: t.space.md),
        ],

        if (p.planoArquitectonicoUrl != null) ...[
          SSectionLabel.heading(
            text: 'Plano arquitectónico',
            icon: Icons.architecture_outlined,
          ),
          SizedBox(height: t.space.xs),
          SCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: t.radius.mdBorder,
                  child: InteractiveViewer(
                    maxScale: _zoomMax,
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: SozuNetworkImage(
                        url: p.planoArquitectonicoUrl,
                        fit: BoxFit.contain,
                        placeholderIcon: Icons.architecture_outlined,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: t.space.xs),
                SButton.secondary(
                  label: 'Abrir en el visor',
                  icon: Icons.open_in_full,
                  onPressed: () => openMedia(
                    context,
                    p.planoArquitectonicoUrl,
                    titulo: 'Plano ${p.modelo ?? p.numeroDepa}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Dato del encabezado de los planos: etiqueta chica arriba, valor abajo.
class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Dato({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: t.text.overline.copyWith(color: t.color.fgMuted),
        ),
        Text(
          valor,
          style: t.text.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: t.color.fg,
          ),
        ),
      ],
    );
  }
}

const double _zoomMax = 4;
