import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Doble de [InventarioPort] con datos fijos en memoria: sin red y sin backend.
/// Se inyecta con `inventarioPortProvider.overrideWithValue`.
///
/// Los payloads se construyen con los `fromJson` reales (no con constructores):
/// así el doble también fija el CONTRATO de la Edge Function, y un cambio de
/// nombre de campo rompe el test en vez de salir en producción.
class FakeInventarioPort implements InventarioPort {
  /// Fallo forzado de la PRÓXIMA operación; se consume al usarse.
  ApiError? nextFailure;

  /// Nombres de los métodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  /// Simula un agente sin desarrollos asignados (respuesta vacía, no error).
  bool sinAcceso = false;

  /// Últimos filtros con los que se pidieron unidades.
  ConsultaUnidades? ultimaConsulta;

  void _revisar(String metodo) {
    log.add(metodo);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  @override
  Future<List<DesarrolloResumen>> desarrollos() async {
    _revisar('desarrollos');
    if (sinAcceso) return const [];
    return [
      DesarrolloResumen.fromJson(const {
        'id': 7,
        'nombre': 'Torre Margot',
        'ubicacion': 'Guadalajara, Jalisco',
        'imagen_url': 'https://cdn.sozu.com/margot.webp',
        'precio_desde': '3250000.00',
        'unidades_disponibles': 12,
        'total_unidades': 80,
        'avance_pct': 45,
        'estatus': 'Obra gris',
        'url_publica': 'https://www.sozu.com/desarrollo/torre-margot/',
      }),
      DesarrolloResumen.fromJson(const {
        'id': 9,
        'nombre': 'Distrito Andares',
        'ubicacion': 'Zapopan, Jalisco',
        'precio_desde': null,
        'unidades_disponibles': 0,
        'total_unidades': 40,
        'avance_pct': 100,
        'url_publica': 'https://www.sozu.com/desarrollo/distrito-andares/',
      }),
    ];
  }

  @override
  Future<FichaDesarrollo> desarrollo(int idDesarrollo) async {
    _revisar('desarrollo:$idDesarrollo');
    return FichaDesarrollo.fromJson({
      'proyecto': {
        'id': idDesarrollo,
        'nombre': 'Torre Margot',
        'descripcion': 'Torre de 20 niveles.',
        'direccion': 'Av. Vallarta 1000',
        'imagen_url': 'https://cdn.sozu.com/margot.webp',
        'latitud': '20.6736',
        'longitud': '-103.4054',
        'fecha_entrega': '2027-06-30',
        'url_publica': 'https://www.sozu.com/desarrollo/torre-margot/',
      },
      'showroom': {
        'nombre': 'Showroom Margot',
        'direccion': 'Av. Vallarta 1002',
        'latitud': '20.6740',
        'longitud': '-103.4060',
      },
      'stats': {'disponibles': 12, 'total': 80},
      'avance': {
        'pct': 45,
        'etapa_actual': 'Obra gris',
        'milestones': [
          {'etapa': 'Cimentación', 'pct': 20, 'completada': true},
          {'etapa': 'Obra gris', 'pct': 45, 'completada': false, 'es_actual': true},
        ],
        'video': {
          'url_embed': 'https://www.youtube.com/embed/abc123',
          'nombre': 'Avance mayo',
        },
      },
      'amenidades': [
        {'id': 3, 'nombre': 'Alberca', 'foto': 'https://cdn.sozu.com/alberca.webp'},
      ],
      'modelos': [
        {
          'id': 55,
          'nombre': 'Modelo B',
          'm2': '82.5',
          'recamaras': 2,
          'banos': 2,
          'precio_desde': '3250000.00',
          'disponibles': 4,
          'plano_url': 'https://cdn.sozu.com/plano-b.pdf',
          'multimedia': ['https://cdn.sozu.com/b1.webp'],
        },
      ],
      'vistas': [
        {'id': 1, 'nombre': 'Lobby', 'url': 'https://cdn.sozu.com/lobby.webp'},
        {'id': 2, 'nombre': 'Sin archivo', 'url': null},
      ],
      'multimedia': [
        {'id': null, 'url': 'https://cdn.sozu.com/margot.webp'},
        {'id': 4, 'url': 'https://cdn.sozu.com/margot-2.webp'},
      ],
      'puntos_interes': [
        {'id': 2, 'nombre': 'Plaza Andares', 'distancia_km': '0.8'},
      ],
      'documentos': {
        'brochure': {'id': 30, 'url': 'https://cdn.sozu.com/brochure.pdf?token=x'},
        'ficha_tecnica': null,
      },
      'fecha_entrega': '2027-06-30',
    });
  }

  @override
  Future<PaginaUnidades> unidades(ConsultaUnidades consulta) async {
    _revisar('unidades:${consulta.pagina}:${consulta.porPagina}');
    ultimaConsulta = consulta;
    if (sinAcceso) return PaginaUnidades.fromJson(const {});
    return PaginaUnidades.fromJson(const {
      'propiedades': [
        {
          'id': 101,
          'numero_propiedad': '1203',
          'numero_piso': '12',
          'precio_lista': '3250000.00',
          'm2_interiores': '70.00',
          'm2_exteriores': '12.50',
          'm2_total': '82.50',
          'proyecto_id': 7,
          'proyecto_nombre': 'Torre Margot',
          'edificio_nombre': 'Torre A',
          'modelo_id': 55,
          'modelo_nombre': 'Modelo B',
          'recamaras': 2,
          'banos': 2,
          'medio_banos': 1,
          'bodegas_count': 1,
          'estacionamientos_count': 2,
          'estacionamientos_tipos': ['Techado', 'Techado'],
          'imagenes': [
            {'id': 1, 'url': 'https://cdn.sozu.com/u1.webp'},
          ],
          'esquemas_pago': [],
        },
        {
          'id': 102,
          'numero_propiedad': '905',
          'numero_piso': '9',
          'precio_lista': '2980000.00',
          'm2_total': '75.00',
          'proyecto_id': 7,
          'proyecto_nombre': 'Torre Margot',
          'modelo_id': 55,
          'modelo_nombre': 'Modelo B',
          'recamaras': 2,
          'banos': 2,
          'imagenes': [],
          'esquemas_pago': [],
        },
      ],
      'total_count': 2,
      'total_pages': 1,
      'project_counts': {'Torre Margot': 12},
      'filter_options': {
        'proyectos': ['Torre Margot'],
        'modelos': ['Modelo B'],
        'recamaras': [2, 3],
        'niveles': ['10', '2', '9'],
      },
      'esquemas_pago_por_proyecto': {
        '7': [
          {
            'id': 900,
            'id_proyecto': 7,
            'nombre': 'Tradicional',
            'porcentaje_descuento_aumento': '0',
            'porcentaje_enganche': '20',
            'porcentaje_mensualidades': '30',
            'numero_mensualidades': 30,
            'porcentaje_entrega': '50',
            'tramos_mensualidad': null,
            'es_manual': false,
            'orden': 1,
          },
        ],
      },
      'fechas_entrega': {
        '7': {
          'fecha_entrega': '2027-06-30',
          'fecha_entrega_proyecto': null,
          'efectiva': '2027-06-30',
          'meses_mensualidades': 18,
        },
      },
    });
  }

  @override
  Future<PlanosUnidad> planos(int idUnidad) async {
    _revisar('planos:$idUnidad');
    return PlanosUnidad.fromJson(const {
      'plano_arquitectonico_url': 'https://cdn.sozu.com/arq.png?token=x',
      'plano_ubicacion_url': 'https://cdn.sozu.com/nivel.png?token=x',
      'regiones': [
        {
          'unit_number': '03',
          'polygon': [
            [10, 10],
            [40, 10],
            [40, 40],
            [10, 40],
          ],
          'curves': {'1': [45, 25]},
        },
        {
          'unit_number': '4',
          'polygon': [
            [50, 10],
            [80, 10],
            [80, 40],
          ],
        },
        // Región inválida (menos de 3 vértices): el puerto la descarta.
        {
          'unit_number': '9',
          'polygon': [
            [1, 1],
          ],
        },
      ],
      'numero_depa': '03',
      'numero_propiedad': '1203',
      'nivel': '12',
      'modelo': 'Modelo B',
      'edificio': 'Torre A',
      'proyecto': 'Torre Margot',
      'm2_total': '82.50',
    });
  }
}
