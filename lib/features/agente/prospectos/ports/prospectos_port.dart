import 'dart:typed_data';

import 'package:sozu_agente_app/shared/json.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Estado de un lead. El catálogo es administrable en la plataforma, así que
/// nombre y color llegan del servidor y nunca se cocinan en el app.
class EstadoLead {
  final int id;
  final String clave;
  final String nombre;

  /// Color del catálogo en hexadecimal (`#f59e0b`); null cuando no se definió.
  final String? color;

  const EstadoLead({
    required this.id,
    required this.clave,
    required this.nombre,
    this.color,
  });

  factory EstadoLead.fromJson(Map<String, dynamic> j) => EstadoLead(
    id: intDe(j['id']) ?? 0,
    clave: (j['clave'] ?? '') as String,
    nombre: (j['nombre'] ?? '') as String,
    color: j['color'] as String?,
  );
}

/// Unidad (propiedad o producto) en la que el prospecto tiene un negocio
/// abierto. Es el grano de negocio: varias ofertas sobre la misma unidad se
/// colapsan en una fila y [ofertas] dice cuántas recotizaciones hubo.
class UnidadDeProspecto {
  final int? idNegocio;
  final int? idOferta;

  /// Número de propiedad o nombre del producto.
  final String unidad;

  /// "Propiedad", "Bodega", "Estacionamiento"…
  final String tipo;

  /// Precio final de la cuenta o precio de lista; null cuando no hay ninguno.
  final double? valor;

  /// Clave de etapa del pipeline (`oferta_enviada`, `apartado_pagado`…).
  final String etapa;

  /// La unidad ya pasó de prospecto a compra (apartado pagado en adelante).
  final bool esCliente;

  final int ofertas;

  const UnidadDeProspecto({
    required this.unidad,
    required this.tipo,
    required this.etapa,
    this.idNegocio,
    this.idOferta,
    this.valor,
    this.esCliente = false,
    this.ofertas = 1,
  });

  factory UnidadDeProspecto.fromJson(Map<String, dynamic> j) =>
      UnidadDeProspecto(
        idNegocio: intDe(j['id_negocio']),
        idOferta: intDe(j['id_oferta']),
        unidad: (j['unidad'] ?? '-') as String,
        tipo: (j['tipo'] ?? 'Propiedad') as String,
        valor: j['valor'] == null ? null : numDe(j['valor']),
        etapa: (j['etapa'] ?? 'oferta_enviada') as String,
        esCliente: j['es_cliente'] == true,
        ofertas: intDe(j['ofertas_count']) ?? 1,
      );
}

/// Interés del prospecto en UN desarrollo. Es la fila persona × desarrollo del
/// CRM: el estado del lead y la transferencia a otro agente se hacen por aquí,
/// no por persona, porque el mismo prospecto puede ir a distinta velocidad en
/// cada desarrollo.
class DesarrolloDeProspecto {
  /// Id de la relación persona × desarrollo. Es lo que identifica al lead en
  /// las operaciones de estado y transferencia.
  final int idRelacion;

  final int? idDesarrollo;
  final String desarrollo;
  final int? idEstadoLead;
  final String? estado;

  /// Color del estado en hexadecimal; null cuando el catálogo no lo define.
  final String? estadoColor;

  final List<UnidadDeProspecto> unidades;

  const DesarrolloDeProspecto({
    required this.idRelacion,
    required this.desarrollo,
    this.idDesarrollo,
    this.idEstadoLead,
    this.estado,
    this.estadoColor,
    this.unidades = const [],
  });

  factory DesarrolloDeProspecto.fromJson(Map<String, dynamic> j) =>
      DesarrolloDeProspecto(
        idRelacion: intDe(j['id_entidad_relacionada']) ?? 0,
        idDesarrollo: intDe(j['id_proyecto']),
        desarrollo: (j['proyecto'] ?? 'Sin desarrollo') as String,
        idEstadoLead: intDe(j['id_estatus_lead']),
        estado: j['estatus'] as String?,
        estadoColor: j['estatus_color'] as String?,
        unidades: listaDe(
          j['unidades'],
        ).map(UnidadDeProspecto.fromJson).toList(growable: false),
      );
}

/// Fila de la cartera: una persona con todos sus desarrollos de interés.
class Prospecto {
  final int idPersona;
  final String nombre;
  final String? email;
  final String? telefono;
  final String? clavePaisTelefono;

  /// Ya compró en alguna de sus unidades: la fila lleva el distintivo "Cliente".
  final bool esCliente;

  final int totalUnidades;
  final List<DesarrolloDeProspecto> desarrollos;

  const Prospecto({
    required this.idPersona,
    required this.nombre,
    this.email,
    this.telefono,
    this.clavePaisTelefono,
    this.esCliente = false,
    this.totalUnidades = 0,
    this.desarrollos = const [],
  });

  factory Prospecto.fromJson(Map<String, dynamic> j) => Prospecto(
    idPersona: intDe(j['id_persona']) ?? 0,
    nombre: (j['nombre'] ?? 'Sin nombre') as String,
    email: j['email'] as String?,
    telefono: j['telefono'] as String?,
    clavePaisTelefono: j['clave_pais_telefono'] as String?,
    esCliente: j['es_cliente'] == true,
    totalUnidades: intDe(j['total_unidades']) ?? 0,
    desarrollos: listaDe(
      j['proyectos'],
    ).map(DesarrolloDeProspecto.fromJson).toList(growable: false),
  );
}

/// Cartera del agente: catálogo de estados + filas.
///
/// [modeloDeTransicion] avisa que la cartera se armó uniendo el dueño del lead
/// con la atribución del CRM en vez de leerse ya resuelta. Se muestra al agente
/// porque explica por qué un lead recién movido puede tardar en acomodarse.
class CarteraProspectos {
  final List<EstadoLead> catalogoEstados;
  final List<Prospecto> prospectos;
  final bool modeloDeTransicion;

  const CarteraProspectos({
    this.catalogoEstados = const [],
    this.prospectos = const [],
    this.modeloDeTransicion = false,
  });

  factory CarteraProspectos.fromJson(Map<String, dynamic> j) =>
      CarteraProspectos(
        catalogoEstados: listaDe(
          j['catalogo_estatus'],
        ).map(EstadoLead.fromJson).toList(growable: false),
        prospectos: listaDe(
          j['rows'],
        ).map(Prospecto.fromJson).toList(growable: false),
        modeloDeTransicion: j['via_rpc'] == false,
      );
}

/// Ficha de la persona detrás del prospecto.
class PersonaProspecto {
  final int id;
  final String nombre;
  final String? email;
  final String? telefono;
  final String? clavePaisTelefono;

  /// `pf` (física) o `pm` (moral).
  final String tipoPersona;

  final String? rfc;
  final String? curp;

  const PersonaProspecto({
    required this.id,
    required this.nombre,
    this.email,
    this.telefono,
    this.clavePaisTelefono,
    this.tipoPersona = 'pf',
    this.rfc,
    this.curp,
  });

  factory PersonaProspecto.fromJson(Map<String, dynamic> j) => PersonaProspecto(
    id: intDe(j['id']) ?? 0,
    nombre: (j['nombre'] ?? 'Sin nombre') as String,
    email: j['email'] as String?,
    telefono: j['telefono'] as String?,
    clavePaisTelefono: j['clave_pais_telefono'] as String?,
    tipoPersona: (j['tipo_persona'] ?? 'pf') as String,
    rfc: j['rfc'] as String?,
    curp: j['curp'] as String?,
  );

  bool get esPersonaMoral => tipoPersona == 'pm';
}

/// Desarrollo de interés del prospecto, tal como se lista en su ficha.
class DesarrolloDeInteres {
  final int idRelacion;
  final int? idDesarrollo;
  final String nombre;

  const DesarrolloDeInteres({
    required this.idRelacion,
    required this.nombre,
    this.idDesarrollo,
  });

  factory DesarrolloDeInteres.fromJson(Map<String, dynamic> j) =>
      DesarrolloDeInteres(
        idRelacion: intDe(j['id']) ?? 0,
        idDesarrollo: intDe(j['id_proyecto']),
        nombre: (j['nombre'] ?? 'Sin desarrollo') as String,
      );
}

/// Oferta digital del prospecto y el enlace que se le manda.
class OfertaDigital {
  final int id;
  final DateTime? fecha;

  /// Unidad de la oferta; vacío en ofertas de producto.
  final String unidad;

  final int? idProducto;

  /// Enlace que ve el cliente. Siempre viene armado, con o sin token.
  final String urlCliente;

  /// Ya tiene cuenta de cobranza: la unidad dejó de estar disponible y el
  /// enlace ya no lleva al pago.
  final bool tieneCuenta;

  /// Sin token de reservación no hay enlace personalizado para el cliente.
  final bool tieneLinkCliente;

  const OfertaDigital({
    required this.id,
    required this.urlCliente,
    this.fecha,
    this.unidad = '',
    this.idProducto,
    this.tieneCuenta = false,
    this.tieneLinkCliente = false,
  });

  factory OfertaDigital.fromJson(Map<String, dynamic> j) {
    final token = j['token'] as String?;
    return OfertaDigital(
      id: intDe(j['id']) ?? 0,
      fecha: DateTime.tryParse('${j['fecha_generacion'] ?? ''}'),
      unidad: (j['propiedad_nombre'] ?? '') as String,
      idProducto: intDe(j['id_producto']),
      urlCliente: (j['url_cliente'] ?? '') as String,
      tieneCuenta: j['tiene_cuenta'] == true,
      tieneLinkCliente: token != null && token.isNotEmpty,
    );
  }
}

/// Archivo pegado a una nota, con su enlace temporal ya firmado por el servidor.
class AdjuntoNota {
  final String nombre;
  final String url;
  final bool esImagen;

  const AdjuntoNota({
    required this.nombre,
    required this.url,
    this.esImagen = false,
  });

  factory AdjuntoNota.fromJson(Map<String, dynamic> j) => AdjuntoNota(
    nombre: (j['nombre'] ?? 'Archivo') as String,
    url: (j['url'] ?? '') as String,
    esImagen: j['es_imagen'] == true,
  );
}

/// Qué originó un movimiento de la actividad del prospecto.
enum TipoActividad {
  /// Nota interna del agente. Es la única editable y borrable.
  nota,

  /// Cita o visita agendada.
  cita,

  /// Oferta generada.
  oferta,
}

/// Movimiento del historial del prospecto (notas, citas y ofertas en una sola
/// línea de tiempo, ordenada de lo más reciente a lo más viejo).
class ActividadProspecto {
  final TipoActividad tipo;
  final DateTime? fecha;
  final String titulo;

  /// Texto plano del movimiento. En una nota es su contenido sin formato; se usa
  /// como respaldo cuando [html] viene vacío.
  final String detalle;

  /// Contenido con formato de la nota, con las URLs de sus archivos ya firmadas.
  /// Vacío en citas y ofertas. Es lo que se conserva al editar: reescribir la
  /// nota desde [detalle] pierde el formato escrito en el portal web.
  final String html;

  final String? autor;

  /// Id de la nota; null en citas y ofertas.
  final int? idNota;

  final List<AdjuntoNota> adjuntos;

  const ActividadProspecto({
    required this.tipo,
    required this.titulo,
    this.fecha,
    this.detalle = '',
    this.html = '',
    this.autor,
    this.idNota,
    this.adjuntos = const [],
  });

  factory ActividadProspecto.fromJson(Map<String, dynamic> j) =>
      ActividadProspecto(
        tipo: switch (j['kind']) {
          'cita' => TipoActividad.cita,
          'oferta' => TipoActividad.oferta,
          _ => TipoActividad.nota,
        },
        titulo: (j['titulo'] ?? '') as String,
        fecha: DateTime.tryParse('${j['fecha'] ?? ''}'),
        detalle: (j['detalle'] ?? '') as String,
        html: (j['html'] ?? '') as String,
        autor: j['autor'] as String?,
        idNota: intDe(j['id_nota']),
        adjuntos: listaDe(
          j['adjuntos'],
        ).map(AdjuntoNota.fromJson).toList(growable: false),
      );

  /// Solo las notas propias se pueden editar o borrar.
  bool get esNotaPropia => tipo == TipoActividad.nota && idNota != null;

  /// La nota no cabe recortada en la línea de tiempo y merece "Ver detalle".
  /// Mismo criterio que el portal web: 140 caracteres o una imagen dentro.
  bool get notaLarga =>
      detalle.length > 140 || html.toLowerCase().contains('<img');
}

/// Ficha completa de un prospecto.
class DetalleProspecto {
  final PersonaProspecto persona;
  final List<DesarrolloDeInteres> desarrollos;
  final List<OfertaDigital> ofertas;
  final List<ActividadProspecto> actividad;

  const DetalleProspecto({
    required this.persona,
    this.desarrollos = const [],
    this.ofertas = const [],
    this.actividad = const [],
  });

  factory DetalleProspecto.fromJson(Map<String, dynamic> j) => DetalleProspecto(
    persona: PersonaProspecto.fromJson(mapaDe(j['persona'])),
    desarrollos: listaDe(
      j['entidades'],
    ).map(DesarrolloDeInteres.fromJson).toList(growable: false),
    ofertas: listaDe(
      j['ofertas'],
    ).map(OfertaDigital.fromJson).toList(growable: false),
    actividad: listaDe(
      j['timeline'],
    ).map(ActividadProspecto.fromJson).toList(growable: false),
  );
}

/// Agente al que se le puede transferir un prospecto.
class AgenteDestino {
  /// Identificador del agente destino tal como lo espera la transferencia.
  final String id;

  final String nombre;
  final String? email;
  final String? rol;

  const AgenteDestino({
    required this.id,
    required this.nombre,
    this.email,
    this.rol,
  });

  factory AgenteDestino.fromJson(Map<String, dynamic> j) => AgenteDestino(
    id: (j['auth_user_id'] ?? '') as String,
    nombre: (j['nombre'] ?? 'Sin nombre') as String,
    email: j['email'] as String?,
    rol: j['rol'] as String?,
  );

  /// "Nombre · Rol" para el selector.
  String get etiqueta =>
      rol == null || rol!.isEmpty ? nombre : '$nombre · $rol';
}

/// Desarrollo que el agente puede ligar a un prospecto.
class DesarrolloVinculable {
  final int id;
  final String nombre;

  const DesarrolloVinculable({required this.id, required this.nombre});
}

/// Datos de la persona que el alta y la edición mandan. Validarlos antes de
/// enviarlos es cortesía: el servidor los vuelve a validar y responde con el
/// código del campo que falló.
class DatosProspecto {
  final String tipoPersona;
  final String nombre;
  final String email;
  final String telefono;
  final String clavePaisTelefono;
  final String? rfc;
  final String? curp;

  const DatosProspecto({
    required this.nombre,
    required this.email,
    required this.telefono,
    this.tipoPersona = 'pf',
    this.clavePaisTelefono = 'MX',
    this.rfc,
    this.curp,
  });
}

/// Archivo que se está pegando a una nota nueva.
class AdjuntoNuevo {
  final String nombre;
  final String contentType;
  final Uint8List bytes;

  const AdjuntoNuevo({
    required this.nombre,
    required this.contentType,
    required this.bytes,
  });
}

/// Cartera de prospectos del agente (CRM): quién es, en qué desarrollo va, en
/// qué estado está y qué se ha hecho con él.
///
/// La instancia queda atada al agente que se está viendo (el propio, o el
/// impersonado por un administrador), así que ningún método recibe ese target:
/// el servidor lo deriva de la sesión y mandarlo desde el app no cambiaría nada.
/// Todos los métodos lanzan [ApiError] con el código de negocio del servidor
/// (`not_owner`, `email_duplicado`, `telefono_invalido`…).
abstract interface class ProspectosPort {
  /// Cartera del agente con el catálogo de estados. [limite] y [desde] paginan.
  Future<CarteraProspectos> cartera({
    String? busqueda,
    int? idEstadoLead,
    int? idDesarrollo,
    int limite,
    int desde,
  });

  /// Ficha del prospecto: persona, desarrollos, ofertas digitales y actividad.
  Future<DetalleProspecto> detalle(int idPersona);

  /// Da de alta el prospecto y lo liga a [desarrollos]. Devuelve su id de
  /// persona. Una persona que ya existe (mismo correo) se reusa, no se duplica.
  Future<int> crear({
    required DatosProspecto datos,
    required List<int> desarrollos,
  });

  /// Actualiza los datos del prospecto. [desarrollos] es la lista COMPLETA de
  /// intereses: lo que no venga se da de baja. null los deja como están.
  Future<void> editar({
    required int idPersona,
    required DatosProspecto datos,
    List<int>? desarrollos,
  });

  /// Mueve el estado del lead en UN desarrollo.
  Future<void> cambiarEstadoLead({
    required int idRelacion,
    required int idEstadoLead,
  });

  /// Pasa el lead a otro agente. El prospecto deja de aparecer en la cartera de
  /// quien lo cede y queda registro del traspaso.
  Future<void> transferir({
    required int idRelacion,
    required String idAgenteDestino,
    String? motivo,
  });

  /// Agentes a los que se puede transferir un prospecto.
  Future<List<AgenteDestino>> agentesDestino();

  /// Desarrollos que el agente puede ligar a un prospecto.
  Future<List<DesarrolloVinculable>> desarrollosVinculables();

  /// Agrega una nota al prospecto. Con [idRelacion] queda en ese desarrollo;
  /// sin él, en el primero del prospecto. Las notas son privadas de su autor.
  Future<void> agregarNota({
    required int idPersona,
    int? idRelacion,
    String texto = '',
    List<AdjuntoNuevo> adjuntos = const [],
  });

  /// Reemplaza el contenido de una nota propia. [adjuntos] son los archivos que
  /// deben quedar pegados: el contenido se reescribe completo, así que omitir uno
  /// lo desprende de la nota.
  ///
  /// [cuerpoConFormato] es el contenido original de la nota SIN sus archivos;
  /// mandarlo conserva negritas, listas y colores escritos en el portal web. Con
  /// null el cuerpo se reescribe desde [texto] y el formato se pierde.
  Future<void> editarNota({
    required int idNota,
    required String texto,
    String? cuerpoConFormato,
    List<AdjuntoNota> adjuntos = const [],
  });

  /// Borra una nota propia. El borrado es lógico: la nota se conserva para
  /// auditoría y deja de mostrarse.
  Future<void> eliminarNota(int idNota);
}
