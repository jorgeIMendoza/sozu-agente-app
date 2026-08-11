import 'package:sozu_agente_app/shared/json.dart';

/// Tono semántico del distintivo de una cita. Lo resuelve el backend para que
/// app y portal web cuenten la misma historia; cada cliente lo pinta con su
/// propia paleta.
enum TonoCita { info, exito, alerta, neutro }

/// Distintivo de estado de una cita ya redactado: "Agendada", "Asistió",
/// "No asistió" o "Sin confirmar".
class DistintivoCita {
  final String etiqueta;
  final TonoCita tono;

  const DistintivoCita({this.etiqueta = '', this.tono = TonoCita.neutro});

  factory DistintivoCita.desdeJson(Map<String, dynamic> j) => DistintivoCita(
    etiqueta: (j['etiqueta'] ?? '') as String,
    tono: switch (j['tono']) {
      'success' => TonoCita.exito,
      'danger' => TonoCita.alerta,
      'info' => TonoCita.info,
      _ => TonoCita.neutro,
    },
  );
}

/// Una cita de la agenda del agente (visita a showroom, capacitación).
class CitaAgente {
  final int id;

  /// `YYYY-MM-DD`. Llega como texto y NO como fecha: el día de la cita es un día
  /// de calendario en México, y convertirlo a `DateTime` local lo correría de día
  /// para quien tenga el dispositivo en otra zona.
  final String? fecha;

  final String? horaInicio;
  final String? horaFin;
  final String? ubicacion;
  final String? estatus;
  final String? estatusNombre;
  final DistintivoCita distintivo;
  final int? idTipoCita;
  final String? tipoNombre;
  final String? configuracionNombre;
  final String? proyectoNombre;
  final String? prospectoNombre;
  final int? idPersonaProspecto;
  final int? idProyecto;
  final String? notas;

  /// Ya pasó el día de la cita (calculado en horario de México por el backend).
  final bool esPasada;

  const CitaAgente({
    required this.id,
    this.fecha,
    this.horaInicio,
    this.horaFin,
    this.ubicacion,
    this.estatus,
    this.estatusNombre,
    this.distintivo = const DistintivoCita(),
    this.idTipoCita,
    this.tipoNombre,
    this.configuracionNombre,
    this.proyectoNombre,
    this.prospectoNombre,
    this.idPersonaProspecto,
    this.idProyecto,
    this.notas,
    this.esPasada = false,
  });

  factory CitaAgente.desdeJson(Map<String, dynamic> j) => CitaAgente(
    id: intDe(j['id']) ?? 0,
    fecha: j['fecha'] as String?,
    horaInicio: j['hora_inicio'] as String?,
    horaFin: j['hora_fin'] as String?,
    ubicacion: j['ubicacion'] as String?,
    estatus: j['estatus'] as String?,
    estatusNombre: j['estatus_nombre'] as String?,
    distintivo: DistintivoCita.desdeJson(mapaDe(j['badge'])),
    idTipoCita: intDe(j['id_tipo_cita']),
    tipoNombre: j['tipo_nombre'] as String?,
    configuracionNombre: j['config_nombre'] as String?,
    proyectoNombre: j['proyecto_nombre'] as String?,
    prospectoNombre: j['prospecto_nombre'] as String?,
    idPersonaProspecto: intDe(j['id_persona_prospecto']),
    idProyecto: intDe(j['id_proyecto']),
    notas: j['notas'] as String?,
    esPasada: j['es_pasada'] == true,
  );

  /// Encabezado de la cita: el nombre de la configuración si el showroom lo
  /// puso, y si no "tipo + proyecto". Mismo orden de preferencia que el portal
  /// web, para que el agente vea el mismo rótulo en los dos lados.
  String get titulo {
    final config = configuracionNombre;
    if (config != null && config.isNotEmpty) return config;
    final partes = [
      tipoNombre,
      proyectoNombre,
    ].where((p) => p != null && p.isNotEmpty).cast<String>();
    return partes.isEmpty ? 'Cita' : partes.join(' · ');
  }

  /// `00:00` significa "sin horario", no medianoche: así se guardan las citas a
  /// las que el showroom todavía no asignó hora.
  static bool _horaValida(String? hora) {
    if (hora == null || hora.length < 5) return false;
    return hora.substring(0, 5) != '00:00';
  }

  /// "10:00 - 11:00", "10:00", o null cuando la cita no tiene horario.
  String? get horario {
    if (!_horaValida(horaInicio)) return null;
    final inicio = horaInicio!.substring(0, 5);
    if (!_horaValida(horaFin)) return inicio;
    return '$inicio - ${horaFin!.substring(0, 5)}';
  }

  /// Solo se cancelan las citas por venir que siguen vivas: una cita pasada ya
  /// no se puede deshacer y una cancelada no se cancela dos veces.
  bool get puedeCancelarse =>
      !esPasada && estatus != 'cancelada' && estatus != 'no_asistio';
}

/// Los cuatro números del tablero del agente.
class KpisAgente {
  final double comisionPagada;
  final double comisionPendiente;
  final int ventasActivas;
  final int ventasCerradas;

  const KpisAgente({
    this.comisionPagada = 0,
    this.comisionPendiente = 0,
    this.ventasActivas = 0,
    this.ventasCerradas = 0,
  });

  factory KpisAgente.desdeJson(Map<String, dynamic> j) => KpisAgente(
    comisionPagada: numDe(j['comision_pagada']),
    comisionPendiente: numDe(j['comision_pendiente']),
    ventasActivas: intDe(j['ventas_activas']) ?? 0,
    ventasCerradas: intDe(j['ventas_cerradas']) ?? 0,
  );
}

/// Tablero de Inicio del agente: sus números, su agenda y su último acceso.
class ResumenInicio {
  final KpisAgente kpis;

  /// TODAS las citas del agente, próximas primero. El recorte a las tres que
  /// caben en la tarjeta es decisión de la pantalla, no del backend.
  final List<CitaAgente> citas;

  final int propiedadesActivas;
  final DateTime? ultimoAcceso;

  const ResumenInicio({
    this.kpis = const KpisAgente(),
    this.citas = const [],
    this.propiedadesActivas = 0,
    this.ultimoAcceso,
  });

  factory ResumenInicio.desdeJson(Map<String, dynamic> j) => ResumenInicio(
    kpis: KpisAgente.desdeJson(mapaDe(j['kpis'])),
    citas: listaDe(j['citas']).map(CitaAgente.desdeJson).toList(),
    propiedadesActivas: intDe(j['propiedades_activas']) ?? 0,
    ultimoAcceso: DateTime.tryParse('${j['ultimo_acceso'] ?? ''}'),
  );
}

/// Tablero de Inicio del Portal del Agente y las escrituras de agenda que se
/// disparan desde ahí.
///
/// La instancia queda atada al agente que se está viendo (el propio, o el que
/// impersona un administrador), así que ningún método recibe ese destinatario.
/// Todos lanzan `ApiError`.
abstract interface class InicioPort {
  /// Números, agenda y último acceso del agente.
  Future<ResumenInicio> cargarResumen();

  /// Cancela una cita del agente. El backend verifica que sea suya.
  Future<void> cancelarCita(int idCita);
}
