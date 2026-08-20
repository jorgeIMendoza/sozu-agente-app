import 'package:sozu_agente_app/shared/json.dart';

/// Perfil del agente: activación, presentación, datos de su cuenta con SOZU,
/// identidad, información fiscal, cuentas de dispersión, expediente de
/// documentos y capacitación.
///
/// Este archivo habla SOLO el lenguaje del negocio. Ni una palabra de la
/// tecnología que lo sirve: eso vive únicamente en `adapters/`.

// ── Catálogo de tipos de documento del expediente ──────────────────────────

/// Ids de `tipos_documento` que forman el expediente del agente.
///
/// Son datos del catálogo del negocio (el mismo número que usa el back office),
/// no un detalle de transporte: por eso viven en el puerto y no en el adapter.
abstract final class TiposDocumento {
  static const ineFrente = 2;
  static const ineReverso = 3;
  static const pasaporte = 4;
  static const constanciaFiscal = 6;
  static const cartaComercializacion = 48;

  /// INE completo (frente y reverso en un solo PDF), formato vigente 2026-08.
  static const ineCompleto = 63;
}

/// Identificación oficial que el agente puede entregar. Es UNA de las dos: subir
/// las dos deja dos identidades vigentes y verificación no sabe cuál manda.
enum TipoIdentificacion {
  ine(TiposDocumento.ineCompleto),
  pasaporte(TiposDocumento.pasaporte);

  const TipoIdentificacion(this.tipoDocumento);

  final int tipoDocumento;
}

// ── Estados ────────────────────────────────────────────────────────────────

/// Estado de un documento del expediente.
enum EstadoDocumento {
  /// No se ha entregado.
  pendiente,

  /// Verificación lo aprobó.
  validado,

  /// Entregado, esperando a que verificación lo revise.
  revision,

  /// Verificación lo rechazó: hay que volver a cargarlo.
  rechazado,

  /// Caducó (una recaptura marca la versión anterior como expirada).
  expirado;

  static EstadoDocumento desde(Object? valor) => switch ('${valor ?? ''}') {
    'validado' => EstadoDocumento.validado,
    'revision' => EstadoDocumento.revision,
    'rechazado' => EstadoDocumento.rechazado,
    'expirado' => EstadoDocumento.expirado,
    _ => EstadoDocumento.pendiente,
  };

  /// Etiqueta que se le muestra al agente.
  String get etiqueta => switch (this) {
    EstadoDocumento.validado => 'Validado',
    EstadoDocumento.revision => 'En revisión',
    EstadoDocumento.rechazado => 'Rechazado',
    EstadoDocumento.expirado => 'Expirado',
    EstadoDocumento.pendiente => 'Pendiente',
  };

  /// Hay que subirlo (o volver a subirlo) para avanzar.
  bool get pideArchivo =>
      this == EstadoDocumento.pendiente ||
      this == EstadoDocumento.rechazado ||
      this == EstadoDocumento.expirado;
}

/// Avance de un paso de la activación.
enum EstadoPaso {
  completo,
  parcial,
  pendiente;

  static EstadoPaso desde(Object? valor) => switch ('${valor ?? ''}') {
    'complete' => EstadoPaso.completo,
    'partial' => EstadoPaso.parcial,
    _ => EstadoPaso.pendiente,
  };

  String get etiqueta => switch (this) {
    EstadoPaso.completo => 'Completado',
    EstadoPaso.parcial => 'En proceso',
    EstadoPaso.pendiente => 'Pendiente',
  };
}

/// Avance de la firma de la Carta de comercialización.
enum EstadoFirmaCarta {
  /// Todavía no se ha generado el documento a firmar.
  sinFirmar,

  /// Documento generado y enviado; nadie ha firmado.
  enviado,

  /// Alguna de las partes firmó, el agente todavía no.
  firmadoParcial,

  /// El agente ya firmó; falta SOZU para cerrarlo.
  pendienteContraparte,

  /// Firmado por todas las partes.
  completado,

  /// Cancelado o caducado: hay que generarlo de nuevo.
  cancelado;

  static EstadoFirmaCarta desde(Object? valor) => switch ('${valor ?? ''}') {
    'enviado' => EstadoFirmaCarta.enviado,
    'firmado_parcial' => EstadoFirmaCarta.firmadoParcial,
    'pendiente_contraparte' => EstadoFirmaCarta.pendienteContraparte,
    'completado' => EstadoFirmaCarta.completado,
    'cancelado' => EstadoFirmaCarta.cancelado,
    _ => EstadoFirmaCarta.sinFirmar,
  };

  String get etiqueta => switch (this) {
    EstadoFirmaCarta.sinFirmar => 'Sin firmar',
    EstadoFirmaCarta.enviado => 'Enviado',
    EstadoFirmaCarta.firmadoParcial => 'Firma parcial',
    EstadoFirmaCarta.pendienteContraparte => 'Pendiente contraparte',
    EstadoFirmaCarta.completado => 'Firmado',
    EstadoFirmaCarta.cancelado => 'Cancelado',
  };

  /// La firma está abierta: se continúa, no se vuelve a generar. Generar un
  /// segundo documento cuesta una verificación de identidad, así que la UI
  /// tiene que ofrecer "Continuar" y no "Firmar".
  bool get enCurso =>
      this == EstadoFirmaCarta.enviado ||
      this == EstadoFirmaCarta.firmadoParcial;
}

/// Cómo se lee el estatus de una cita de capacitación.
enum TonoCita { exito, advertencia, info, peligro, neutral }

// ── Activación ─────────────────────────────────────────────────────────────

/// Un paso de la activación del agente (identidad, fiscal, banco, capacitación).
class PasoActivacion {
  /// Clave estable del paso: `basic`, `fiscal`, `bank-accounts`, `training`.
  final String clave;
  final String etiqueta;
  final EstadoPaso estado;

  /// El paso lo lleva la inmobiliaria: se muestra, no se edita.
  final bool soloLectura;

  /// Qué le falta al agente, en su idioma ("Código postal", "RFC"…).
  final List<String> faltantes;

  const PasoActivacion({
    required this.clave,
    required this.etiqueta,
    this.estado = EstadoPaso.pendiente,
    this.soloLectura = false,
    this.faltantes = const [],
  });

  factory PasoActivacion.desde(Map<String, dynamic> j) => PasoActivacion(
    clave: '${j['id'] ?? ''}',
    etiqueta: '${j['etiqueta'] ?? ''}',
    estado: EstadoPaso.desde(j['estado']),
    soloLectura: j['solo_lectura'] == true,
    faltantes: (j['faltantes'] as List?)?.map((e) => '$e').toList() ?? const [],
  );

  bool get completo => estado == EstadoPaso.completo;
}

/// Conteo de secciones del perfil por avance. Es el tally del hero del
/// expediente: el agente ve de un golpe cuánto le falta.
class ResumenSecciones {
  final int total;
  final int validadas;
  final int enProceso;
  final int pendientes;

  /// Avance agregado de la sección Documentos.
  final EstadoPaso documentos;

  const ResumenSecciones({
    this.total = 0,
    this.validadas = 0,
    this.enProceso = 0,
    this.pendientes = 0,
    this.documentos = EstadoPaso.pendiente,
  });

  factory ResumenSecciones.desde(Map<String, dynamic> j) => ResumenSecciones(
    total: intDe(j['total']) ?? 0,
    validadas: intDe(j['validadas']) ?? 0,
    enProceso: intDe(j['en_proceso']) ?? 0,
    pendientes: intDe(j['pendientes']) ?? 0,
    documentos: EstadoPaso.desde(j['documentos']),
  );
}

/// Avance de activación del agente. Es el número que decide el badge
/// "Verificado" y lo que el agente puede hacer en el portal.
class Activacion {
  final int porcentaje;
  final int completados;
  final int totalPasos;
  final List<PasoActivacion> pasos;
  final ResumenSecciones secciones;

  const Activacion({
    this.porcentaje = 0,
    this.completados = 0,
    this.totalPasos = 0,
    this.pasos = const [],
    this.secciones = const ResumenSecciones(),
  });

  factory Activacion.desde(Map<String, dynamic> j) => Activacion(
    porcentaje: intDe(j['percentage']) ?? 0,
    completados: intDe(j['completados']) ?? 0,
    totalPasos: intDe(j['total_pasos']) ?? 0,
    pasos: listaDe(j['steps']).map(PasoActivacion.desde).toList(),
    secciones: ResumenSecciones.desde(mapaDe(j['secciones'])),
  );

  /// El badge "Verificado" solo al 100 %.
  bool get verificado => porcentaje >= 100;

  PasoActivacion? paso(String clave) {
    for (final p in pasos) {
      if (p.clave == clave) return p;
    }
    return null;
  }

  /// El agente cobra comisiones solo con fiscal y banco listos. Los pasos del
  /// dependiente llegan marcados completos (los lleva su inmobiliaria), así que
  /// esta bandera ya lo contempla sin preguntarle a nadie más.
  bool get puedeRecibirComisiones {
    final fiscal = paso('fiscal');
    final banco = paso('bank-accounts');
    return (fiscal?.completo ?? false) && (banco?.completo ?? false);
  }
}

// ── Presentación pública del agente ────────────────────────────────────────

/// Con qué cara aparece el agente ante sus prospectos.
class PresentacionAgente {
  final String nombre;
  final String? fotoUrl;

  /// Frase de presentación; aparece al compartir una propiedad.
  final String? frase;
  final String? rol;

  /// Nombres de los desarrollos que tiene asignados.
  final List<String> desarrollos;

  const PresentacionAgente({
    this.nombre = 'Agente',
    this.fotoUrl,
    this.frase,
    this.rol,
    this.desarrollos = const [],
  });

  factory PresentacionAgente.desde(Map<String, dynamic> j) =>
      PresentacionAgente(
        nombre: '${j['nombre'] ?? 'Agente'}',
        fotoUrl: j['foto_perfil_url'] as String?,
        frase: j['frase_perfil'] as String?,
        rol: j['rol'] as String?,
        desarrollos:
            (j['desarrollos'] as List?)?.map((e) => '$e').toList() ?? const [],
      );

  /// Límite de la frase, el mismo que acepta el backend.
  static const int maximoFrase = 280;

  PresentacionAgente conFoto(String? url) => PresentacionAgente(
    nombre: nombre,
    fotoUrl: url,
    frase: frase,
    rol: rol,
    desarrollos: desarrollos,
  );

  PresentacionAgente conFrase(String? nueva) => PresentacionAgente(
    nombre: nombre,
    fotoUrl: fotoUrl,
    frase: nueva,
    rol: rol,
    desarrollos: desarrollos,
  );
}

// ── Datos que administra SOZU ──────────────────────────────────────────────

/// Lo que SOZU define sobre la relación con el agente. Solo consulta: si algo no
/// coincide, lo corrige su contacto interno.
class CuentaSozu {
  final String? rol;
  final String? tipoRelacion;
  final double? porcentajeComision;
  final bool activo;

  /// Quién lo trae (su líder o su inmobiliaria).
  final String? lider;
  final DateTime? fechaAlta;

  const CuentaSozu({
    this.rol,
    this.tipoRelacion,
    this.porcentajeComision,
    this.activo = false,
    this.lider,
    this.fechaAlta,
  });

  factory CuentaSozu.desde(Map<String, dynamic> j) => CuentaSozu(
    rol: j['rol'] as String?,
    tipoRelacion: j['tipo_relacion'] as String?,
    porcentajeComision: j['porcentaje_comision'] == null
        ? null
        : numDe(j['porcentaje_comision']),
    activo: j['activo'] == true,
    lider: j['lider'] as String?,
    fechaAlta: DateTime.tryParse('${j['fecha_alta'] ?? ''}'),
  );
}

// ── Identidad y domicilio ──────────────────────────────────────────────────

/// Domicilio (particular o fiscal). País/estado/municipio viajan como ids del
/// catálogo porque la activación los exige y hay que poder volver a escribirlos.
class Domicilio {
  final String? calle;
  final String? numExt;
  final String? numInt;
  final String? colonia;
  final String? codigoPostal;
  final String? idPais;
  final int? idEstado;
  final int? idMunicipio;

  const Domicilio({
    this.calle,
    this.numExt,
    this.numInt,
    this.colonia,
    this.codigoPostal,
    this.idPais,
    this.idEstado,
    this.idMunicipio,
  });

  factory Domicilio.desde(Map<String, dynamic> j) => Domicilio(
    calle: j['calle'] as String?,
    numExt: j['num_ext'] as String?,
    numInt: j['num_int'] as String?,
    colonia: j['colonia'] as String?,
    codigoPostal: j['codigo_postal'] as String?,
    idPais: j['id_pais'] == null ? null : '${j['id_pais']}',
    idEstado: intDe(j['id_estado']),
    idMunicipio: intDe(j['id_municipio']),
  );

  /// Una línea legible: "Av. Insurgentes Sur 1234, Del Valle, 03100".
  String get resumen {
    final partes = <String>[
      if ((calle ?? '').trim().isNotEmpty)
        [
          calle!.trim(),
          if ((numExt ?? '').trim().isNotEmpty) numExt!.trim(),
        ].join(' '),
      if ((colonia ?? '').trim().isNotEmpty) colonia!.trim(),
      if ((codigoPostal ?? '').trim().isNotEmpty) codigoPostal!.trim(),
    ];
    return partes.join(', ');
  }
}

/// Datos personales del agente.
class Identidad {
  final String? email;
  final String? telefono;
  final String? nombreLegal;
  final String? curp;
  final DateTime? fechaNacimiento;

  /// `M`, `F` u `O` como lo guarda el catálogo.
  final String? sexo;
  final Domicilio domicilio;

  const Identidad({
    this.email,
    this.telefono,
    this.nombreLegal,
    this.curp,
    this.fechaNacimiento,
    this.sexo,
    this.domicilio = const Domicilio(),
  });

  factory Identidad.desde(Map<String, dynamic> j) => Identidad(
    email: j['email'] as String?,
    telefono: j['telefono'] as String?,
    nombreLegal: j['nombre_legal'] as String?,
    curp: j['curp'] as String?,
    fechaNacimiento: DateTime.tryParse('${j['fecha_nacimiento'] ?? ''}'),
    sexo: j['sexo'] as String?,
    domicilio: Domicilio.desde(mapaDe(j['direccion'])),
  );

  /// Cómo se lee el sexo. Un valor fuera del catálogo se muestra tal cual: mejor
  /// un dato raro visible que un campo vacío que nadie sabe explicar.
  String? get sexoLegible => switch (sexo) {
    'M' => 'Hombre',
    'F' => 'Mujer',
    'O' => 'Otro',
    null => null,
    _ => sexo,
  };
}

/// Datos con los que el agente factura sus comisiones a SOZU.
class DatosFiscales {
  final String? nombreLegal;
  final String? rfc;

  /// Clave del régimen (id del catálogo).
  final String? regimen;
  final String? regimenNombre;

  /// Clave del uso del CFDI.
  final String? usoCfdi;
  final String? usoCfdiNombre;
  final Domicilio domicilio;

  /// Los administra su inmobiliaria: se muestran, no se editan.
  final bool soloLectura;

  /// Por qué no se puede editar ("La administra Grupo X").
  final String? nota;

  const DatosFiscales({
    this.nombreLegal,
    this.rfc,
    this.regimen,
    this.regimenNombre,
    this.usoCfdi,
    this.usoCfdiNombre,
    this.domicilio = const Domicilio(),
    this.soloLectura = false,
    this.nota,
  });

  factory DatosFiscales.desde(Map<String, dynamic> j) => DatosFiscales(
    nombreLegal: j['nombre_legal'] as String?,
    rfc: j['rfc'] as String?,
    regimen: j['regimen'] as String?,
    regimenNombre: j['regimen_nombre'] as String?,
    usoCfdi: j['uso_cfdi'] as String?,
    usoCfdiNombre: j['uso_cfdi_nombre'] as String?,
    domicilio: Domicilio.desde(mapaDe(j['direccion_fiscal'])),
    soloLectura: j['solo_lectura'] == true,
    nota: j['nota'] as String?,
  );

  /// "626 · Régimen Simplificado de Confianza"; solo la clave si el catálogo no
  /// la resuelve.
  String? get regimenLegible => _claveYNombre(regimen, regimenNombre);
  String? get usoCfdiLegible => _claveYNombre(usoCfdi, usoCfdiNombre);
}

String? _claveYNombre(String? clave, String? nombre) {
  if ((clave ?? '').isEmpty) return null;
  return (nombre ?? '').isEmpty ? clave : '$clave · $nombre';
}

// ── Cuentas de dispersión ──────────────────────────────────────────────────

/// Cuenta a la que SOZU le dispersa las comisiones.
class CuentaDeDispersion {
  final int id;
  final int? idBanco;
  final String banco;

  /// Últimos 4 dígitos de la CLABE, o del número de cuenta si no hay CLABE.
  final String? ultimos4;
  final String? titular;

  /// SOZU ya la validó: es la que recibe la dispersión.
  final bool validada;

  /// El agente puede corregirla (permiso + no la administra su inmobiliaria).
  final bool editable;

  /// Carátula del estado de cuenta.
  final String? evidenciaUrl;

  const CuentaDeDispersion({
    required this.id,
    this.idBanco,
    this.banco = 'Banco',
    this.ultimos4,
    this.titular,
    this.validada = false,
    this.editable = false,
    this.evidenciaUrl,
  });

  factory CuentaDeDispersion.desde(Map<String, dynamic> j) =>
      CuentaDeDispersion(
        id: intDe(j['id']) ?? 0,
        idBanco: intDe(j['id_banco']),
        banco: '${j['banco'] ?? 'Banco'}',
        ultimos4: j['last4'] as String?,
        titular: j['titular'] as String?,
        validada: j['validada'] == true,
        editable: j['editable'] == true,
        evidenciaUrl: j['evidencia_url'] as String?,
      );

  /// "•••• •••• •••• 1234"; vacío si no hay dígitos que mostrar.
  String get numeroEnmascarado =>
      (ultimos4 ?? '').isEmpty ? '' : '•••• •••• •••• $ultimos4';

  String get estatusLegible =>
      validada ? 'Validada' : 'Pendiente de activación';
}

// ── Expediente ─────────────────────────────────────────────────────────────

/// Estado de la firma de la Carta de comercialización.
class FirmaDeCarta {
  final EstadoFirmaCarta estado;

  /// Folio del documento en firma; null si todavía no existe.
  final String? folio;

  /// Liga donde el agente firma. Null cuando no hay documento abierto.
  final String? urlParaFirmar;

  /// PDF firmado, cuando ya está cerrado.
  final String? pdfUrl;

  const FirmaDeCarta({
    this.estado = EstadoFirmaCarta.sinFirmar,
    this.folio,
    this.urlParaFirmar,
    this.pdfUrl,
  });

  /// Qué se le dice al agente sobre el siguiente paso de su firma.
  String get ayuda => switch (estado) {
    EstadoFirmaCarta.completado =>
      'Carta firmada por todas las partes. Puedes consultarla cuando quieras.',
    EstadoFirmaCarta.pendienteContraparte =>
      'Ya firmaste. Falta la firma de SOZU para cerrar el documento.',
    EstadoFirmaCarta.enviado || EstadoFirmaCarta.firmadoParcial =>
      'Tu carta ya está lista. Continúa para firmarla.',
    EstadoFirmaCarta.cancelado =>
      'Tu carta anterior se canceló. Genérala de nuevo para firmarla.',
    EstadoFirmaCarta.sinFirmar =>
      'Al firmar se abre tu carta para revisarla y firmarla en línea.',
  };
}

/// Un documento del expediente del agente.
class DocumentoDelExpediente {
  /// Clave estable: `identidad`, `csf`, `carta`.
  final String clave;
  final String nombre;

  /// Quién lo emite ("SAT", "INE", "SOZU").
  final String emisor;

  /// Qué se espera del archivo, en una línea.
  final String ayuda;

  /// Tipos de documento que cubre esta fila.
  final List<int> tipos;

  /// Solo en la identidad: con cuál de las dos se registró.
  final TipoIdentificacion? identificacion;
  final EstadoDocumento estado;

  /// Archivo ya entregado, listo para abrir.
  final String? urlArchivo;

  /// Lo entrega su inmobiliaria.
  final bool soloLectura;

  /// Por qué no lo puede subir él ("La sube Grupo X").
  final String? nota;

  /// Solo en la carta: no se sube, se firma.
  final FirmaDeCarta? firma;

  const DocumentoDelExpediente({
    required this.clave,
    required this.nombre,
    this.emisor = '',
    this.ayuda = '',
    this.tipos = const [],
    this.identificacion,
    this.estado = EstadoDocumento.pendiente,
    this.urlArchivo,
    this.soloLectura = false,
    this.nota,
    this.firma,
  });

  factory DocumentoDelExpediente.desde(Map<String, dynamic> j) {
    final firma = j['firma'];
    return DocumentoDelExpediente(
      clave: '${j['key'] ?? ''}',
      nombre: '${j['nombre'] ?? 'Documento'}',
      emisor: '${j['emisor'] ?? ''}',
      ayuda: '${j['hint'] ?? ''}',
      tipos:
          (j['tipos'] as List?)?.map(intDe).whereType<int>().toList() ??
          const [],
      identificacion: switch ('${j['modo'] ?? ''}') {
        'ine' => TipoIdentificacion.ine,
        'pasaporte' => TipoIdentificacion.pasaporte,
        _ => null,
      },
      estado: EstadoDocumento.desde(j['estatus']),
      urlArchivo: j['url_firmada'] as String?,
      soloLectura: j['solo_lectura'] == true,
      nota: j['nota'] as String?,
      firma: firma is Map
          ? FirmaDeCarta(
              estado: EstadoFirmaCarta.desde(firma['estado']),
              folio: firma['mifiel_document_id'] as String?,
              urlParaFirmar: firma['url_firma'] as String?,
            )
          : null,
    );
  }

  /// Se firma en línea en vez de subirse.
  bool get seFirma => firma != null;

  /// Ya hay archivo que consultar.
  bool get tieneArchivo => (urlArchivo ?? '').isNotEmpty;
}

/// El expediente completo.
class Expediente {
  /// La Constancia la sube su inmobiliaria.
  final bool constanciaSoloLectura;
  final List<DocumentoDelExpediente> documentos;

  const Expediente({
    this.constanciaSoloLectura = false,
    this.documentos = const [],
  });

  factory Expediente.desde(Map<String, dynamic> j) => Expediente(
    constanciaSoloLectura: j['solo_lectura_csf'] == true,
    documentos: listaDe(j['docs']).map(DocumentoDelExpediente.desde).toList(),
  );

  DocumentoDelExpediente? documento(String clave) {
    for (final d in documentos) {
      if (d.clave == clave) return d;
    }
    return null;
  }

  int get validados =>
      documentos.where((d) => d.estado == EstadoDocumento.validado).length;
}

// ── Capacitación ───────────────────────────────────────────────────────────

/// Una cita de capacitación del agente.
class CitaDeCapacitacion {
  final int id;
  final String nombre;
  final DateTime? fecha;

  /// `HH:MM`; null si la cita no tiene hora.
  final String? hora;

  /// Cómo se lee el estatus ("Confirmada", "Agendada"…).
  final String etiqueta;
  final TonoCita tono;

  const CitaDeCapacitacion({
    required this.id,
    this.nombre = 'Capacitación',
    this.fecha,
    this.hora,
    this.etiqueta = 'Sin estatus',
    this.tono = TonoCita.neutral,
  });

  factory CitaDeCapacitacion.desde(Map<String, dynamic> j) {
    final inicio = '${j['hora_inicio'] ?? ''}';
    return CitaDeCapacitacion(
      id: intDe(j['id']) ?? 0,
      nombre: '${j['nombre'] ?? 'Capacitación'}',
      fecha: DateTime.tryParse('${j['fecha'] ?? ''}'),
      hora: inicio.length >= 5 ? inicio.substring(0, 5) : null,
      etiqueta: '${j['etiqueta'] ?? 'Sin estatus'}',
      tono: switch ('${j['tono'] ?? ''}') {
        'success' => TonoCita.exito,
        'warning' => TonoCita.advertencia,
        'info' => TonoCita.info,
        'danger' => TonoCita.peligro,
        _ => TonoCita.neutral,
      },
    );
  }
}

/// Avance de capacitación del agente. Agendar la cita no se hace desde aquí:
/// esta pantalla solo muestra en qué va.
class Capacitacion {
  final int porcentaje;
  final List<CitaDeCapacitacion> citas;

  const Capacitacion({this.porcentaje = 0, this.citas = const []});

  factory Capacitacion.desde(Map<String, dynamic> j) => Capacitacion(
    porcentaje: intDe(j['pct']) ?? 0,
    citas: listaDe(j['citas']).map(CitaDeCapacitacion.desde).toList(),
  );
}

// ── Catálogos ──────────────────────────────────────────────────────────────

/// Opción de un catálogo cerrado (banco, régimen, uso del CFDI, estado…).
class OpcionDeCatalogo {
  /// Valor que se guarda.
  final String valor;
  final String nombre;

  /// Opción de la que depende (el estado de un municipio, el país de un estado).
  final String? padre;

  const OpcionDeCatalogo({
    required this.valor,
    required this.nombre,
    this.padre,
  });

  /// "G03 · Gastos en general".
  String get etiqueta => '$valor · $nombre';
}

/// Catálogos que la pantalla necesita para editar el perfil.
class CatalogosDelPerfil {
  final List<OpcionDeCatalogo> usosCfdi;
  final List<OpcionDeCatalogo> regimenes;
  final List<OpcionDeCatalogo> bancos;

  const CatalogosDelPerfil({
    this.usosCfdi = const [],
    this.regimenes = const [],
    this.bancos = const [],
  });

  factory CatalogosDelPerfil.desde(Map<String, dynamic> j) =>
      CatalogosDelPerfil(
        usosCfdi: listaDe(j['uso_cfdi'])
            .map(
              (e) => OpcionDeCatalogo(
                valor: '${e['codigo'] ?? ''}',
                nombre: '${e['nombre'] ?? ''}',
              ),
            )
            .toList(),
        regimenes: listaDe(j['regimen'])
            .map(
              (e) => OpcionDeCatalogo(
                valor: '${e['id'] ?? ''}',
                nombre: '${e['nombre'] ?? ''}',
              ),
            )
            .toList(),
        bancos: listaDe(j['bancos'])
            .map(
              (e) => OpcionDeCatalogo(
                valor: '${e['id'] ?? ''}',
                nombre: '${e['nombre'] ?? ''}',
              ),
            )
            .toList(),
      );

  String? nombreDeBanco(int? id) {
    if (id == null) return null;
    for (final b in bancos) {
      if (b.valor == '$id') return b.nombre;
    }
    return null;
  }
}

/// Catálogos del domicilio. Los municipios llegan solo del estado que se pide:
/// la tabla completa son miles de filas y no cabe en una respuesta de arranque.
class CatalogosDeDomicilio {
  final List<OpcionDeCatalogo> paises;
  final List<OpcionDeCatalogo> estados;
  final List<OpcionDeCatalogo> municipios;

  const CatalogosDeDomicilio({
    this.paises = const [],
    this.estados = const [],
    this.municipios = const [],
  });
}

// ── Perfil completo ────────────────────────────────────────────────────────

/// Todo lo que la pantalla de Perfil necesita, en una sola lectura.
class PerfilAgente {
  final Activacion activacion;
  final PresentacionAgente presentacion;

  /// Null si el agente no tiene relación registrada con SOZU.
  final CuentaSozu? cuentaSozu;
  final Identidad identidad;
  final DatosFiscales fiscal;
  final List<CuentaDeDispersion> cuentas;
  final Expediente expediente;
  final Capacitacion capacitacion;
  final CatalogosDelPerfil catalogos;

  /// Es su propio perfil (o soporte con acceso completo): puede tocar foto y
  /// presentación.
  final bool puedeEditar;

  /// Su rol tiene el permiso de actualizar el Perfil.
  final bool puedeActualizar;

  /// Cuelga de una inmobiliaria: fiscal y banco los lleva ella.
  final bool esDependiente;
  final String? inmobiliaria;

  const PerfilAgente({
    this.activacion = const Activacion(),
    this.presentacion = const PresentacionAgente(),
    this.cuentaSozu,
    this.identidad = const Identidad(),
    this.fiscal = const DatosFiscales(),
    this.cuentas = const [],
    this.expediente = const Expediente(),
    this.capacitacion = const Capacitacion(),
    this.catalogos = const CatalogosDelPerfil(),
    this.puedeEditar = false,
    this.puedeActualizar = false,
    this.esDependiente = false,
    this.inmobiliaria,
  });

  factory PerfilAgente.desde(Map<String, dynamic> j) {
    final cuenta = j['cuenta_sozu'];
    return PerfilAgente(
      activacion: Activacion.desde(mapaDe(j['activacion'])),
      presentacion: PresentacionAgente.desde(mapaDe(j['hero'])),
      cuentaSozu: cuenta is Map
          ? CuentaSozu.desde(Map<String, dynamic>.from(cuenta))
          : null,
      identidad: Identidad.desde(mapaDe(j['identidad'])),
      fiscal: DatosFiscales.desde(mapaDe(j['fiscal'])),
      cuentas: listaDe(j['bancos']).map(CuentaDeDispersion.desde).toList(),
      expediente: Expediente.desde(mapaDe(j['expediente'])),
      capacitacion: Capacitacion.desde(mapaDe(j['capacitacion'])),
      catalogos: CatalogosDelPerfil.desde(mapaDe(j['catalogos'])),
      puedeEditar: j['can_edit'] == true,
      puedeActualizar: j['can_update'] == true,
      esDependiente: j['es_dependiente'] == true,
      inmobiliaria: j['inmobiliaria_nombre'] as String?,
    );
  }

  /// Puede dar de alta o corregir sus cuentas de dispersión.
  bool get puedeEditarBanco =>
      puedeActualizar && !fiscal.soloLectura && puedeEditar;

  /// Puede tocar sus datos fiscales (hoy: el uso del CFDI y subir la CSF).
  bool get puedeEditarFiscal => puedeEditarBanco;
}

/// Datos fiscales que viajan con la Constancia: los que el servidor extrajo del
/// PDF (`csf_campos`) o los que el agente confirmó al entregarla.
///
/// Lo que el agente escriba GANA sobre lo que el servidor lea del documento: el
/// backend solo escribe lo extraído donde el cuerpo no traiga ya el campo.
class DatosDeConstancia {
  final String? rfc;
  final String? curp;
  final String? nombreLegal;
  final String? regimen;
  final String? codigoPostal;
  final String? calle;
  final String? numExt;
  final String? numInt;
  final String? colonia;

  /// El régimen que leyó el servidor coincide con el catálogo del SAT. En false
  /// NO se guarda: `personas.regimen` guarda la clave, no el texto del PDF.
  final bool regimenResuelto;

  const DatosDeConstancia({
    this.rfc,
    this.curp,
    this.nombreLegal,
    this.regimen,
    this.codigoPostal,
    this.calle,
    this.numExt,
    this.numInt,
    this.colonia,
    this.regimenResuelto = false,
  });

  factory DatosDeConstancia.desde(Map<String, dynamic> j) => DatosDeConstancia(
    rfc: j['rfc'] as String?,
    curp: j['curp'] as String?,
    nombreLegal: j['nombre'] as String?,
    regimen: j['regimen'] as String?,
    codigoPostal: j['codigo_postal'] as String?,
    calle: j['calle'] as String?,
    numExt: j['num_ext'] as String?,
    numInt: j['num_int'] as String?,
    colonia: j['colonia'] as String?,
    regimenResuelto: j['regimen_resuelto'] == true,
  );

  bool get vacio => [
    rfc,
    curp,
    nombreLegal,
    regimen,
    codigoPostal,
    calle,
    numExt,
    numInt,
    colonia,
  ].every((v) => (v ?? '').trim().isEmpty);

  /// Cómo se le resume al agente lo que quedó capturado del documento.
  List<String> get resumen => [
    if ((rfc ?? '').isNotEmpty) 'RFC',
    if ((curp ?? '').isNotEmpty) 'CURP',
    if ((nombreLegal ?? '').isNotEmpty) 'nombre',
    if ((regimen ?? '').isNotEmpty && regimenResuelto) 'régimen',
    if ((codigoPostal ?? '').isNotEmpty ||
        (calle ?? '').isNotEmpty ||
        (colonia ?? '').isNotEmpty)
      'domicilio fiscal',
  ];
}

/// Veredicto del backend al entregar un documento del expediente.
///
/// Con la Constancia el servidor lee el PDF y decide él mismo si la valida: el
/// app no propone estatus. [constanciaValidada], [motivo] y [campos] llegan
/// AUSENTES del JSON cuando no aplican, así que null es un dato, no un hueco.
class ResultadoDeCarga {
  final EstadoDocumento estado;

  /// Solo en la Constancia: el servidor la validó él mismo. Null cuando el
  /// documento no es una Constancia.
  final bool? constanciaValidada;

  /// Por qué no la pudo validar, ya redactado para el agente.
  final String? motivo;

  /// Lo que el servidor extrajo del documento y ya guardó.
  final DatosDeConstancia? campos;

  const ResultadoDeCarga({
    this.estado = EstadoDocumento.pendiente,
    this.constanciaValidada,
    this.motivo,
    this.campos,
  });

  factory ResultadoDeCarga.desde(Map<String, dynamic> j) {
    final campos = j['csf_campos'];
    return ResultadoDeCarga(
      estado: EstadoDocumento.desde(j['estatus']),
      constanciaValidada: j.containsKey('csf_validada')
          ? j['csf_validada'] == true
          : null,
      motivo: j['csf_motivo'] as String?,
      campos: campos is Map
          ? DatosDeConstancia.desde(Map<String, dynamic>.from(campos))
          : null,
    );
  }
}

// ── Puerto ─────────────────────────────────────────────────────────────────

/// Perfil del agente que está usando el portal (o el que un admin está viendo:
/// la instancia ya sabe de quién se trata, ningún método recibe ese objetivo).
///
/// Todos los métodos lanzan `ApiError` con el código del backend; los textos los
/// decide la pantalla.
///
/// Los datos fiscales tienen DOS caminos y no compiten: [guardarFiscal] es el
/// capturador (lo que el agente escribe, y lo que cierra su paso fiscal) y
/// [subirDocumento] con [TiposDocumento.constanciaFiscal] es el documento que los
/// respalda, del que el servidor los lee solo. Lo que el agente escriba gana.
abstract interface class PerfilAgentePort {
  /// Lectura completa del perfil.
  Future<PerfilAgente> cargar();

  /// Catálogos del domicilio. Sin [idEstado] no llegan municipios.
  Future<CatalogosDeDomicilio> catalogosDeDomicilio({int? idEstado});

  /// Datos personales y domicilio particular.
  Future<void> guardarIdentidad({
    required String nombreLegal,
    required String telefono,
    required String curp,
    DateTime? fechaNacimiento,
    String? sexo,
    Domicilio? domicilio,
  });

  /// Uso del CFDI con el que el agente factura.
  Future<void> guardarUsoCfdi(String? codigo);

  /// Datos fiscales completos: RFC, régimen, uso del CFDI y domicilio fiscal.
  /// Es el paso que le habilita las comisiones al agente independiente.
  ///
  /// Todo es obligatorio menos [Domicilio.numInt]. El agente dependiente recibe
  /// `forbidden_field`: esos datos los lleva su inmobiliaria.
  Future<void> guardarFiscal({
    required String rfc,
    required String regimen,
    required String usoCfdi,
    required Domicilio domicilio,
  });

  /// Frase de presentación. Devuelve la que quedó guardada.
  Future<String?> guardarPresentacion(String? frase);

  /// Foto de perfil. Devuelve su URL.
  Future<String?> guardarFoto({required String base64, required String mime});

  /// Quita la foto: el agente vuelve a mostrar su inicial.
  Future<void> borrarFoto();

  /// Entrega un documento del expediente y devuelve el veredicto del servidor.
  ///
  /// El estatus NO se propone desde el app: con la Constancia el servidor lee el
  /// PDF y la valida él mismo. [datos] solo aplica a la Constancia, y lo que
  /// traiga gana sobre lo que el servidor extraiga.
  Future<ResultadoDeCarga> subirDocumento({
    required int tipo,
    required String base64,
    required String nombre,
    String? contentType,
    DatosDeConstancia? datos,
  });

  /// Alta ([id] nulo) o corrección de una cuenta de dispersión. Devuelve su id.
  Future<int> guardarCuentaBancaria({
    int? id,
    required int idBanco,
    required String numeroCuenta,
    required String titular,
    String? clabe,
    String? evidenciaBase64,
    String? evidenciaNombre,
    String? evidenciaContentType,
  });

  /// Baja de una cuenta de dispersión. Una cuenta ya validada solo la baja SOZU.
  Future<void> borrarCuentaBancaria(int id);

  /// Genera la Carta de comercialización y devuelve dónde firmarla. Generarla
  /// dos veces cuesta una verificación de identidad, así que si ya hay una en
  /// curso el backend reusa esa.
  Future<FirmaDeCarta> iniciarFirmaDeCarta({String? firmaAutografa});

  /// Consulta en qué va la firma. [cargar] NO la sincroniza: para saber si el
  /// agente ya firmó hay que llamar aquí.
  Future<FirmaDeCarta> consultarFirmaDeCarta();
}
