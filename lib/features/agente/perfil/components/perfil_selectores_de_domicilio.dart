import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// País, estado y municipio de un domicilio. Viajan juntos porque cambiar el de
/// arriba invalida a los de abajo.
typedef TerritorioDelDomicilio = ({
  String? idPais,
  int? idEstado,
  int? idMunicipio,
});

/// Los tres selects encadenados del domicilio, particular o fiscal.
///
/// La activación exige los tres, así que los comparten las dos hojas que
/// capturan un domicilio: con dos copias, la regla de la cascada se bifurca.
/// Los municipios llegan SOLO del estado elegido (la tabla completa son miles de
/// filas y no cabe en una respuesta de arranque).
class PerfilSelectoresDeDomicilio extends ConsumerWidget {
  final TerritorioDelDomicilio valor;
  final ValueChanged<TerritorioDelDomicilio> onCambio;

  /// En false los tres quedan inertes (se está guardando, o el domicilio se
  /// está copiando de otro).
  final bool habilitado;

  const PerfilSelectoresDeDomicilio({
    super.key,
    required this.valor,
    required this.onCambio,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final catalogos = ref.watch(catalogosDeDomicilioProvider(valor.idEstado));
    final datos = catalogos.valueOrNull;

    if (catalogos.hasError) {
      return Text(
        'No pudimos cargar los catálogos de país, estado y municipio. Guarda lo '
        'demás y vuelve a intentarlo.',
        style: t.text.caption.copyWith(color: t.color.warningFg),
      );
    }

    final estadosDelPais = (datos?.estados ?? const <OpcionDeCatalogo>[])
        .where(
          (e) =>
              valor.idPais == null ||
              e.padre == null ||
              e.padre == valor.idPais,
        )
        .toList();
    final listo = habilitado && datos != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SSelectField<String>(
          label: 'País',
          hint: datos == null ? 'Cargando…' : 'Selecciona el país',
          value: valor.idPais,
          opciones: [
            for (final p in datos?.paises ?? const <OpcionDeCatalogo>[])
              (value: p.valor, label: p.nombre),
          ],
          // Cambiar de país invalida estado y municipio: dejarlos guardaría un
          // municipio de otro país.
          onChanged: listo
              ? (v) => onCambio((idPais: v, idEstado: null, idMunicipio: null))
              : null,
        ),
        SizedBox(height: t.space.md),
        SSelectField<int>(
          label: 'Estado',
          hint: datos == null ? 'Cargando…' : 'Selecciona el estado',
          value: valor.idEstado,
          opciones: [
            for (final e in estadosDelPais)
              (value: int.tryParse(e.valor) ?? 0, label: e.nombre),
          ],
          onChanged: listo
              ? (v) => onCambio((
                  idPais: valor.idPais,
                  idEstado: v,
                  idMunicipio: null,
                ))
              : null,
        ),
        SizedBox(height: t.space.md),
        SSelectField<int>(
          label: 'Municipio',
          hint: valor.idEstado == null
              ? 'Elige primero el estado'
              : datos == null
              ? 'Cargando…'
              : 'Selecciona el municipio',
          value: valor.idMunicipio,
          opciones: [
            for (final m in datos?.municipios ?? const <OpcionDeCatalogo>[])
              (value: int.tryParse(m.valor) ?? 0, label: m.nombre),
          ],
          onChanged: listo && valor.idEstado != null
              ? (v) => onCambio((
                  idPais: valor.idPais,
                  idEstado: valor.idEstado,
                  idMunicipio: v,
                ))
              : null,
        ),
      ],
    );
  }
}
