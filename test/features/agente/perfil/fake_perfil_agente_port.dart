import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Doble de [PerfilAgentePort] con estado en memoria: sin red, sin Supabase.
/// Se inyecta con `perfilAgentePortProvider.overrideWithValue(...)`.
class FakePerfilAgentePort implements PerfilAgentePort {
  FakePerfilAgentePort({PerfilAgente? perfil})
    : perfil = perfil ?? perfilDePrueba();

  /// Lo que devuelve [cargar].
  PerfilAgente perfil;

  /// Fallo forzado de la PRÓXIMA operación; se consume al usarse.
  ApiError? proximoFallo;

  /// Nombres de los métodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  /// Última cuenta bancaria guardada, para verificar qué se mandó.
  Map<String, Object?>? ultimaCuenta;

  /// Últimos datos de la Constancia mandados al subir el documento fiscal.
  DatosDeConstancia? ultimosDatosFiscales;

  FirmaDeCarta firma = const FirmaDeCarta();

  /// Trazo autógrafo que llegó en la última [iniciarFirmaDeCarta].
  String? ultimaFirmaAutografa;

  void _registrar(String metodo) {
    log.add(metodo);
    final fallo = proximoFallo;
    if (fallo != null) {
      proximoFallo = null;
      throw fallo;
    }
  }

  @override
  Future<PerfilAgente> cargar() async {
    _registrar('cargar');
    return perfil;
  }

  @override
  Future<CatalogosDeDomicilio> catalogosDeDomicilio({int? idEstado}) async {
    _registrar('catalogosDeDomicilio:$idEstado');
    return CatalogosDeDomicilio(
      paises: const [OpcionDeCatalogo(valor: 'MX', nombre: 'México')],
      estados: const [
        OpcionDeCatalogo(valor: '9', nombre: 'Ciudad de México', padre: 'MX'),
      ],
      municipios: idEstado == null
          ? const []
          : const [
              OpcionDeCatalogo(
                valor: '15',
                nombre: 'Benito Juárez',
                padre: '9',
              ),
            ],
    );
  }

  @override
  Future<void> guardarIdentidad({
    required String nombreLegal,
    required String telefono,
    required String curp,
    DateTime? fechaNacimiento,
    String? sexo,
    Domicilio? domicilio,
  }) async {
    _registrar('guardarIdentidad');
  }

  @override
  Future<void> guardarUsoCfdi(String? codigo) async {
    _registrar('guardarUsoCfdi:$codigo');
  }

  @override
  Future<String?> guardarPresentacion(String? frase) async {
    _registrar('guardarPresentacion');
    return frase;
  }

  @override
  Future<String?> guardarFoto({
    required String base64,
    required String mime,
  }) async {
    _registrar('guardarFoto:$mime');
    return 'https://ejemplo/avatar.png';
  }

  @override
  Future<void> borrarFoto() async {
    _registrar('borrarFoto');
  }

  @override
  Future<EstadoDocumento> subirDocumento({
    required int tipo,
    required String base64,
    required String nombre,
    String? contentType,
    bool validado = false,
    DatosDeConstancia? datos,
  }) async {
    _registrar('subirDocumento:$tipo');
    ultimosDatosFiscales = datos;
    return validado ? EstadoDocumento.validado : EstadoDocumento.revision;
  }

  @override
  Future<int> guardarCuentaBancaria({
    int? id,
    required int idBanco,
    required String numeroCuenta,
    required String titular,
    String? clabe,
    String? evidenciaBase64,
    String? evidenciaNombre,
    String? evidenciaContentType,
  }) async {
    _registrar('guardarCuentaBancaria');
    ultimaCuenta = {
      'id': id,
      'id_banco': idBanco,
      'numero_cuenta': numeroCuenta,
      'titular': titular,
      'clabe': clabe,
      'evidencia': evidenciaNombre,
    };
    return id ?? 99;
  }

  @override
  Future<void> borrarCuentaBancaria(int id) async {
    _registrar('borrarCuentaBancaria:$id');
  }

  @override
  Future<FirmaDeCarta> iniciarFirmaDeCarta({String? firmaAutografa}) async {
    _registrar('iniciarFirmaDeCarta');
    ultimaFirmaAutografa = firmaAutografa;
    return firma;
  }

  @override
  Future<FirmaDeCarta> consultarFirmaDeCarta() async {
    _registrar('consultarFirmaDeCarta');
    return firma;
  }
}

/// Perfil de un agente INDEPENDIENTE: administra sus datos fiscales y su cuenta.
PerfilAgente perfilDePrueba() => PerfilAgente.desde(_jsonDePrueba());

/// Perfil de un agente DEPENDIENTE de una inmobiliaria: fiscal y banco los lleva
/// ella, y el backend responde `403 forbidden_field` si intenta escribirlos.
PerfilAgente perfilDependienteDePrueba() {
  final json = _jsonDePrueba();
  json['es_dependiente'] = true;
  json['inmobiliaria_nombre'] = 'Grupo Inmobiliario Norte';
  json['fiscal'] = {
    ...(json['fiscal'] as Map<String, dynamic>),
    'solo_lectura': true,
    'nota': 'La administra Grupo Inmobiliario Norte',
  };
  json['expediente'] = {
    'solo_lectura_csf': true,
    'docs': [
      {
        'key': 'identidad',
        'nombre': 'INE',
        'emisor': 'INE',
        'hint': 'Frente y reverso en un solo PDF',
        'tipos': [2, 3, 4, 63],
        'modo': 'ine',
        'estatus': 'validado',
        'solo_lectura': false,
      },
      {
        'key': 'csf',
        'nombre': 'Constancia de Situación Fiscal',
        'emisor': 'SAT',
        'hint': 'PDF del SAT, no mayor a 3 meses',
        'tipos': [6],
        'estatus': 'pendiente',
        'solo_lectura': true,
        'nota': 'La sube Grupo Inmobiliario Norte',
      },
    ],
  };
  json['bancos'] = <Map<String, dynamic>>[];
  // El backend le marca fiscal y banco como completos: los lleva su inmobiliaria.
  json['activacion'] = {
    ...(json['activacion'] as Map<String, dynamic>),
    'steps': [
      {'id': 'basic', 'etiqueta': 'Identidad', 'estado': 'complete'},
      {
        'id': 'fiscal',
        'etiqueta': 'Información fiscal',
        'estado': 'complete',
        'solo_lectura': true,
      },
      {
        'id': 'bank-accounts',
        'etiqueta': 'Cuenta bancaria',
        'estado': 'complete',
        'solo_lectura': true,
      },
      {'id': 'training', 'etiqueta': 'Capacitación', 'estado': 'pending'},
    ],
  };
  return PerfilAgente.desde(json);
}

Map<String, dynamic> _jsonDePrueba() => <String, dynamic>{
  'activacion': {
    'percentage': 75,
    'completados': 3,
    'total_pasos': 4,
    'steps': [
      {
        'id': 'basic',
        'etiqueta': 'Identidad',
        'estado': 'complete',
        'faltantes': <String>[],
      },
      {
        'id': 'fiscal',
        'etiqueta': 'Información fiscal',
        'estado': 'partial',
        'faltantes': ['RFC', 'Régimen fiscal'],
      },
      {
        'id': 'bank-accounts',
        'etiqueta': 'Cuenta bancaria',
        'estado': 'complete',
      },
      {'id': 'training', 'etiqueta': 'Capacitación', 'estado': 'complete'},
    ],
    'secciones': {
      'total': 5,
      'validadas': 3,
      'en_proceso': 1,
      'pendientes': 1,
      'documentos': 'partial',
    },
  },
  'hero': {
    'nombre': 'Alex Hernández',
    'foto_perfil_url': null,
    'frase_perfil': 'Diez años vendiendo en la zona.',
    'rol': 'Agente Inmobiliario',
    'desarrollos': ['Margot', 'Aurora', 'Lumina', 'Cielo'],
  },
  'cuenta_sozu': {
    'rol': 'Agente Inmobiliario',
    'tipo_relacion': 'Agente inmobiliario',
    'porcentaje_comision': 3,
    'activo': true,
    'lider': 'María Ruiz',
    'fecha_alta': '2026-03-15T00:00:00Z',
  },
  'identidad': {
    'email': 'alex@sozu.com',
    'telefono': '5512345678',
    'nombre_legal': 'Alex Hernández',
    'curp': 'HEAL850101HDFRRL09',
    'fecha_nacimiento': '1985-01-01',
    'sexo': 'M',
    'direccion': {
      'calle': 'Av. Insurgentes Sur',
      'num_ext': '1234',
      'colonia': 'Del Valle',
      'codigo_postal': '03100',
      'id_pais': 'MX',
      'id_estado': 9,
      'id_municipio': 15,
    },
  },
  'fiscal': {
    'nombre_legal': 'Alex Hernández',
    'rfc': null,
    'regimen': '626',
    'regimen_nombre': 'Régimen Simplificado de Confianza',
    'uso_cfdi': 'G03',
    'uso_cfdi_nombre': 'Gastos en general',
    'direccion_fiscal': {'calle': null, 'colonia': null},
    'solo_lectura': false,
    'nota': null,
  },
  'bancos': [
    {
      'id': 7,
      'id_banco': 2,
      'banco': 'BBVA',
      'last4': '4321',
      'titular': 'Alex Hernández',
      'validada': true,
      'editable': true,
      'evidencia_url': 'https://ejemplo/caratula.pdf',
    },
  ],
  'expediente': {
    'solo_lectura_csf': false,
    'docs': [
      {
        'key': 'identidad',
        'nombre': 'INE',
        'emisor': 'INE',
        'hint': 'Frente y reverso en un solo PDF',
        'tipos': [2, 3, 4, 63],
        'modo': 'ine',
        'estatus': 'validado',
        'url_firmada': 'https://ejemplo/ine.pdf',
        'solo_lectura': false,
      },
      {
        'key': 'csf',
        'nombre': 'Constancia de Situación Fiscal',
        'emisor': 'SAT',
        'hint': 'PDF del SAT, no mayor a 3 meses',
        'tipos': [6],
        'estatus': 'pendiente',
        'solo_lectura': false,
      },
      {
        'key': 'carta',
        'nombre': 'Carta de comercialización',
        'emisor': 'SOZU',
        'hint': 'Se genera y firma digitalmente con SOZU',
        'tipos': [48],
        'estatus': 'pendiente',
        'solo_lectura': false,
        'firma': {'estado': 'sin_firmar', 'widget_id': null},
      },
    ],
  },
  'capacitacion': {
    'pct': 100,
    'citas': [
      {
        'id': 1,
        'nombre': 'Capacitación inicial',
        'fecha': '2026-04-10',
        'hora_inicio': '10:00:00',
        'etiqueta': 'Confirmada',
        'tono': 'success',
      },
    ],
  },
  'catalogos': {
    'uso_cfdi': [
      {'codigo': 'G03', 'nombre': 'Gastos en general'},
    ],
    'regimen': [
      {'id': 626, 'nombre': 'Régimen Simplificado de Confianza'},
    ],
    'bancos': [
      {'id': 2, 'nombre': 'BBVA'},
    ],
  },
  'can_edit': true,
  'can_update': true,
  'es_dependiente': false,
  'inmobiliaria_nombre': null,
};
