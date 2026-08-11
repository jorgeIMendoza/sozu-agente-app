/// Inventario comercial del portal del agente: los desarrollos que puede
/// vender, la ficha de cada uno, las unidades disponibles y los planos de una
/// unidad.
///
/// El universo visible lo decide SIEMPRE el servidor (los proyectos asignados
/// al agente). El app nunca manda a quién pertenece la consulta: si un agente
/// no tiene proyectos asignados, [InventarioPort.desarrollos] devuelve lista
/// vacía y eso es un resultado válido, no un error.
library;

import 'package:sozu_agente_app/shared/json.dart';

// ---------------------------------------------------------------------------
// Vista de desarrollos
// ---------------------------------------------------------------------------

/// Tarjeta de un desarrollo en la lista de inventario.
class DesarrolloResumen {
  final int id;
  final String nombre;
  final String ubicacion;
  final String? imagenUrl;

  /// Precio de la unidad disponible más barata; null si no hay disponibles.
  final double? precioDesde;

  final int unidadesDisponibles;
  final int totalUnidades;

  /// Avance de obra en porcentaje (0-100).
  final int avancePct;

  /// Etapa de obra vigente según el catálogo; null si el desarrollo no la tiene.
  final String? estatus;

  /// Ficha pública del desarrollo en sozu.com, lo que se comparte al cliente.
  final String urlPublica;

  const DesarrolloResumen({
    required this.id,
    required this.nombre,
    this.ubicacion = '',
    this.imagenUrl,
    this.precioDesde,
    this.unidadesDisponibles = 0,
    this.totalUnidades = 0,
    this.avancePct = 0,
    this.estatus,
    this.urlPublica = '',
  });

  factory DesarrolloResumen.fromJson(Map<String, dynamic> j) =>
      DesarrolloResumen(
        id: intDe(j['id']) ?? 0,
        nombre: (j['nombre'] ?? '') as String,
        ubicacion: (j['ubicacion'] ?? '') as String,
        imagenUrl: _texto(j['imagen_url']),
        precioDesde: j['precio_desde'] == null ? null : numDe(j['precio_desde']),
        unidadesDisponibles: intDe(j['unidades_disponibles']) ?? 0,
        totalUnidades: intDe(j['total_unidades']) ?? 0,
        avancePct: intDe(j['avance_pct']) ?? 0,
        estatus: _texto(j['estatus']),
        urlPublica: (j['url_publica'] ?? '') as String,
      );

  bool get agotado => unidadesDisponibles == 0;
}

// ---------------------------------------------------------------------------
// Ficha de un desarrollo
// ---------------------------------------------------------------------------

/// Datos de identidad y ubicación del desarrollo.
class DatosDesarrollo {
  final int id;
  final String nombre;
  final String? descripcion;
  final String? direccion;
  final String? imagenUrl;
  final double? latitud;
  final double? longitud;
  final String? fechaEntrega;
  final String? fechaEntregaProyecto;
  final String? fechaActualizacion;
  final String urlPublica;

  const DatosDesarrollo({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.direccion,
    this.imagenUrl,
    this.latitud,
    this.longitud,
    this.fechaEntrega,
    this.fechaEntregaProyecto,
    this.fechaActualizacion,
    this.urlPublica = '',
  });

  factory DatosDesarrollo.fromJson(Map<String, dynamic> j) => DatosDesarrollo(
    id: intDe(j['id']) ?? 0,
    nombre: (j['nombre'] ?? '') as String,
    descripcion: _texto(j['descripcion']),
    direccion: _texto(j['direccion']),
    imagenUrl: _texto(j['imagen_url']),
    latitud: j['latitud'] == null ? null : numDe(j['latitud']),
    longitud: j['longitud'] == null ? null : numDe(j['longitud']),
    fechaEntrega: _texto(j['fecha_entrega']),
    fechaEntregaProyecto: _texto(j['fecha_entrega_proyecto']),
    fechaActualizacion: _texto(j['fecha_actualizacion']),
    urlPublica: (j['url_publica'] ?? '') as String,
  );

  bool get tieneCoordenadas => latitud != null && longitud != null;
}

/// Showroom de ventas del desarrollo (donde se atiende al cliente).
class Showroom {
  final String? nombre;
  final String? direccion;
  final String? horarios;
  final double? latitud;
  final double? longitud;

  const Showroom({
    this.nombre,
    this.direccion,
    this.horarios,
    this.latitud,
    this.longitud,
  });

  factory Showroom.fromJson(Map<String, dynamic> j) => Showroom(
    nombre: _texto(j['nombre']),
    direccion: _texto(j['direccion']),
    horarios: _texto(j['horarios']),
    latitud: j['latitud'] == null ? null : numDe(j['latitud']),
    longitud: j['longitud'] == null ? null : numDe(j['longitud']),
  );

  bool get tieneCoordenadas => latitud != null && longitud != null;
  bool get vacio => (direccion ?? '').isEmpty && !tieneCoordenadas;
}

/// Una etapa del roadmap de obra, con su porcentaje acumulado.
class EtapaObra {
  final String nombre;
  final int porcentaje;
  final bool completada;

  /// Etapa en la que está el desarrollo hoy (la primera sin completar).
  final bool esActual;

  const EtapaObra({
    required this.nombre,
    this.porcentaje = 0,
    this.completada = false,
    this.esActual = false,
  });

  factory EtapaObra.fromJson(Map<String, dynamic> j) => EtapaObra(
    nombre: (j['etapa'] ?? '') as String,
    porcentaje: intDe(j['pct']) ?? 0,
    completada: j['completada'] == true,
    esActual: j['es_actual'] == true,
  );
}

/// Video de avance de obra publicado para el desarrollo.
class VideoAvance {
  /// URL de reproducción incrustada (`.../embed/<id>`) que entrega el servidor.
  final String urlEmbed;
  final String? nombre;
  final String? fecha;

  const VideoAvance({required this.urlEmbed, this.nombre, this.fecha});

  factory VideoAvance.fromJson(Map<String, dynamic> j) =>
      VideoAvance(
        urlEmbed: (j['url_embed'] ?? '') as String,
        nombre: _texto(j['nombre']),
        fecha: _texto(j['fecha']),
      );

  /// Id del video dentro de la URL incrustada. Vacío si no se puede extraer.
  String get idVideo {
    final partes = urlEmbed.split('/embed/');
    if (partes.length < 2) return '';
    return partes[1].split(RegExp(r'[?&]')).first;
  }

  /// Miniatura pública del video, para no cargar un reproductor sin que el
  /// agente lo pida.
  String? get miniaturaUrl =>
      idVideo.isEmpty ? null : 'https://i.ytimg.com/vi/$idVideo/hqdefault.jpg';

  /// Página de reproducción, que se abre fuera del app (no hay reproductor
  /// incrustado en el portal del agente).
  String? get urlReproduccion =>
      idVideo.isEmpty ? null : 'https://www.youtube.com/watch?v=$idVideo';
}

/// Avance de obra del desarrollo: porcentaje, etapa actual y su roadmap.
class AvanceObra {
  final int porcentaje;
  final String etapaActual;
  final List<EtapaObra> etapas;

  /// Fecha de la última señal de avance (el video más reciente, o el proyecto).
  final String? actualizado;

  final VideoAvance? video;

  const AvanceObra({
    this.porcentaje = 0,
    this.etapaActual = '',
    this.etapas = const [],
    this.actualizado,
    this.video,
  });

  factory AvanceObra.fromJson(Map<String, dynamic> j) => AvanceObra(
    porcentaje: intDe(j['pct']) ?? 0,
    etapaActual: (j['etapa_actual'] ?? '') as String,
    etapas: listaDe(j['milestones']).map(EtapaObra.fromJson).toList(),
    actualizado: _texto(j['actualizado']),
    video: j['video'] == null ? null : VideoAvance.fromJson(mapaDe(j['video'])),
  );

  bool get vacio => porcentaje <= 0 && video == null;
}

/// Amenidad del desarrollo. [foto] es la foto real en el proyecto, no un icono.
class Amenidad {
  final int id;
  final String nombre;
  final String? foto;

  const Amenidad({required this.id, required this.nombre, this.foto});

  factory Amenidad.fromJson(Map<String, dynamic> j) => Amenidad(
    id: intDe(j['id']) ?? 0,
    nombre: (j['nombre'] ?? '') as String,
    foto: _texto(j['foto']),
  );
}

/// Modelo de unidad del desarrollo, con su mínimo disponible y su plano.
class ModeloDesarrollo {
  final int id;
  final String nombre;
  final String? descripcion;
  final double? m2;
  final int recamaras;
  final int banos;
  final int medioBanos;
  final double? precioDesde;
  final int disponibles;
  final String? imagenUrl;

  /// Plano arquitectónico del modelo; URL temporal que entrega el servidor.
  final String? planoUrl;

  /// Galería del modelo: portada, fotos y el plano, sin repetir.
  final List<String> multimedia;

  const ModeloDesarrollo({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.m2,
    this.recamaras = 0,
    this.banos = 0,
    this.medioBanos = 0,
    this.precioDesde,
    this.disponibles = 0,
    this.imagenUrl,
    this.planoUrl,
    this.multimedia = const [],
  });

  factory ModeloDesarrollo.fromJson(Map<String, dynamic> j) =>
      ModeloDesarrollo(
        id: intDe(j['id']) ?? 0,
        nombre: (j['nombre'] ?? '') as String,
        descripcion: _texto(j['descripcion']),
        m2: j['m2'] == null ? null : numDe(j['m2']),
        recamaras: intDe(j['recamaras']) ?? 0,
        banos: intDe(j['banos']) ?? 0,
        medioBanos: intDe(j['medio_banos']) ?? 0,
        precioDesde: j['precio_desde'] == null
            ? null
            : numDe(j['precio_desde']),
        disponibles: intDe(j['disponibles']) ?? 0,
        imagenUrl: _texto(j['imagen_url']),
        planoUrl: _texto(j['plano_url']),
        multimedia: _textos(j['multimedia']),
      );
}

/// Render o vista comercial del desarrollo.
class VistaDesarrollo {
  final int id;
  final String? nombre;
  final String url;

  const VistaDesarrollo({required this.id, this.nombre, required this.url});

  factory VistaDesarrollo.fromJson(Map<String, dynamic> j) => VistaDesarrollo(
    id: intDe(j['id']) ?? 0,
    nombre: _texto(j['nombre']),
    url: (j['url'] ?? '') as String,
  );
}

/// Imagen de la galería del desarrollo. `id` null = la portada del proyecto.
class ImagenGaleria {
  final int? id;
  final String url;

  const ImagenGaleria({this.id, required this.url});

  factory ImagenGaleria.fromJson(Map<String, dynamic> j) =>
      ImagenGaleria(id: intDe(j['id']), url: (j['url'] ?? '') as String);
}

/// Punto de interés cercano al desarrollo, con su distancia.
class PuntoInteres {
  final int id;
  final String nombre;
  final double? distanciaKm;

  const PuntoInteres({
    required this.id,
    required this.nombre,
    this.distanciaKm,
  });

  factory PuntoInteres.fromJson(Map<String, dynamic> j) => PuntoInteres(
    id: intDe(j['id']) ?? 0,
    nombre: (j['nombre'] ?? '') as String,
    distanciaKm: j['distancia_km'] == null ? null : numDe(j['distancia_km']),
  );

  /// "800 m" bajo el kilómetro, "1.4 km" arriba. Null si no hay distancia.
  String? get distanciaTexto {
    final d = distanciaKm;
    if (d == null) return null;
    if (d < 1) return '${(d * 1000).round()} m';
    return '$d km';
  }
}

/// Documento comercial del desarrollo. [url] es temporal y la firma el servidor.
class DocumentoComercial {
  final int id;
  final String? url;

  const DocumentoComercial({required this.id, this.url});

  factory DocumentoComercial.fromJson(Map<String, dynamic> j) =>
      DocumentoComercial(id: intDe(j['id']) ?? 0, url: _texto(j['url']));
}

/// Material comercial que el agente puede mostrarle al cliente.
class MaterialComercial {
  final DocumentoComercial? brochure;
  final DocumentoComercial? fichaTecnica;

  const MaterialComercial({this.brochure, this.fichaTecnica});

  factory MaterialComercial.fromJson(Map<String, dynamic> j) =>
      MaterialComercial(
        brochure: j['brochure'] == null
            ? null
            : DocumentoComercial.fromJson(mapaDe(j['brochure'])),
        fichaTecnica: j['ficha_tecnica'] == null
            ? null
            : DocumentoComercial.fromJson(mapaDe(j['ficha_tecnica'])),
      );

  bool get vacio => brochure?.url == null && fichaTecnica?.url == null;
}

/// Ficha completa de un desarrollo: todo lo que la pantalla de detalle pinta.
class FichaDesarrollo {
  final DatosDesarrollo desarrollo;
  final Showroom? showroom;
  final int disponibles;
  final int totalUnidades;
  final AvanceObra avance;
  final List<Amenidad> amenidades;
  final List<ModeloDesarrollo> modelos;
  final List<VistaDesarrollo> vistas;
  final List<ImagenGaleria> galeria;
  final List<PuntoInteres> puntosInteres;
  final MaterialComercial material;

  /// Fecha de entrega que se le muestra al cliente (estimada, no contractual).
  final String? fechaEntrega;

  const FichaDesarrollo({
    required this.desarrollo,
    this.showroom,
    this.disponibles = 0,
    this.totalUnidades = 0,
    this.avance = const AvanceObra(),
    this.amenidades = const [],
    this.modelos = const [],
    this.vistas = const [],
    this.galeria = const [],
    this.puntosInteres = const [],
    this.material = const MaterialComercial(),
    this.fechaEntrega,
  });

  factory FichaDesarrollo.fromJson(Map<String, dynamic> j) {
    final stats = mapaDe(j['stats']);
    final showroom = j['showroom'] == null
        ? null
        : Showroom.fromJson(mapaDe(j['showroom']));
    return FichaDesarrollo(
      desarrollo: DatosDesarrollo.fromJson(mapaDe(j['proyecto'])),
      // Un showroom sin dirección ni coordenadas no se puede pintar: se trata
      // como ausente para que la pantalla no muestre una tarjeta hueca.
      showroom: showroom != null && !showroom.vacio ? showroom : null,
      disponibles: intDe(stats['disponibles']) ?? 0,
      totalUnidades: intDe(stats['total']) ?? 0,
      avance: AvanceObra.fromJson(mapaDe(j['avance'])),
      amenidades: listaDe(j['amenidades']).map(Amenidad.fromJson).toList(),
      modelos: listaDe(j['modelos']).map(ModeloDesarrollo.fromJson).toList(),
      vistas: listaDe(j['vistas'])
          .map(VistaDesarrollo.fromJson)
          .where((v) => v.url.isNotEmpty)
          .toList(),
      galeria: listaDe(j['multimedia'])
          .map(ImagenGaleria.fromJson)
          .where((m) => m.url.isNotEmpty)
          .toList(),
      puntosInteres: listaDe(
        j['puntos_interes'],
      ).map(PuntoInteres.fromJson).toList(),
      material: MaterialComercial.fromJson(mapaDe(j['documentos'])),
      fechaEntrega: _texto(j['fecha_entrega']),
    );
  }
}

// ---------------------------------------------------------------------------
// Vista de unidades
// ---------------------------------------------------------------------------

/// Tramo de mensualidades de un esquema escalonado. [montoMensualidad] viene en
/// CENTAVOS, como se guarda: convertirlo es responsabilidad del cálculo.
class TramoMensualidad {
  final int montoMensualidadCentavos;
  final int numeroMensualidades;

  /// Fecha límite del tramo; con ella el número de mensualidades se recalcula
  /// contra hoy en vez de usar el guardado.
  final String? fechaLimite;

  const TramoMensualidad({
    this.montoMensualidadCentavos = 0,
    this.numeroMensualidades = 0,
    this.fechaLimite,
  });

  factory TramoMensualidad.fromJson(Map<String, dynamic> j) => TramoMensualidad(
    montoMensualidadCentavos: intDe(j['monto_mensualidad']) ?? 0,
    numeroMensualidades: intDe(j['numero_mensualidades']) ?? 0,
    fechaLimite: _texto(j['fecha_limite']),
  );
}

/// Esquema de pago de un desarrollo, tal como se le ofrece al cliente.
class EsquemaPago {
  final int id;
  final int idDesarrollo;
  final String nombre;

  /// Descuento (negativo) o aumento (positivo) sobre el precio de lista, en %.
  final double porcentajeDescuentoAumento;

  final double porcentajeEnganche;
  final double porcentajeMensualidades;
  final int numeroMensualidades;
  final double porcentajeEntrega;
  final int? numeroPagosEnganche;
  final List<TramoMensualidad> tramos;
  final bool esManual;
  final int? orden;

  const EsquemaPago({
    required this.id,
    required this.idDesarrollo,
    required this.nombre,
    this.porcentajeDescuentoAumento = 0,
    this.porcentajeEnganche = 0,
    this.porcentajeMensualidades = 0,
    this.numeroMensualidades = 0,
    this.porcentajeEntrega = 0,
    this.numeroPagosEnganche,
    this.tramos = const [],
    this.esManual = false,
    this.orden,
  });

  factory EsquemaPago.fromJson(Map<String, dynamic> j) => EsquemaPago(
    id: intDe(j['id']) ?? 0,
    idDesarrollo: intDe(j['id_proyecto']) ?? 0,
    nombre: (j['nombre'] ?? '') as String,
    porcentajeDescuentoAumento: numDe(j['porcentaje_descuento_aumento']),
    porcentajeEnganche: numDe(j['porcentaje_enganche']),
    porcentajeMensualidades: numDe(j['porcentaje_mensualidades']),
    numeroMensualidades: intDe(j['numero_mensualidades']) ?? 0,
    porcentajeEntrega: numDe(j['porcentaje_entrega']),
    numeroPagosEnganche: intDe(j['numero_pagos_enganche']),
    tramos: listaDe(j['tramos_mensualidad'])
        .map(TramoMensualidad.fromJson)
        .toList(),
    esManual: j['es_manual'] == true,
    orden: intDe(j['orden']),
  );

  /// Escalonado con monto fijo: las mensualidades viven en los tramos (en
  /// centavos) y las columnas planas quedan en cero, así que el cálculo NO
  /// puede salir de los porcentajes.
  bool get esEscalonadoMontoFijo =>
      tramos.any((t) => t.montoMensualidadCentavos > 0);
}

/// Fechas de entrega de un desarrollo y los meses de mensualidades que quedan.
class EntregaDesarrollo {
  final String? fechaEntrega;
  final String? fechaEntregaProyecto;

  /// La que manda para la oferta: `fecha_entrega_proyecto ?? fecha_entrega`.
  final String? efectiva;

  /// Mensualidades restantes: de hoy a la entrega menos 1 mes (el mes de
  /// entrega es el pago a escrituración, no una mensualidad).
  final int mesesMensualidades;

  const EntregaDesarrollo({
    this.fechaEntrega,
    this.fechaEntregaProyecto,
    this.efectiva,
    this.mesesMensualidades = 0,
  });

  factory EntregaDesarrollo.fromJson(Map<String, dynamic> j) =>
      EntregaDesarrollo(
        fechaEntrega: _texto(j['fecha_entrega']),
        fechaEntregaProyecto: _texto(j['fecha_entrega_proyecto']),
        efectiva: _texto(j['efectiva']),
        mesesMensualidades: intDe(j['meses_mensualidades']) ?? 0,
      );
}

/// Unidad disponible del inventario.
class Unidad {
  final int id;
  final String? numero;
  final String? nivel;
  final double precioLista;
  final double m2Interiores;
  final double m2Exteriores;
  final double m2Total;
  final int? idDesarrollo;
  final String? desarrolloNombre;
  final String? edificioNombre;
  final int? idModelo;
  final String? modeloNombre;
  final int recamaras;
  final int banos;
  final int medioBanos;
  final int bodegas;
  final int estacionamientos;
  final List<String> tiposEstacionamiento;

  /// Imagen efectiva de la tarjeta: las de la unidad si tiene, si no las del
  /// modelo. La resuelve el servidor.
  final List<String> imagenes;

  final List<EsquemaPago> esquemasPago;

  const Unidad({
    required this.id,
    this.numero,
    this.nivel,
    this.precioLista = 0,
    this.m2Interiores = 0,
    this.m2Exteriores = 0,
    this.m2Total = 0,
    this.idDesarrollo,
    this.desarrolloNombre,
    this.edificioNombre,
    this.idModelo,
    this.modeloNombre,
    this.recamaras = 0,
    this.banos = 0,
    this.medioBanos = 0,
    this.bodegas = 0,
    this.estacionamientos = 0,
    this.tiposEstacionamiento = const [],
    this.imagenes = const [],
    this.esquemasPago = const [],
  });

  factory Unidad.fromJson(Map<String, dynamic> j) => Unidad(
    id: intDe(j['id']) ?? 0,
    numero: _texto(j['numero_propiedad']),
    nivel: _texto(j['numero_piso']),
    precioLista: numDe(j['precio_lista']),
    m2Interiores: numDe(j['m2_interiores']),
    m2Exteriores: numDe(j['m2_exteriores']),
    m2Total: numDe(j['m2_total']),
    idDesarrollo: intDe(j['proyecto_id']),
    desarrolloNombre: _texto(j['proyecto_nombre']),
    edificioNombre: _texto(j['edificio_nombre']),
    idModelo: intDe(j['modelo_id']),
    modeloNombre: _texto(j['modelo_nombre']),
    recamaras: intDe(j['recamaras']) ?? 0,
    banos: intDe(j['banos']) ?? 0,
    medioBanos: intDe(j['medio_banos']) ?? 0,
    bodegas: intDe(j['bodegas_count']) ?? 0,
    estacionamientos: intDe(j['estacionamientos_count']) ?? 0,
    tiposEstacionamiento: _textos(j['estacionamientos_tipos']),
    // Las imágenes llegan como objetos {id, url}: aquí solo interesa la URL.
    imagenes: _urls(j['imagenes']),
    esquemasPago: listaDe(j['esquemas_pago']).map(EsquemaPago.fromJson).toList(),
  );

  /// Etiqueta de la unidad para títulos y tarjetas.
  String get etiqueta => (numero ?? '').isNotEmpty ? numero! : '$id';
}

/// Valores disponibles para armar los filtros, calculados por el servidor sobre
/// el inventario visible del agente.
class OpcionesFiltro {
  final List<String> desarrollos;
  final List<String> modelos;
  final List<int> recamaras;
  final List<String> niveles;

  const OpcionesFiltro({
    this.desarrollos = const [],
    this.modelos = const [],
    this.recamaras = const [],
    this.niveles = const [],
  });

  factory OpcionesFiltro.fromJson(Map<String, dynamic> j) => OpcionesFiltro(
    desarrollos: _textos(j['proyectos']),
    modelos: _textos(j['modelos']),
    recamaras: ((j['recamaras'] as List?) ?? const [])
        .map(intDe)
        .whereType<int>()
        .toList(),
    // Los niveles llegan como texto (`numero_piso` es TEXT) y se ordenan
    // numéricamente cuando se puede: "10" no va antes de "2".
    niveles: _ordenarNiveles(_textos(j['niveles'])),
  );
}

/// Página de resultados de la búsqueda de unidades.
class PaginaUnidades {
  final List<Unidad> unidades;
  final int total;
  final int totalPaginas;

  /// Unidades disponibles por nombre de desarrollo, para el selector de filtro.
  final Map<String, int> conteoPorDesarrollo;

  final OpcionesFiltro opciones;

  /// Esquemas por id de desarrollo, con tramos y orden (el listado por sí solo
  /// no alcanza para calcular un escalonado).
  final Map<int, List<EsquemaPago>> esquemasPorDesarrollo;

  /// Fechas de entrega por id de desarrollo, insumo del cálculo de esquemas.
  final Map<int, EntregaDesarrollo> entregaPorDesarrollo;

  const PaginaUnidades({
    this.unidades = const [],
    this.total = 0,
    this.totalPaginas = 0,
    this.conteoPorDesarrollo = const {},
    this.opciones = const OpcionesFiltro(),
    this.esquemasPorDesarrollo = const {},
    this.entregaPorDesarrollo = const {},
  });

  factory PaginaUnidades.fromJson(Map<String, dynamic> j) {
    final conteos = mapaDe(j['project_counts']);
    final esquemas = mapaDe(j['esquemas_pago_por_proyecto']);
    final entregas = mapaDe(j['fechas_entrega']);
    return PaginaUnidades(
      unidades: listaDe(j['propiedades']).map(Unidad.fromJson).toList(),
      total: intDe(j['total_count']) ?? 0,
      totalPaginas: intDe(j['total_pages']) ?? 0,
      conteoPorDesarrollo: {
        for (final e in conteos.entries) e.key: intDe(e.value) ?? 0,
      },
      opciones: OpcionesFiltro.fromJson(mapaDe(j['filter_options'])),
      esquemasPorDesarrollo: {
        for (final e in esquemas.entries)
          if (intDe(e.key) != null)
            intDe(e.key)!: listaDe(e.value).map(EsquemaPago.fromJson).toList(),
      },
      entregaPorDesarrollo: {
        for (final e in entregas.entries)
          if (intDe(e.key) != null)
            intDe(e.key)!: EntregaDesarrollo.fromJson(mapaDe(e.value)),
      },
    );
  }

  /// Esquemas de la unidad: los del desarrollo (con tramos) y, si aún no
  /// llegaron, los que trae la unidad.
  List<EsquemaPago> esquemasDe(Unidad u) {
    final delDesarrollo = esquemasPorDesarrollo[u.idDesarrollo] ?? const [];
    return delDesarrollo.isNotEmpty ? delDesarrollo : u.esquemasPago;
  }

  /// Mensualidades restantes del desarrollo de la unidad (0 si no se conoce su
  /// fecha de entrega).
  int mesesDe(Unidad u) =>
      entregaPorDesarrollo[u.idDesarrollo]?.mesesMensualidades ?? 0;
}

/// Orden por precio pedido al servidor.
enum OrdenPrecio {
  ninguno,
  ascendente,
  descendente;

  /// Clave que entiende el backend; null cuando no se ordena.
  String? get clave => switch (this) {
    OrdenPrecio.ninguno => null,
    OrdenPrecio.ascendente => 'asc',
    OrdenPrecio.descendente => 'desc',
  };
}

/// Filtros de la búsqueda de unidades. Inmutable y comparable: es la clave de
/// caché de la consulta, así que dos filtros iguales no pueden pedir dos veces.
class FiltrosUnidades {
  final List<String> desarrollos;
  final List<String> modelos;
  final List<String> niveles;

  /// Opciones de recámaras tal como se eligen en la UI ("1", "2", "4+").
  final List<String> recamaras;

  /// null = sin filtrar; true = con bodega; false = sin bodega.
  final bool? conBodega;
  final bool? conEstacionamiento;

  final OrdenPrecio ordenPrecio;
  final double? precioMin;
  final double? precioMax;

  const FiltrosUnidades({
    this.desarrollos = const [],
    this.modelos = const [],
    this.niveles = const [],
    this.recamaras = const [],
    this.conBodega,
    this.conEstacionamiento,
    this.ordenPrecio = OrdenPrecio.ninguno,
    this.precioMin,
    this.precioMax,
  });

  FiltrosUnidades copyWith({
    List<String>? desarrollos,
    List<String>? modelos,
    List<String>? niveles,
    List<String>? recamaras,
    bool? conBodega,
    bool? conEstacionamiento,
    OrdenPrecio? ordenPrecio,
    double? precioMin,
    double? precioMax,
    bool limpiarBodega = false,
    bool limpiarEstacionamiento = false,
    bool limpiarPrecio = false,
  }) => FiltrosUnidades(
    desarrollos: desarrollos ?? this.desarrollos,
    modelos: modelos ?? this.modelos,
    niveles: niveles ?? this.niveles,
    recamaras: recamaras ?? this.recamaras,
    conBodega: limpiarBodega ? null : (conBodega ?? this.conBodega),
    conEstacionamiento: limpiarEstacionamiento
        ? null
        : (conEstacionamiento ?? this.conEstacionamiento),
    ordenPrecio: ordenPrecio ?? this.ordenPrecio,
    precioMin: limpiarPrecio ? null : (precioMin ?? this.precioMin),
    precioMax: limpiarPrecio ? null : (precioMax ?? this.precioMax),
  );

  /// Recámaras en números para el servidor: "4+" abre el rango 4-10, igual que
  /// el portal web.
  List<int> get recamarasNumericas {
    final out = <int>[];
    for (final r in recamaras) {
      if (r == '4+') {
        out.addAll([4, 5, 6, 7, 8, 9, 10]);
      } else {
        final n = int.tryParse(r);
        if (n != null) out.add(n);
      }
    }
    return out;
  }

  /// Cuántos grupos de filtro están puestos (lo que pinta el contador del botón).
  int get activos =>
      (desarrollos.isEmpty ? 0 : 1) +
      (modelos.isEmpty ? 0 : 1) +
      (niveles.isEmpty ? 0 : 1) +
      (recamaras.isEmpty ? 0 : 1) +
      (conBodega == null ? 0 : 1) +
      (conEstacionamiento == null ? 0 : 1) +
      (precioMin == null && precioMax == null ? 0 : 1);

  bool get hayFiltros => activos > 0;

  @override
  bool operator ==(Object other) =>
      other is FiltrosUnidades &&
      _mismaLista(other.desarrollos, desarrollos) &&
      _mismaLista(other.modelos, modelos) &&
      _mismaLista(other.niveles, niveles) &&
      _mismaLista(other.recamaras, recamaras) &&
      other.conBodega == conBodega &&
      other.conEstacionamiento == conEstacionamiento &&
      other.ordenPrecio == ordenPrecio &&
      other.precioMin == precioMin &&
      other.precioMax == precioMax;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(desarrollos),
    Object.hashAll(modelos),
    Object.hashAll(niveles),
    Object.hashAll(recamaras),
    conBodega,
    conEstacionamiento,
    ordenPrecio,
    precioMin,
    precioMax,
  );
}

/// Consulta concreta de unidades: filtros + página. Es la clave de caché de la
/// vista, por eso es comparable.
class ConsultaUnidades {
  final FiltrosUnidades filtros;

  /// Página base 0.
  final int pagina;

  final int porPagina;

  const ConsultaUnidades({
    this.filtros = const FiltrosUnidades(),
    this.pagina = 0,
    this.porPagina = paginaDefault,
  });

  /// Tamaño de página del listado, igual que el portal web.
  static const int paginaDefault = 30;

  /// Techo que impone el servidor. La búsqueda por número de unidad filtra en
  /// cliente, así que pide una página grande, pero no el inventario completo.
  static const int paginaMaxima = 500;

  @override
  bool operator ==(Object other) =>
      other is ConsultaUnidades &&
      other.filtros == filtros &&
      other.pagina == pagina &&
      other.porPagina == porPagina;

  @override
  int get hashCode => Object.hash(filtros, pagina, porPagina);
}

// ---------------------------------------------------------------------------
// Planos de una unidad
// ---------------------------------------------------------------------------

/// Región de una unidad dentro del plano del nivel. Las coordenadas son
/// PORCENTAJES (0-100) de la imagen, no píxeles: el plano se escala al ancho
/// disponible y el polígono con él.
class RegionPlano {
  /// Número de unidad tal como se capturó en el plano.
  final String unidad;

  /// Vértices `[x, y]` en porcentaje.
  final List<List<double>> poligono;

  /// Punto de control de la curva que sale del vértice i (índice -> `[x, y]`).
  /// Un tramo sin entrada aquí es una recta.
  final Map<int, List<double>> curvas;

  const RegionPlano({
    required this.unidad,
    this.poligono = const [],
    this.curvas = const {},
  });

  factory RegionPlano.fromJson(Map<String, dynamic> j) {
    final curvasRaw = mapaDe(j['curves']);
    return RegionPlano(
      unidad: ((j['unit_number'] ?? '') as String).trim(),
      poligono: ((j['polygon'] as List?) ?? const [])
          .whereType<List>()
          .map((p) => p.map(numDe).toList())
          .where((p) => p.length >= 2)
          .toList(),
      curvas: {
        for (final e in curvasRaw.entries)
          if (intDe(e.key) != null && e.value is List)
            intDe(e.key)!: (e.value as List).map(numDe).toList(),
      },
    );
  }
}

/// Planos de una unidad: el arquitectónico de su modelo y el de ubicación de su
/// nivel, con las regiones para resaltarla.
class PlanosUnidad {
  final String? planoArquitectonicoUrl;
  final String? planoUbicacionUrl;
  final List<RegionPlano> regiones;

  /// Número de departamento dentro del nivel ("1203" en el nivel 12 -> "03").
  final String numeroDepa;

  final String? numeroUnidad;
  final String? nivel;
  final String? modelo;
  final String? edificio;
  final String? desarrollo;
  final double? m2Total;

  const PlanosUnidad({
    this.planoArquitectonicoUrl,
    this.planoUbicacionUrl,
    this.regiones = const [],
    this.numeroDepa = '',
    this.numeroUnidad,
    this.nivel,
    this.modelo,
    this.edificio,
    this.desarrollo,
    this.m2Total,
  });

  factory PlanosUnidad.fromJson(Map<String, dynamic> j) => PlanosUnidad(
    planoArquitectonicoUrl: _texto(j['plano_arquitectonico_url']),
    planoUbicacionUrl: _texto(j['plano_ubicacion_url']),
    regiones: listaDe(j['regiones'])
        .map(RegionPlano.fromJson)
        .where((r) => r.unidad.isNotEmpty && r.poligono.length >= 3)
        .toList(),
    numeroDepa: (j['numero_depa'] ?? '') as String,
    numeroUnidad: _texto(j['numero_propiedad']),
    nivel: _texto(j['nivel']),
    modelo: _texto(j['modelo']),
    edificio: _texto(j['edificio']),
    desarrollo: _texto(j['proyecto']),
    m2Total: j['m2_total'] == null ? null : numDe(j['m2_total']),
  );

  bool get vacio => planoArquitectonicoUrl == null && planoUbicacionUrl == null;
}

// ---------------------------------------------------------------------------
// Contrato
// ---------------------------------------------------------------------------

/// Inventario que el agente puede vender. La instancia queda atada al agente
/// que se está viendo (el propio, o el impersonado por un admin), así que
/// ningún método recibe ese destinatario. Todos lanzan `ApiError`.
abstract interface class InventarioPort {
  /// Desarrollos con unidades cargadas a los que tiene acceso. Lista vacía =
  /// sin proyectos asignados, no un fallo.
  Future<List<DesarrolloResumen>> desarrollos();

  /// Ficha completa de un desarrollo.
  Future<FichaDesarrollo> desarrollo(int idDesarrollo);

  /// Unidades disponibles que cumplen los filtros, paginadas.
  Future<PaginaUnidades> unidades(ConsultaUnidades consulta);

  /// Planos de una unidad, con las regiones del plano de nivel.
  Future<PlanosUnidad> planos(int idUnidad);
}

// ---------------------------------------------------------------------------
// Lectura tolerante del payload
// ---------------------------------------------------------------------------

/// Texto no vacío, o null. El backend degrada campos ausentes a null y a "" de
/// forma indistinta, y una cadena vacía pintada es un hueco en la pantalla.
String? _texto(Object? v) {
  if (v is! String) return null;
  final s = v.trim();
  return s.isEmpty ? null : s;
}

List<String> _textos(Object? v) {
  if (v is! List) return const [];
  return v
      .map((e) => '$e'.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// URLs de una lista de objetos `{id, url}`, sin vacíos.
List<String> _urls(Object? v) => listaDe(v)
    .map((e) => _texto(e['url']))
    .whereType<String>()
    .toList(growable: false);

/// Niveles ordenados numéricamente cuando se puede; el resto, alfabético al
/// final. `numero_piso` es TEXT, así que "10" y "2" se comparan como cadenas y
/// saldrían al revés.
List<String> _ordenarNiveles(List<String> niveles) {
  final copia = [...niveles];
  copia.sort((a, b) {
    final na = double.tryParse(a);
    final nb = double.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.compareTo(b);
  });
  return copia;
}

bool _mismaLista(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
