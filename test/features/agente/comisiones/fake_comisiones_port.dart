import 'dart:typed_data';

import 'package:sozu_agente_app/features/agente/comisiones/ports/comisiones_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Doble de [ComisionesPort] con datos fijos en memoria: sin red, sin Supabase.
/// Se inyecta con `comisionesPortProvider.overrideWithValue`.
class FakeComisionesPort implements ComisionesPort {
  /// Fallo forzado de la PRÓXIMA operación; se consume al usarse.
  ApiError? proximoFallo;

  /// Nombres de los métodos llamados, en orden.
  final List<String> log = [];

  /// Payload que devuelve [cargarComisiones], en el formato del contrato.
  Map<String, dynamic> payload = payloadConComisiones();

  /// Facturas recibidas, para afirmar qué se mandó al backend.
  final List<({int cuenta, String nombre, int bytes})> facturas = [];

  void _fallarSiToca(String metodo) {
    log.add(metodo);
    final f = proximoFallo;
    proximoFallo = null;
    if (f != null) throw f;
  }

  @override
  Future<ComisionesAgente> cargarComisiones() async {
    _fallarSiToca('cargarComisiones');
    return ComisionesAgente.desdeJson(payload);
  }

  @override
  Future<String?> subirFactura({
    required int idCuentaCobranza,
    required String nombreArchivo,
    required Uint8List archivo,
  }) async {
    _fallarSiToca('subirFactura:$idCuentaCobranza');
    facturas.add((
      cuenta: idCuentaCobranza,
      nombre: nombreArchivo,
      bytes: archivo.length,
    ));
    return 'https://firmada/factura.pdf';
  }

  /// Tres comisiones en tres etapas, dos proyectos y una operación en
  /// copropiedad: cubre los tres filtros y el permiso de facturar.
  static Map<String, dynamic> payloadConComisiones() => {
    'bloqueo': null,
    'totales': {'cobrado': 125000.5, 'por_cobrar': '48250.25'},
    'filtros': {
      'proyectos': ['Kavia', 'Margot'],
      'estatus': [
        {'valor': 'pagada', 'etiqueta': 'Pagada'},
        {'valor': 'aprobado', 'etiqueta': 'Aprobado'},
        {'valor': 'pendiente', 'etiqueta': 'Pendiente'},
      ],
    },
    'comisiones': [
      {
        'id_cuenta_cobranza': 101,
        'cuenta_label': 'CC-000101',
        'proyecto': 'Margot',
        'propiedad': 'A-301',
        'producto_nombre': '',
        'tipo': 'Propiedad',
        'precio_final': 4200000,
        'porcentaje_comision': '3.00',
        'monto_comision': 126000,
        'aprobada': true,
        'pagada': true,
        'estatus': 'pagada',
        'estatus_bucket': 'pagada',
        'estatus_etiqueta': 'Pagada',
        'factura_url': 'https://firmada/mi-factura.pdf',
        'url_evidencia_pago': 'https://firmada/comprobante.pdf',
        'fecha_pago': '2026-07-24',
        'clientes': [
          {'nombre': 'Ana López', 'email': 'ana@example.com', 'porcentaje': 50},
          {'nombre': 'Luis Ruiz', 'email': 'luis@example.com', 'porcentaje': 50},
        ],
        'puede_subir_factura': false,
      },
      {
        'id_cuenta_cobranza': 102,
        'cuenta_label': 'CC-000102',
        'proyecto': 'Kavia',
        'propiedad': 'B-102',
        'precio_final': 3000000,
        'porcentaje_comision': 2.5,
        'monto_comision': 75000,
        'aprobada': true,
        'pagada': false,
        'estatus': 'factura_requerida',
        'estatus_bucket': 'aprobado',
        'estatus_etiqueta': 'Aprobado',
        'factura_url': null,
        'url_evidencia_pago': null,
        'fecha_pago': null,
        'clientes': [
          {'nombre': 'Marta Díaz', 'email': 'marta@example.com'},
        ],
        'puede_subir_factura': true,
      },
      {
        'id_cuenta_cobranza': 103,
        'cuenta_label': 'CCP-000103',
        'proyecto': 'Margot',
        'propiedad': '',
        'producto_nombre': 'Bodega 12',
        'tipo': 'Producto',
        'precio_final': 250000,
        'porcentaje_comision': 3,
        'monto_comision': 7500,
        'aprobada': false,
        'pagada': false,
        'estatus': 'pendiente',
        'estatus_bucket': 'pendiente',
        'estatus_etiqueta': 'Pendiente',
        'clientes': const [],
        'puede_subir_factura': false,
      },
    ],
  };

  /// Perfil incompleto: la pantalla se sustituye por el checklist.
  static Map<String, dynamic> payloadBloqueado() => {
    'bloqueo': {
      'motivo': 'perfil_incompleto',
      'faltantes': ['Información fiscal', 'Cuenta bancaria'],
    },
    'totales': {'cobrado': 0, 'por_cobrar': 0},
    'filtros': {'proyectos': [], 'estatus': []},
    'comisiones': [],
  };
}
