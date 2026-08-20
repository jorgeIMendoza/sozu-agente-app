import 'package:sozu_agente_app/features/agente/citas/ports/citas_port.dart';

/// Los cupos de capacitación del agente en un solo calendario.
class AgendaDeCapacitacion {
  /// Días con cupo, en orden de fecha.
  final List<DiaDisponible> dias;

  /// Desarrollo del que salió cada configuración. `agendar_capacitacion` lo
  /// manda como `id_proyecto`.
  final Map<int, int> desarrolloPorConfiguracion;

  const AgendaDeCapacitacion({
    this.dias = const [],
    this.desarrolloPorConfiguracion = const {},
  });

  bool get vacia => dias.isEmpty;

  /// El día de esa fecha, o null si ese día ya no tiene cupo.
  DiaDisponible? dia(String? fecha) {
    for (final d in dias) {
      if (d.fecha == fecha) return d;
    }
    return null;
  }
}

/// Fusiona la disponibilidad que respondió cada desarrollo en un calendario
/// único.
///
/// `disponibilidad_capacitacion` responde por desarrollo, pero la misma
/// configuración cuelga de varios: sin deduplicar por configuración + fecha +
/// hora, el mismo cupo se pintaría tantas veces como desarrollos tenga el
/// agente.
AgendaDeCapacitacion fusionarAgendaDeCapacitacion(
  Map<int, List<DiaDisponible>> porDesarrollo,
) {
  final cuposPorFecha = <String, List<HorarioDisponible>>{};
  final vistos = <String>{};
  final desarrolloPorConfiguracion = <int, int>{};

  for (final entrada in porDesarrollo.entries) {
    for (final dia in entrada.value) {
      if (dia.fecha.isEmpty) continue;
      for (final horario in dia.horarios) {
        if (!vistos.add(
          '${dia.fecha}|${horario.idConfiguracion}|${horario.hora}',
        )) {
          continue;
        }
        desarrolloPorConfiguracion.putIfAbsent(
          horario.idConfiguracion,
          () => entrada.key,
        );
        (cuposPorFecha[dia.fecha] ??= []).add(horario);
      }
    }
  }

  final fechas = cuposPorFecha.keys.toList()..sort();
  return AgendaDeCapacitacion(
    dias: [
      for (final fecha in fechas)
        DiaDisponible(
          fecha: fecha,
          horarios: cuposPorFecha[fecha]!
            ..sort(
              (a, b) => a.hora != b.hora
                  ? a.hora.compareTo(b.hora)
                  : a.idConfiguracion.compareTo(b.idConfiguracion),
            ),
        ),
    ],
    desarrolloPorConfiguracion: Map.unmodifiable(desarrolloPorConfiguracion),
  );
}
