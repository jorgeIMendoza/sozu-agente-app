import 'package:sozu_agente_app/features/agente/home/ports/inicio_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Doble de [InicioPort] con datos fijos en memoria: sin red, sin Supabase.
/// Se inyecta con `inicioPortProvider.overrideWithValue`.
class FakeInicioPort implements InicioPort {
  /// Fallo forzado de la PRÓXIMA operación; se consume al usarse.
  ApiError? proximoFallo;

  /// Nombres de los métodos llamados, en orden, para pruebas de secuencia.
  final List<String> log = [];

  /// Payload que devuelve [cargarResumen], en el formato del contrato.
  Map<String, dynamic> payload = _payloadPorDefecto();

  void _fallarSiToca(String metodo) {
    log.add(metodo);
    final f = proximoFallo;
    proximoFallo = null;
    if (f != null) throw f;
  }

  @override
  Future<ResumenInicio> cargarResumen() async {
    _fallarSiToca('cargarResumen');
    return ResumenInicio.desdeJson(payload);
  }

  @override
  Future<void> cancelarCita(int idCita) async {
    _fallarSiToca('cancelarCita:$idCita');
  }

  /// Dos citas por venir, dos pasadas y KPIs con decimales: suficiente para
  /// ejercitar el recorte a tres y el formato de moneda.
  static Map<String, dynamic> _payloadPorDefecto() => {
    'kpis': {
      'comision_pagada': 125000.5,
      // Como lo manda Postgres para un `numeric`: texto, no número.
      'comision_pendiente': '48250.25',
      'ventas_activas': 3,
      'ventas_cerradas': 2,
    },
    'citas': [
      {
        'id': 1,
        'fecha': '2026-09-01',
        'hora_inicio': '10:00:00',
        'hora_fin': '11:00:00',
        'ubicacion': 'Showroom Polanco',
        'estatus': 'agendada',
        'badge': {'etiqueta': 'Agendada', 'tono': 'info'},
        'id_tipo_cita': 2,
        'tipo_nombre': 'Visita',
        'config_nombre': 'Showroom Reforma',
        'proyecto_nombre': 'Margot',
        'prospecto_nombre': 'Ana López',
        'id_persona_prospecto': 88,
        'id_proyecto': 1743,
        'notas': 'Llega 10 minutos antes.',
        'es_pasada': false,
      },
      {
        'id': 2,
        'fecha': '2026-09-05',
        'hora_inicio': '00:00:00',
        'hora_fin': '00:00:00',
        'estatus': 'agendada',
        'badge': {'etiqueta': 'Agendada', 'tono': 'info'},
        'tipo_nombre': 'Visita',
        'proyecto_nombre': 'Margot',
        'es_pasada': false,
      },
      {
        'id': 3,
        'fecha': '2026-07-20',
        'hora_inicio': '09:30:00',
        'estatus': 'asistio',
        'badge': {'etiqueta': 'Asistió', 'tono': 'success'},
        'es_pasada': true,
      },
      {
        'id': 4,
        'fecha': '2026-07-10',
        'estatus': 'no_asistio',
        'badge': {'etiqueta': 'No asistió', 'tono': 'danger'},
        'es_pasada': true,
      },
    ],
    'propiedades_activas': 3,
    'ultimo_acceso': '2026-08-10T15:30:00Z',
  };
}
