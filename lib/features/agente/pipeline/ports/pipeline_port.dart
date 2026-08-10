import 'package:sozu_agente_app/shared/json.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Pipeline de negocios del agente: un negocio = una UNIDAD (propiedad o
/// producto), con todas sus ofertas colapsadas en una sola fila.
///
/// El lenguaje de este archivo es el del negocio, no el del transporte: quien
/// lo lea no debe poder decir con qué tecnología se sirve.

/// Etapa canónica del pipeline de ventas.
class EtapaPipeline {
  final String clave;
  final String nombre;
  final int orden;

  /// La mueve un hecho del sistema (oferta emitida, apartado aplicado, estatus
  /// de la propiedad). El agente no puede asignarla a mano: se pinta con
  /// candado y no acepta arrastre.
  final bool automatica;

  const EtapaPipeline({
    required this.clave,
    required this.nombre,
    this.orden = 0,
    this.automatica = false,
  });

  factory EtapaPipeline.fromJson(Map<String, dynamic> j) => EtapaPipeline(
    clave: (j['clave'] ?? '') as String,
    nombre: (j['label'] ?? j['nombre'] ?? j['clave'] ?? '') as String,
    orden: intDe(j['orden']) ?? 0,
    automatica: j['automatica'] == true,
  );

  /// Etapa de cierre perdido: la única manual que además pide una razón.
  bool get esPerdido => clave == 'perdido';
}

/// Prospecto del negocio.
class LeadNegocio {
  final int? idPersona;
  final String nombre;
  final String? email;
  final String? telefono;
  final String clavePaisTelefono;

  const LeadNegocio({
    this.idPersona,
    this.nombre = 'Sin prospecto',
    this.email,
    this.telefono,
    this.clavePaisTelefono = 'MX',
  });

  factory LeadNegocio.fromJson(Map<String, dynamic> j) => LeadNegocio(
    idPersona: intDe(j['id_persona']),
    nombre: (j['nombre'] as String?)?.trim().isNotEmpty == true
        ? j['nombre'] as String
        : 'Sin prospecto',
    email: j['email'] as String?,
    telefono: j['telefono'] as String?,
    clavePaisTelefono: (j['clave_pais_telefono'] as String?) ?? 'MX',
  );
}

/// Razón ya registrada de por qué un negocio cerrado no avanzó.
class RazonNoAvance {
  final int idMotivo;
  final String motivoNombre;
  final String motivoClave;
  final String? comentario;
  final String? registradoPor;
  final DateTime? fecha;

  const RazonNoAvance({
    required this.idMotivo,
    this.motivoNombre = '',
    this.motivoClave = '',
    this.comentario,
    this.registradoPor,
    this.fecha,
  });

  factory RazonNoAvance.fromJson(Map<String, dynamic> j) => RazonNoAvance(
    idMotivo: intDe(j['id_motivo']) ?? 0,
    motivoNombre: (j['motivo_nombre'] as String?) ?? '',
    motivoClave: (j['motivo_clave'] as String?) ?? '',
    comentario: j['comentario'] as String?,
    registradoPor: j['registrado_por'] as String?,
    fecha: DateTime.tryParse('${j['fecha'] ?? ''}'),
  );
}

/// Motivo del catálogo de razones de no avance.
class MotivoNoAvance {
  final int id;
  final String clave;
  final String nombre;
  final String? descripcion;

  /// Sin detalle escrito el motivo no se puede guardar.
  final bool requiereComentario;

  /// `false` = cierre definitivo (se fue con la competencia, oferta duplicada).
  final bool esRecuperable;

  final int orden;

  const MotivoNoAvance({
    required this.id,
    required this.clave,
    required this.nombre,
    this.descripcion,
    this.requiereComentario = false,
    this.esRecuperable = true,
    this.orden = 0,
  });

  factory MotivoNoAvance.fromJson(Map<String, dynamic> j) => MotivoNoAvance(
    id: intDe(j['id']) ?? 0,
    clave: (j['clave'] ?? '') as String,
    nombre: (j['nombre'] ?? '') as String,
    descripcion: j['descripcion'] as String?,
    requiereComentario: j['requiere_comentario'] == true,
    esRecuperable: j['es_recuperable'] != false,
    orden: intDe(j['orden']) ?? 0,
  );
}

/// Catálogo de razones de no avance.
class CatalogoRazones {
  /// `false` = el catálogo todavía no está habilitado en el ambiente: las
  /// opciones se pueden leer pero no se puede registrar ninguna razón.
  final bool disponible;
  final List<MotivoNoAvance> motivos;

  const CatalogoRazones({this.disponible = false, this.motivos = const []});

  factory CatalogoRazones.fromJson(Map<String, dynamic> j) => CatalogoRazones(
    disponible: j['disponible'] == true,
    motivos: listaDe(j['motivos']).map(MotivoNoAvance.fromJson).toList(),
  );
}

/// Un negocio: una unidad con la oferta que la representa.
class Negocio {
  /// Oferta representativa del negocio (la de la etapa más avanzada).
  final int idOferta;

  /// Negocio del pipeline. **Puede ser null**: sin él no hay a dónde mover la
  /// etapa, así que el arrastre y el selector quedan deshabilitados.
  final int? idNegocio;

  final int? idPropiedad;
  final int? idProducto;
  final bool esProducto;

  /// `O-000123` propiedad · `OP-000123` producto.
  final String folio;

  final String proyectoNombre;
  final String unidad;
  final LeadNegocio lead;
  final double? precio;

  /// Clave de la etapa actual ([EtapaPipeline.clave]).
  final String etapa;

  final DateTime? fechaGeneracion;
  final int? idCuentaCobranza;

  /// `CC-000123` / `CCP-000123`, null si la oferta no llegó a cuenta.
  final String? cuentaFolio;

  /// Credencial del link del cliente; sin ella el link solo sirve de vista previa.
  final String? reservaToken;

  final bool tieneContratoFirmado;
  final RazonNoAvance? razonNoAvance;
  final String inmobiliariaNombre;

  /// Cuántas ofertas (recotizaciones) hay sobre la misma unidad.
  final int ofertasCount;
  final List<int> ofertasIds;

  final String urlCliente;
  final String urlPreview;

  const Negocio({
    required this.idOferta,
    required this.folio,
    this.idNegocio,
    this.idPropiedad,
    this.idProducto,
    this.esProducto = false,
    this.proyectoNombre = '',
    this.unidad = '',
    this.lead = const LeadNegocio(),
    this.precio,
    this.etapa = '',
    this.fechaGeneracion,
    this.idCuentaCobranza,
    this.cuentaFolio,
    this.reservaToken,
    this.tieneContratoFirmado = false,
    this.razonNoAvance,
    this.inmobiliariaNombre = '',
    this.ofertasCount = 1,
    this.ofertasIds = const [],
    this.urlCliente = '',
    this.urlPreview = '',
  });

  factory Negocio.fromJson(Map<String, dynamic> j) => Negocio(
    idOferta: intDe(j['id_oferta']) ?? intDe(j['id']) ?? 0,
    idNegocio: intDe(j['id_negocio']),
    idPropiedad: intDe(j['id_propiedad']),
    idProducto: intDe(j['id_producto']),
    esProducto: j['es_producto'] == true,
    folio: (j['folio'] ?? '') as String,
    proyectoNombre: (j['proyecto_nombre'] as String?) ?? '',
    unidad: (j['unidad'] as String?) ?? '',
    lead: LeadNegocio.fromJson(mapaDe(j['lead'])),
    precio: j['precio'] == null ? null : numDe(j['precio']),
    etapa: (j['etapa'] ?? '') as String,
    fechaGeneracion: DateTime.tryParse('${j['fecha_generacion'] ?? ''}'),
    idCuentaCobranza: intDe(j['id_cuenta_cobranza']),
    cuentaFolio: j['cuenta_label'] as String?,
    reservaToken: j['reserva_token'] as String?,
    tieneContratoFirmado: j['tiene_contrato_firmado'] == true,
    razonNoAvance: j['no_avance'] == null
        ? null
        : RazonNoAvance.fromJson(mapaDe(j['no_avance'])),
    inmobiliariaNombre: (j['inmobiliaria_nombre'] as String?) ?? '',
    ofertasCount: intDe(j['ofertas_count']) ?? 1,
    ofertasIds:
        (j['ofertas_ids'] as List?)?.map(intDe).whereType<int>().toList() ??
        const [],
    urlCliente: (j['url_cliente'] as String?) ?? '',
    urlPreview: (j['url_preview'] as String?) ?? '',
  );

  /// El link que se comparte apunta al cliente solo si hay token; sin token es
  /// vista previa y no permite apartar.
  bool get tieneLinkCliente => (reservaToken ?? '').isNotEmpty;

  /// Se puede mover de etapa a mano: existe en el pipeline.
  bool get sePuedeMover => idNegocio != null;

  Negocio copyWith({String? etapa, RazonNoAvance? razonNoAvance}) => Negocio(
    idOferta: idOferta,
    idNegocio: idNegocio,
    idPropiedad: idPropiedad,
    idProducto: idProducto,
    esProducto: esProducto,
    folio: folio,
    proyectoNombre: proyectoNombre,
    unidad: unidad,
    lead: lead,
    precio: precio,
    etapa: etapa ?? this.etapa,
    fechaGeneracion: fechaGeneracion,
    idCuentaCobranza: idCuentaCobranza,
    cuentaFolio: cuentaFolio,
    reservaToken: reservaToken,
    tieneContratoFirmado: tieneContratoFirmado,
    razonNoAvance: razonNoAvance ?? this.razonNoAvance,
    inmobiliariaNombre: inmobiliariaNombre,
    ofertasCount: ofertasCount,
    ofertasIds: ofertasIds,
    urlCliente: urlCliente,
    urlPreview: urlPreview,
  );
}

/// Cifras del encabezado: "N negocios · N ofertas · $X abiertos".
class ResumenPipeline {
  final int negocios;
  final int ofertas;
  final double montoAbierto;

  /// Negocios cerrados como perdidos a los que nadie les capturó la razón.
  final int cerradosSinRazon;

  const ResumenPipeline({
    this.negocios = 0,
    this.ofertas = 0,
    this.montoAbierto = 0,
    this.cerradosSinRazon = 0,
  });

  factory ResumenPipeline.fromJson(Map<String, dynamic> j) => ResumenPipeline(
    negocios: intDe(j['negocios']) ?? 0,
    ofertas: intDe(j['ofertas']) ?? 0,
    montoAbierto: numDe(j['monto_abierto']),
    cerradosSinRazon: intDe(j['cerrados_sin_razon']) ?? 0,
  );
}

/// Todo lo que la pantalla necesita para pintarse: etapas, negocios, cifras y
/// el catálogo de razones.
class PipelineAgente {
  final List<EtapaPipeline> etapas;
  final List<Negocio> negocios;
  final ResumenPipeline resumen;
  final CatalogoRazones catalogoRazones;

  const PipelineAgente({
    this.etapas = const [],
    this.negocios = const [],
    this.resumen = const ResumenPipeline(),
    this.catalogoRazones = const CatalogoRazones(),
  });

  factory PipelineAgente.fromJson(Map<String, dynamic> j) => PipelineAgente(
    etapas: listaDe(j['etapas']).map(EtapaPipeline.fromJson).toList(),
    negocios: listaDe(j['negocios']).map(Negocio.fromJson).toList(),
    resumen: ResumenPipeline.fromJson(mapaDe(j['resumen'])),
    catalogoRazones: CatalogoRazones.fromJson(mapaDe(j['catalogo_no_avance'])),
  );

  /// Definición de una etapa por su clave; null si el ambiente no la tiene.
  EtapaPipeline? etapaDe(String clave) {
    for (final e in etapas) {
      if (e.clave == clave) return e;
    }
    return null;
  }
}

/// Propiedad de la oferta, en el detalle.
class PropiedadOferta {
  final int id;
  final String numero;
  final double? precioLista;

  const PropiedadOferta({
    required this.id,
    this.numero = '',
    this.precioLista,
  });

  factory PropiedadOferta.fromJson(Map<String, dynamic> j) => PropiedadOferta(
    id: intDe(j['id']) ?? 0,
    numero: (j['numero_propiedad'] as String?) ?? '',
    precioLista: j['precio_lista'] == null ? null : numDe(j['precio_lista']),
  );
}

/// Bodega o estacionamiento ligado a la propiedad.
class AsociadoUnidad {
  /// `bodega` · `estacionamiento`.
  final String tipo;
  final String nombre;

  /// `true` = ya viene en el precio; `false` = genera una oferta adicional.
  final bool esIncluido;

  final double precio;

  const AsociadoUnidad({
    required this.tipo,
    this.nombre = '',
    this.esIncluido = false,
    this.precio = 0,
  });

  factory AsociadoUnidad.fromJson(Map<String, dynamic> j) => AsociadoUnidad(
    tipo: (j['tipo'] ?? '') as String,
    nombre: (j['nombre'] as String?) ?? '',
    esIncluido: j['es_incluido'] == true,
    precio: numDe(j['precio']),
  );
}

/// Esquema de pago seleccionable en el detalle de la oferta. Los porcentajes se
/// guardan como los captura el administrador (0-100), no como fracción.
class EsquemaPago {
  final int id;
  final String nombre;
  final double porcentajeEnganche;
  final double porcentajeMensualidades;
  final double porcentajeEntrega;
  final int numeroMensualidades;

  /// Ajuste sobre el precio de lista: negativo descuenta, positivo encarece.
  final double porcentajeDescuentoAumento;

  const EsquemaPago({
    required this.id,
    this.nombre = '',
    this.porcentajeEnganche = 0,
    this.porcentajeMensualidades = 0,
    this.porcentajeEntrega = 0,
    this.numeroMensualidades = 1,
    this.porcentajeDescuentoAumento = 0,
  });

  factory EsquemaPago.fromJson(Map<String, dynamic> j) => EsquemaPago(
    id: intDe(j['id']) ?? 0,
    nombre: (j['nombre'] as String?) ?? '',
    porcentajeEnganche: numDe(j['porcentaje_enganche']),
    porcentajeMensualidades: numDe(j['porcentaje_mensualidades']),
    porcentajeEntrega: numDe(j['porcentaje_entrega']),
    numeroMensualidades: intDe(j['numero_mensualidades']) ?? 1,
    porcentajeDescuentoAumento: numDe(j['porcentaje_descuento_aumento']),
  );

  /// Precio con el ajuste del esquema aplicado.
  double precioFinal(double base) =>
      base * (1 + porcentajeDescuentoAumento / 100);

  double enganche(double base) => precioFinal(base) * porcentajeEnganche / 100;

  double entrega(double base) => precioFinal(base) * porcentajeEntrega / 100;

  /// Importe de UNA mensualidad.
  double mensualidad(double base) {
    final meses = numeroMensualidades > 0 ? numeroMensualidades : 1;
    return precioFinal(base) * porcentajeMensualidades / 100 / meses;
  }
}

/// Link digital de la oferta.
class LinkCliente {
  /// Credencial del cliente; null = solo hay vista previa.
  final String? token;

  /// Link con token, null si no hay token.
  final String? url;

  /// Link sin token: sirve para mostrar la oferta, no para apartar.
  final String urlPreview;

  const LinkCliente({this.token, this.url, this.urlPreview = ''});

  factory LinkCliente.fromJson(Map<String, dynamic> j) => LinkCliente(
    token: j['token'] as String?,
    url: j['url'] as String?,
    urlPreview: (j['url_preview'] as String?) ?? '',
  );

  bool get vigente => (token ?? '').isNotEmpty && (url ?? '').isNotEmpty;

  /// Lo que se comparte: el link del cliente si existe, la vista previa si no.
  String get urlCompartible => vigente ? url! : urlPreview;
}

/// Detalle de una oferta del pipeline.
class OfertaDetalle {
  final int idOferta;
  final bool esProducto;
  final String folio;
  final PropiedadOferta? propiedad;
  final List<AsociadoUnidad> asociados;
  final List<EsquemaPago> esquemas;
  final LinkCliente link;

  /// El esquema ya está elegido: no se puede cambiar desde el portal.
  final bool yaTieneEsquema;

  final int? idEsquemaSeleccionado;

  const OfertaDetalle({
    required this.idOferta,
    this.esProducto = false,
    this.folio = '',
    this.propiedad,
    this.asociados = const [],
    this.esquemas = const [],
    this.link = const LinkCliente(),
    this.yaTieneEsquema = false,
    this.idEsquemaSeleccionado,
  });

  factory OfertaDetalle.fromJson(Map<String, dynamic> j) => OfertaDetalle(
    idOferta: intDe(j['id_oferta']) ?? 0,
    esProducto: j['es_producto'] == true,
    folio: (j['folio'] as String?) ?? '',
    propiedad: j['propiedad'] == null
        ? null
        : PropiedadOferta.fromJson(mapaDe(j['propiedad'])),
    asociados: listaDe(j['asociados']).map(AsociadoUnidad.fromJson).toList(),
    esquemas: listaDe(j['esquemas']).map(EsquemaPago.fromJson).toList(),
    link: LinkCliente.fromJson(mapaDe(j['link_digital'])),
    yaTieneEsquema: j['ya_tiene_esquema'] == true,
    idEsquemaSeleccionado: intDe(j['id_esquema_pago_seleccionado']),
  );

  /// Asociados que NO vienen incluidos: suman al total de la unidad.
  List<AsociadoUnidad> get adicionales =>
      asociados.where((a) => !a.esIncluido).toList(growable: false);

  double get totalAdicionales =>
      adicionales.fold<double>(0, (s, a) => s + a.precio);
}

/// Resultado de elegir el esquema de pago.
class CambioEsquema {
  final int idEsquemaSeleccionado;

  /// `true` regenerados · `false` falló la regeneración (hay que pedirla a
  /// cobranza) · `null` la oferta no tiene cuenta, no había acuerdos que
  /// regenerar. Los tres se le comunican distinto al agente.
  final bool? acuerdosRegenerados;

  const CambioEsquema({
    required this.idEsquemaSeleccionado,
    this.acuerdosRegenerados,
  });

  factory CambioEsquema.fromJson(Map<String, dynamic> j) => CambioEsquema(
    idEsquemaSeleccionado: intDe(j['id_esquema_pago_seleccionado']) ?? 0,
    acuerdosRegenerados: j['acuerdos_regenerados'] as bool?,
  );
}

/// La acción no se puede intentar: la bloquea el estado del negocio, no el
/// servidor. Se resuelve en el app para no mandar una llamada que va a fallar.
class AccionNoDisponible implements Exception {
  /// Motivo en snake_case, traducido por `services/pipeline_textos.dart`
  /// (`negocio_sin_pipeline`, `etapa_automatica`, `catalogo_no_disponible`,
  /// `sin_permiso`).
  final String motivo;

  AccionNoDisponible(this.motivo);

  @override
  String toString() => 'AccionNoDisponible($motivo)';
}

/// Pipeline de negocios del agente. Todos los métodos lanzan [ApiError].
abstract interface class PipelinePort {
  /// Negocios del agente desde [desde] (por omisión, el último mes).
  Future<PipelineAgente> negocios({DateTime? desde});

  /// Detalle de una oferta: propiedad, asociados, esquemas y link del cliente.
  Future<OfertaDetalle> detalleOferta(int idOferta);

  /// Mueve un negocio a una etapa manual. Falla con `stage_not_manual` en las
  /// automáticas y con `pipeline_unavailable` si el ambiente no tiene pipeline.
  Future<void> moverEtapa({
    required int idNegocio,
    required String claveEtapa,
  });

  /// Registra (o corrige) la razón por la que un negocio cerrado no avanzó.
  Future<RazonNoAvance> registrarRazonNoAvance({
    required int idOferta,
    required int idMotivo,
    String? comentario,
  });

  /// Fija el esquema de pago de la oferta y regenera sus acuerdos si ya tiene
  /// cuenta de cobranza.
  Future<CambioEsquema> elegirEsquemaPago({
    required int idOferta,
    required int idEsquema,
  });

  /// Emite el link del cliente de una oferta que todavía no lo tiene.
  Future<LinkCliente> generarLinkCliente({
    required int idOferta,
    String? email,
  });
}
