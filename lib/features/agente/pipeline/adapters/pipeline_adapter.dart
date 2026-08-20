import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/shared/adapters/edge_function.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Implementación de [PipelinePort] sobre la Edge Function `agente-pipeline`.
///
/// Único archivo de la feature que sabe cómo se sirve el pipeline: el resto
/// habla de negocios, etapas y razones.
class PipelineAdapter implements PipelinePort {
  /// `id_persona` del agente que un admin está viendo; null = su propia sesión.
  final int? impersonate;

  final EdgeFunctions _fn;

  PipelineAdapter({this.impersonate})
    : _fn = EdgeFunctions(impersonate: impersonate);

  /// Constructor con el llamador ya armado. Existe para las pruebas: es lo que
  /// permite fijar el CUERPO que sale a la function sin levantar backend.
  PipelineAdapter.conLlamador(this._fn) : impersonate = null;

  static const _fnNombre = 'agente-pipeline';

  /// `YYYY-MM-DD`: es el formato que espera el filtro de fecha del servidor.
  static String _soloFecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<PipelineAgente> negocios({DateTime? desde}) async =>
      PipelineAgente.fromJson(
        await _fn.call(
          _fnNombre,
          body: {
            'action': 'lista',
            if (desde != null) 'desde': _soloFecha(desde),
          },
        ),
      );

  @override
  Future<OfertaDetalle> detalleOferta(int idOferta) async =>
      OfertaDetalle.fromJson(
        await _fn.call(
          _fnNombre,
          body: {'action': 'detalle', 'id_oferta': idOferta},
        ),
      );

  @override
  Future<void> moverEtapa({
    required int idNegocio,
    required String claveEtapa,
  }) async {
    await _fn.call(
      _fnNombre,
      body: {
        'action': 'mover_etapa',
        'id_negocio': idNegocio,
        'clave_etapa': claveEtapa,
      },
    );
  }

  @override
  Future<RazonNoAvance> registrarRazonNoAvance({
    required int idOferta,
    required int idMotivo,
    String? comentario,
  }) async {
    final res = await _fn.call(
      _fnNombre,
      body: {
        'action': 'guardar_no_avance',
        'id_oferta': idOferta,
        'id_motivo': idMotivo,
        if (comentario != null && comentario.trim().isNotEmpty)
          'comentario': comentario.trim(),
      },
    );
    return RazonNoAvance.fromJson(mapaDe(res['no_avance']));
  }

  @override
  Future<CambioEsquema> elegirEsquemaPago({
    required int idOferta,
    required int idEsquema,
  }) async => CambioEsquema.fromJson(
    await _fn.call(
      _fnNombre,
      body: {
        'action': 'guardar_esquema',
        'id_oferta': idOferta,
        'id_esquema': idEsquema,
      },
    ),
  );

  @override
  Future<LinkCliente> generarLinkCliente({
    required int idOferta,
    String? email,
  }) async {
    final res = await _fn.call(
      _fnNombre,
      body: {
        'action': 'crear_link',
        'id_oferta': idOferta,
        if (email != null && email.contains('@')) 'email': email,
      },
    );
    return LinkCliente.fromJson(mapaDe(res['link_digital']));
  }

  @override
  Future<EnvioCorreoOferta> enviarOfertaPorCorreo({
    required int idOferta,
    required String email,
    bool adjuntarPdf = false,
  }) async => EnvioCorreoOferta.fromJson(
    await _fn.call(
      _fnNombre,
      body: cuerpoEnviarCorreo(
        idOferta: idOferta,
        email: email,
        adjuntarPdf: adjuntarPdf,
      ),
    ),
  );

  /// Cuerpo de `enviar_oferta_email`.
  ///
  /// `adjuntar_pdf` va como booleano DESNUDO: el servidor compara con `=== true`
  /// y cualquier otra forma ("true", 1) se lee como "sin adjunto" en silencio.
  static Map<String, dynamic> cuerpoEnviarCorreo({
    required int idOferta,
    required String email,
    required bool adjuntarPdf,
  }) => {
    'action': 'enviar_oferta_email',
    'id_oferta': idOferta,
    'email': email.trim(),
    'adjuntar_pdf': adjuntarPdf,
  };

  @override
  Future<PdfOferta> pdfDeOferta(int idOferta) async => PdfOferta.fromJson(
    await _fn.call(
      _fnNombre,
      body: {'action': 'pdf_oferta', 'id_oferta': idOferta},
    ),
  );

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
    final creada = OfertaCreada.fromJson(
      await _fn.call(
        _fnNombre,
        body: cuerpoCrearOferta(
          idPropiedad: idPropiedad,
          idEsquemaPago: idEsquemaPago,
          idPersonaLead: idPersonaLead,
          prospecto: prospecto,
          esquemasProducto: esquemasProducto,
          crearLink: crearLink,
          enviarEmail: enviarEmail,
          adjuntarPdf: adjuntarPdf,
        ),
      ),
    );
    // Un 200 sin `id_oferta` es una function que no conoce la acción y cayó en
    // su rama por omisión: se trata igual que el `invalid_action` explícito para
    // que la pantalla degrade en vez de decir "oferta creada" sin folio.
    if (creada.idOferta == 0) throw ApiError(400, 'invalid_action');
    return creada;
  }

  /// Cuerpo de `crear_oferta`.
  ///
  /// NUNCA lleva identidad del agente (`email_creador`, `id_persona`,
  /// `auth_user_id`), montos, porcentajes ni CLABEs: el servidor los deriva del
  /// JWT o los rechaza, y mandarlos sería cotizar a nombre de otro asesor.
  /// [idPersonaLead] y [prospecto] son EXCLUYENTES: se manda solo el que venga.
  static Map<String, dynamic> cuerpoCrearOferta({
    required int idPropiedad,
    int? idEsquemaPago,
    int? idPersonaLead,
    ProspectoNuevo? prospecto,
    Map<int, int?> esquemasProducto = const {},
    bool crearLink = true,
    bool enviarEmail = false,
    bool adjuntarPdf = false,
  }) => {
    'action': 'crear_oferta',
    'id_propiedad': idPropiedad,
    if (idEsquemaPago != null) 'id_esquema_pago': idEsquemaPago,
    // El prospecto capturado manda: si llegaran los dos, el servidor responde
    // `lead_conflict` y el agente no sabría cuál quitar.
    if (prospecto != null)
      'prospecto': _prospectoAJson(prospecto)
    else if (idPersonaLead != null)
      'id_persona_lead': idPersonaLead,
    if (esquemasProducto.isNotEmpty)
      'esquemas_producto': {
        for (final e in esquemasProducto.entries) '${e.key}': e.value,
      },
    // Los tres van como booleanos DESNUDOS: el servidor compara con `=== true`
    // (y `crear_link` con `!== false`), así que un "true" de texto se lee al
    // revés en silencio.
    'crear_link': crearLink,
    'enviar_email': enviarEmail,
    // El adjunto solo existe si hay correo; suelto, el servidor lo ignora.
    'adjuntar_pdf': enviarEmail && adjuntarPdf,
  };

  /// El prospecto tal como lo valida el servidor: `nombre_completo` es el campo
  /// que lee, y RFC y CURP viajan en null cuando no se capturaron.
  static Map<String, dynamic> _prospectoAJson(ProspectoNuevo p) => {
    'tipo_persona': p.tipoPersona,
    'nombre_completo': p.nombreCompleto.trim(),
    'email': p.email.trim(),
    'clave_pais_telefono': p.clavePaisTelefono,
    'telefono': p.telefono.trim(),
    'rfc': _oNulo(p.rfc),
    'curp': _oNulo(p.curp),
  };

  static String? _oNulo(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? null : t.toUpperCase();
  }
}
