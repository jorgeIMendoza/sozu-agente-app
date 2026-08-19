import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Doble de [ProspectosPort] con datos fijos en memoria: sin red y sin backend.
/// Se inyecta con `prospectosPortProvider.overrideWithValue`.
///
/// Los datos se construyen con los `fromJson` del puerto a propósito: así el
/// test también fija el mapeo de las claves que manda el servidor.
class FakeProspectosPort implements ProspectosPort {
  /// Fallo forzado de la PRÓXIMA operación; se consume al usarse.
  ApiError? nextFailure;

  /// Nombres de los métodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  /// Estados de lead guardados por relación, como los dejaría el servidor.
  final Map<int, int> estadosGuardados = {};

  /// Notas creadas: texto y cuántos archivos traía cada una.
  final List<({String texto, int adjuntos})> notasCreadas = [];

  bool viaCarteraDeTransicion = false;

  void _registrar(String metodo) {
    log.add(metodo);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  @override
  Future<CarteraProspectos> cartera({
    String? busqueda,
    int? idEstadoLead,
    int? idDesarrollo,
    int limite = 500,
    int desde = 0,
  }) async {
    _registrar('cartera');
    return CarteraProspectos.fromJson({
      'catalogo_estatus': [
        {'id': 1, 'clave': 'nuevo', 'nombre': 'Nuevo', 'color': '#94a3b8'},
        {'id': 2, 'clave': 'conectado', 'nombre': 'Conectado'},
      ],
      'rows': [
        {
          'id_persona': 11,
          'nombre': 'Ana Torres',
          'email': 'ana@correo.com',
          'telefono': '5512345678',
          'es_cliente': true,
          'total_unidades': 2,
          'proyectos': [
            {
              'id_entidad_relacionada': 101,
              'id_proyecto': 7,
              'proyecto': 'Margot',
              'id_estatus_lead': 2,
              'estatus': 'Conectado',
              'unidades': [
                {
                  'id_oferta': 900,
                  'unidad': 'A-101',
                  'tipo': 'Propiedad',
                  'valor': '2500000.50',
                  'etapa': 'apartado_pagado',
                  'es_cliente': true,
                  'ofertas_count': 3,
                },
                {
                  'id_oferta': 901,
                  'unidad': 'Bodega 4',
                  'tipo': 'Bodega',
                  'valor': 150000,
                  'etapa': 'oferta_enviada',
                },
              ],
            },
          ],
        },
        {
          'id_persona': 12,
          'nombre': 'Bruno Díaz',
          'email': 'bruno@correo.com',
          'telefono': '5598765432',
          'total_unidades': 0,
          'proyectos': [
            {
              'id_entidad_relacionada': 102,
              'id_proyecto': 9,
              'proyecto': 'Torre Sur',
              'id_estatus_lead': 1,
              'estatus': 'Nuevo',
              'unidades': [],
            },
          ],
        },
      ],
      'totales': {'prospectos': 2, 'unidades': 2, 'clientes': 1},
      'via_rpc': !viaCarteraDeTransicion,
    });
  }

  @override
  Future<DetalleProspecto> detalle(int idPersona) async {
    _registrar('detalle:$idPersona');
    return DetalleProspecto.fromJson({
      'persona': {
        'id': idPersona,
        'nombre': 'Ana Torres',
        'email': 'ana@correo.com',
        'telefono': '5512345678',
        'clave_pais_telefono': 'MX',
        'tipo_persona': 'pf',
        'rfc': 'TOAN850101H2A',
      },
      'entidades': [
        {'id': 101, 'id_proyecto': 7, 'nombre': 'Margot'},
      ],
      'ofertas': [
        {
          'id': 900,
          'fecha_generacion': '2026-08-01T10:00:00Z',
          'propiedad_nombre': 'A-101',
          'token': 'abc123',
          'tiene_cuenta': true,
          'url_cliente': 'https://admin.sozu.com/oferta/O-000900/abc123',
        },
      ],
      'timeline': [
        {
          'kind': 'nota',
          'fecha': '2026-08-05T18:30:00Z',
          'titulo': 'Nota',
          'detalle': 'Pidió cotización a 24 meses \u{1F4CE} plano.pdf',
          'html':
              '<p>Pidió cotización a <strong>24 meses</strong></p>'
              '<p><a href="https://x/storage/v1/object/sign/documentos/a.pdf'
              '?t=1" class="crm-attachment">\u{1F4CE} plano.pdf</a></p>',
          'autor': 'Agente Uno',
          'id_nota': 55,
          'adjuntos': [
            {
              'nombre': 'plano.pdf',
              'url': 'https://x/storage/v1/object/sign/documentos/a.pdf?t=1',
              'es_imagen': false,
            },
          ],
        },
        {
          'kind': 'cita',
          'fecha': '2026-08-03T17:00:00Z',
          'titulo': 'Visita a showroom',
          'detalle': 'Margot · confirmada',
        },
      ],
    });
  }

  @override
  Future<int> crear({
    required DatosProspecto datos,
    required List<int> desarrollos,
  }) async {
    _registrar('crear:${datos.email}:${desarrollos.join(",")}');
    return 99;
  }

  @override
  Future<void> editar({
    required int idPersona,
    required DatosProspecto datos,
    List<int>? desarrollos,
  }) async => _registrar('editar:$idPersona');

  @override
  Future<void> cambiarEstadoLead({
    required int idRelacion,
    required int idEstadoLead,
  }) async {
    _registrar('cambiarEstadoLead:$idRelacion:$idEstadoLead');
    estadosGuardados[idRelacion] = idEstadoLead;
  }

  @override
  Future<void> transferir({
    required int idRelacion,
    required String idAgenteDestino,
    String? motivo,
  }) async => _registrar('transferir:$idRelacion:$idAgenteDestino');

  @override
  Future<List<AgenteDestino>> agentesDestino() async {
    _registrar('agentesDestino');
    return [
      AgenteDestino.fromJson({
        'auth_user_id': 'uuid-1',
        'nombre': 'Carla Ruiz',
        'rol': 'Agente Inmobiliario',
      }),
    ];
  }

  @override
  Future<List<DesarrolloVinculable>> desarrollosVinculables() async {
    _registrar('desarrollosVinculables');
    return const [
      DesarrolloVinculable(id: 7, nombre: 'Margot'),
      DesarrolloVinculable(id: 9, nombre: 'Torre Sur'),
    ];
  }

  @override
  Future<void> agregarNota({
    required int idPersona,
    int? idRelacion,
    String texto = '',
    List<AdjuntoNuevo> adjuntos = const [],
  }) async {
    _registrar('agregarNota:$idPersona');
    notasCreadas.add((texto: texto, adjuntos: adjuntos.length));
  }

  /// Ediciones de nota recibidas, para fijar qué se conserva al guardar.
  final List<({String texto, String? cuerpoConFormato, int adjuntos})>
  notasEditadas = [];

  @override
  Future<void> editarNota({
    required int idNota,
    required String texto,
    String? cuerpoConFormato,
    List<AdjuntoNota> adjuntos = const [],
  }) async {
    _registrar('editarNota:$idNota:${adjuntos.length}');
    notasEditadas.add((
      texto: texto,
      cuerpoConFormato: cuerpoConFormato,
      adjuntos: adjuntos.length,
    ));
  }

  @override
  Future<void> eliminarNota(int idNota) async =>
      _registrar('eliminarNota:$idNota');
}
