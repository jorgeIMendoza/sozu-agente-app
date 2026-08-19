import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';

/// Desarrollo al que se puede citar a un prospecto.
class DesarrolloParaCita {
  final int id;
  final String nombre;

  const DesarrolloParaCita({required this.id, required this.nombre});
}

/// Prospecto que se puede citar y los desarrollos en los que va.
class ProspectoParaCita {
  final int idPersona;
  final String nombre;
  final List<DesarrolloParaCita> desarrollos;

  const ProspectoParaCita({
    required this.idPersona,
    required this.nombre,
    this.desarrollos = const [],
  });
}

/// Convierte la cartera del CRM en el universo de a quién se puede citar,
/// ordenado por nombre igual que el diálogo del portal web.
///
/// Un desarrollo sin id se descarta: sin él no hay a qué agenda pedirle
/// disponibilidad y el servidor rechazaría el agendado.
List<ProspectoParaCita> prospectosParaCita(List<Prospecto> cartera) {
  final salida = [
    for (final p in cartera)
      ProspectoParaCita(
        idPersona: p.idPersona,
        nombre: p.nombre,
        desarrollos: desarrollosUnicos([
          for (final d in p.desarrollos)
            if (d.idDesarrollo != null)
              DesarrolloParaCita(id: d.idDesarrollo!, nombre: d.desarrollo),
        ]),
      ),
  ];
  salida.sort(
    (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
  );
  return List.unmodifiable(salida);
}

/// Los desarrollos de interés de una ficha de prospecto, listos para el
/// selector de la hoja de agendado.
List<DesarrolloParaCita> desarrollosDeFicha(
  List<DesarrolloDeInteres> desarrollos,
) => desarrollosUnicos([
  for (final d in desarrollos)
    if (d.idDesarrollo != null)
      DesarrolloParaCita(id: d.idDesarrollo!, nombre: d.nombre),
]);

/// Quita los desarrollos repetidos conservando el orden. El mismo desarrollo
/// llega dos veces cuando el prospecto tiene varias unidades en él.
List<DesarrolloParaCita> desarrollosUnicos(List<DesarrolloParaCita> lista) {
  final vistos = <int>{};
  return List.unmodifiable([
    for (final d in lista)
      if (vistos.add(d.id)) d,
  ]);
}
