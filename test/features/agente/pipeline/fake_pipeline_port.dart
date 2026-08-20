import 'dart:async';

import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Doble de [PipelinePort] con datos fijos en memoria: sin red y sin backend.
/// Se inyecta con `pipelinePortProvider.overrideWithValue`.
class FakePipelinePort implements PipelinePort {
  /// Fallo forzado de la PRÓXIMA operación; se consume al usarse.
  ApiError? proximoFallo;

  /// Métodos llamados, en orden, para fijar que una acción bloqueada en el app
  /// no llega al servidor.
  final List<String> log = [];

  /// El catálogo de razones está habilitado en el ambiente.
  bool catalogoDisponible = true;

  /// Cuelga la PRÓXIMA operación asíncrona hasta que la prueba la complete.
  /// Es lo que permite observar el estado de carga de la UI; se consume al
  /// usarse, igual que [proximoFallo].
  Completer<void>? compuerta;

  void _fallarSiToca(String metodo) {
    log.add(metodo);
    final f = proximoFallo;
    proximoFallo = null;
    if (f != null) throw f;
  }

  /// Variante de [_fallarSiToca] que primero espera a [compuerta].
  Future<void> _colgarSiToca(String metodo) async {
    final c = compuerta;
    if (c != null) {
      compuerta = null;
      await c.future;
    }
    _fallarSiToca(metodo);
  }

  static Map<String, dynamic> _negocio({
    required int idOferta,
    int? idNegocio,
    String etapa = 'oferta_enviada',
    String lead = 'Ana Ruiz',
    double? precio = 1000000,
    Map<String, dynamic>? noAvance,
  }) => {
    'id_oferta': idOferta,
    'id_negocio': idNegocio,
    'id_propiedad': 500 + idOferta,
    'es_producto': false,
    'folio': 'O-${idOferta.toString().padLeft(6, '0')}',
    'proyecto_nombre': 'Margot',
    'unidad': 'A-$idOferta',
    'lead': {'id_persona': idOferta, 'nombre': lead, 'email': 'ana@x.com'},
    'precio': precio,
    'etapa': etapa,
    'fecha_generacion': '2026-08-01T12:00:00Z',
    'id_cuenta_cobranza': 900 + idOferta,
    'cuenta_label': 'CC-00000$idOferta',
    'reserva_token': idOferta.isEven ? 'tok-$idOferta' : null,
    'no_avance': noAvance,
    'inmobiliaria_nombre': 'Interno',
    'ofertas_count': 2,
    'ofertas_ids': [idOferta, idOferta + 100],
    'url_cliente': 'https://admin.sozu.com/oferta/O-00000$idOferta',
    'url_preview': 'https://admin.sozu.com/oferta/O-00000$idOferta',
  };

  @override
  Future<PipelineAgente> negocios({DateTime? desde}) async {
    _fallarSiToca('negocios');
    return PipelineAgente.fromJson({
      'etapas': [
        {'clave': 'nuevo', 'label': 'Nuevo', 'orden': 10, 'automatica': false},
        {
          'clave': 'negociando',
          'label': 'Negociando',
          'orden': 50,
          'automatica': false,
        },
        {
          'clave': 'oferta_enviada',
          'label': 'Oferta enviada',
          'orden': 60,
          'automatica': true,
        },
        {
          'clave': 'perdido',
          'label': 'Cierre perdido',
          'orden': 99,
          'automatica': false,
        },
      ],
      'negocios': [
        // Con negocio en el pipeline: se puede mover.
        _negocio(idOferta: 1, idNegocio: 77, etapa: 'negociando'),
        // SIN negocio en el pipeline (`crm_negocios` no resolvió): no se mueve.
        _negocio(idOferta: 2, lead: 'Beto Lara'),
        // Cerrado perdido y sin razón capturada: alimenta el aviso.
        _negocio(idOferta: 3, idNegocio: 79, etapa: 'perdido', precio: null),
      ],
      'resumen': {
        'negocios': 3,
        'ofertas': 6,
        'monto_abierto': 2000000,
        'cerrados_sin_razon': 1,
      },
      'catalogo_no_avance': {
        'disponible': catalogoDisponible,
        'motivos': [
          {
            'id': 1,
            'clave': 'fuera_presupuesto',
            'nombre': 'Está fuera de presupuesto',
            'requiere_comentario': false,
            'es_recuperable': true,
            'orden': 10,
          },
          {
            'id': 13,
            'clave': 'otro',
            'nombre': 'Otro motivo',
            'requiere_comentario': true,
            'es_recuperable': true,
            'orden': 999,
          },
        ],
      },
    });
  }

  @override
  Future<OfertaDetalle> detalleOferta(int idOferta) async {
    _fallarSiToca('detalleOferta:$idOferta');
    return OfertaDetalle.fromJson({
      'id_oferta': idOferta,
      'es_producto': false,
      'folio': 'O-${idOferta.toString().padLeft(6, '0')}',
      'propiedad': {
        'id': 500 + idOferta,
        'numero_propiedad': 'A-$idOferta',
        'precio_lista': 1000000,
      },
      'asociados': [
        {'tipo': 'bodega', 'nombre': 'B-12', 'es_incluido': true, 'precio': 0},
        {
          'tipo': 'estacionamiento',
          'nombre': 'E-3',
          'es_incluido': false,
          'precio': 250000,
        },
      ],
      'esquemas': [
        {
          'id': 40,
          'nombre': '20-60-20',
          'porcentaje_enganche': 20,
          'porcentaje_mensualidades': 60,
          'porcentaje_entrega': 20,
          'numero_mensualidades': 24,
          'porcentaje_descuento_aumento': -5,
        },
      ],
      'link_digital': {
        'token': 'tok-$idOferta',
        'url': 'https://admin.sozu.com/oferta/O-00000$idOferta/tok-$idOferta',
        'url_preview': 'https://admin.sozu.com/oferta/O-00000$idOferta',
      },
      'ya_tiene_esquema': false,
      'id_esquema_pago_seleccionado': null,
    });
  }

  @override
  Future<void> moverEtapa({
    required int idNegocio,
    required String claveEtapa,
  }) async {
    _fallarSiToca('moverEtapa:$idNegocio:$claveEtapa');
  }

  @override
  Future<RazonNoAvance> registrarRazonNoAvance({
    required int idOferta,
    required int idMotivo,
    String? comentario,
  }) async {
    _fallarSiToca('registrarRazonNoAvance:$idOferta:$idMotivo');
    return RazonNoAvance(
      idMotivo: idMotivo,
      motivoNombre: 'Está fuera de presupuesto',
      comentario: comentario,
      registradoPor: 'agente@sozu.com',
      fecha: DateTime.utc(2026, 8, 10),
    );
  }

  @override
  Future<CambioEsquema> elegirEsquemaPago({
    required int idOferta,
    required int idEsquema,
  }) async {
    _fallarSiToca('elegirEsquemaPago:$idOferta:$idEsquema');
    return CambioEsquema(
      idEsquemaSeleccionado: idEsquema,
      acuerdosRegenerados: acuerdosRegenerados,
    );
  }

  /// Lo que el servidor reporta de la regeneración de acuerdos.
  bool? acuerdosRegenerados;

  @override
  Future<LinkCliente> generarLinkCliente({
    required int idOferta,
    String? email,
  }) async {
    _fallarSiToca('generarLinkCliente:$idOferta');
    return const LinkCliente(
      token: 'tok-nuevo',
      url: 'https://admin.sozu.com/oferta/O-000001/tok-nuevo',
      urlPreview: 'https://admin.sozu.com/oferta/O-000001',
    );
  }

  /// Valor de `adjuntarPdf` con el que llegó el último envío por correo. Es lo
  /// que fija que la casilla de la hoja viaje como booleano y no como texto.
  bool? ultimoAdjuntarPdf;

  /// Destinatario del último envío por correo, ya recortado por la hoja.
  String? ultimoDestinatario;

  @override
  Future<EnvioCorreoOferta> enviarOfertaPorCorreo({
    required int idOferta,
    required String email,
    bool adjuntarPdf = false,
  }) async {
    ultimoAdjuntarPdf = adjuntarPdf;
    ultimoDestinatario = email;
    await _colgarSiToca('enviarOfertaPorCorreo:$idOferta');
    return EnvioCorreoOferta(enviado: true, email: email, conPdf: adjuntarPdf);
  }

  @override
  Future<PdfOferta> pdfDeOferta(int idOferta) async {
    await _colgarSiToca('pdfDeOferta:$idOferta');
    return PdfOferta(
      url: 'https://cdn.sozu.com/ofertas_temp/O_$idOferta.pdf',
      nombreArchivo: 'O_$idOferta.pdf',
    );
  }

  /// Argumentos del último `crearOferta`. Es lo que fija que el prospecto de la
  /// cartera y el capturado sean excluyentes.
  ({int? idPersonaLead, ProspectoNuevo? prospecto, int? idEsquemaPago})?
  ultimaOferta;

  /// Respuesta de `crearOferta`. Cambiarla deja probar el link ausente, los
  /// avisos del servidor y la recotización sin tocar el resto del doble.
  Map<String, dynamic> respuestaCrearOferta = const {
    'ok': true,
    'id_oferta': 45678,
    'id_persona_lead': 8901,
    'prospecto_creado': false,
    'id_esquema_pago_seleccionado': 57,
    'ofertas_producto': [],
    'avisos': [],
    'link_digital': {
      'token': 'tok-45678',
      'url': 'https://admin.sozu.com/oferta/O-045678/tok-45678',
      'url_preview': 'https://admin.sozu.com/oferta/O-045678',
    },
    'email_enviado': false,
    'id_negocio': 3312,
    'es_recotizacion': false,
  };

  @override
  Future<OfertaCreada> crearOferta({
    required int idPropiedad,
    int? idEsquemaPago,
    int? idPersonaLead,
    ProspectoNuevo? prospecto,
    Map<int, int?> esquemasProducto = const {},
    bool crearLink = true,
    bool enviarEmail = false,
    bool adjuntarPdf = false,
  }) async {
    ultimaOferta = (
      idPersonaLead: idPersonaLead,
      prospecto: prospecto,
      idEsquemaPago: idEsquemaPago,
    );
    await _colgarSiToca('crearOferta:$idPropiedad');
    return OfertaCreada.fromJson(respuestaCrearOferta);
  }
}
