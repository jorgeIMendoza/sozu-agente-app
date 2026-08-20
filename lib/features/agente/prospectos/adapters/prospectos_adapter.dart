import 'dart:convert';

import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/shared/adapters/edge_function.dart';

/// Implementación de [ProspectosPort] sobre la Edge Function
/// `agente-prospectos` (y, para el catálogo de desarrollos vinculables,
/// `agente-inventario`).
///
/// Es el ÚNICO archivo de la feature que conoce el transporte: el formato de
/// las notas (HTML con los adjuntos embebidos) y el base64 de los archivos se
/// arman y se leen aquí, no en la UI ni en el puerto.
class ProspectosAdapter implements ProspectosPort {
  final EdgeFunctions _fn;

  ProspectosAdapter({int? impersonate})
    : _fn = EdgeFunctions(impersonate: impersonate);

  Future<Map<String, dynamic>> _accion(
    String accion, [
    Map<String, dynamic> extra = const {},
  ]) => _fn.call('agente-prospectos', body: {'action': accion, ...extra});

  @override
  Future<CarteraProspectos> cartera({
    String? busqueda,
    int? idEstadoLead,
    int? idDesarrollo,
    int limite = 500,
    int desde = 0,
  }) async {
    final res = await _accion('lista', {
      if (busqueda != null && busqueda.isNotEmpty) 'search': busqueda,
      if (idEstadoLead != null) 'id_estatus': idEstadoLead,
      if (idDesarrollo != null) 'id_proyecto': idDesarrollo,
      'limit': limite,
      'offset': desde,
    });
    return CarteraProspectos.fromJson(res);
  }

  @override
  Future<DetalleProspecto> detalle(int idPersona) async =>
      DetalleProspecto.fromJson(
        await _accion('detalle', {'id_persona': idPersona}),
      );

  @override
  Future<int> crear({
    required DatosProspecto datos,
    required List<int> desarrollos,
  }) async {
    final res = await _accion('crear', {
      'persona': _persona(datos),
      'proyectos': desarrollos,
    });
    return intDe(res['id_persona']) ?? 0;
  }

  @override
  Future<void> editar({
    required int idPersona,
    required DatosProspecto datos,
    List<int>? desarrollos,
  }) async {
    await _accion('editar', {
      'id_persona': idPersona,
      'persona': _persona(datos),
      if (desarrollos != null) 'proyectos': desarrollos,
    });
  }

  @override
  Future<void> cambiarEstadoLead({
    required int idRelacion,
    required int idEstadoLead,
  }) async {
    await _accion('set_estatus', {
      'id_entidad_relacionada': idRelacion,
      'id_estatus_lead': idEstadoLead,
    });
  }

  @override
  Future<void> transferir({
    required int idRelacion,
    required String idAgenteDestino,
    String? motivo,
  }) async {
    await _accion('reasignar', {
      'id_entidad_relacionada': idRelacion,
      'nuevo_propietario': idAgenteDestino,
      if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
    });
  }

  @override
  Future<List<AgenteDestino>> agentesDestino() async {
    final res = await _accion('agentes_asignables');
    return listaDe(res['agentes'])
        .map(AgenteDestino.fromJson)
        .where((a) => a.id.isNotEmpty)
        .toList(growable: false);
  }

  /// El servicio de prospectos no publica el catálogo de desarrollos, así que
  /// se toma del inventario del agente, ya filtrado por sus accesos.
  ///
  /// NO es la misma lista que la web: el inventario solo devuelve desarrollos
  /// con `publicar = true` y con unidades cargadas, mientras la web ofrece todo
  /// proyecto activo con acceso. Un desarrollo accesible pero despublicado, o
  /// sin inventario, se puede ligar desde la web y desde aquí no. Se cierra
  /// cuando `agente-prospectos` publique su propio catálogo.
  @override
  Future<List<DesarrolloVinculable>> desarrollosVinculables() async {
    final res = await _fn.call(
      'agente-inventario',
      body: {'vista': 'proyectos'},
    );
    final desarrollos = listaDe(res['proyectos'])
        .map(
          (p) => DesarrolloVinculable(
            id: intDe(p['id']) ?? 0,
            nombre: (p['nombre'] ?? '') as String,
          ),
        )
        .where((d) => d.id != 0)
        .toList();
    desarrollos.sort((a, b) => a.nombre.compareTo(b.nombre));
    return desarrollos;
  }

  @override
  Future<void> agregarNota({
    required int idPersona,
    int? idRelacion,
    String texto = '',
    List<AdjuntoNuevo> adjuntos = const [],
  }) async {
    await _accion('nota_crear', {
      'id_persona': idPersona,
      if (idRelacion != null) 'id_entidad_relacionada': idRelacion,
      'contenido': _parrafos(texto),
      if (adjuntos.isNotEmpty)
        'adjuntos': [
          for (final a in adjuntos)
            {
              'nombre': a.nombre,
              'content_type': a.contentType,
              'base64': base64Encode(a.bytes),
            },
        ],
    });
  }

  @override
  Future<void> editarNota({
    required int idNota,
    required String texto,
    String? cuerpoConFormato,
    List<AdjuntoNota> adjuntos = const [],
  }) async {
    // La edición REEMPLAZA el contenido y los adjuntos viven dentro de él, así
    // que se vuelven a escribir sus enlaces. El servidor los re-firma al leer
    // (extrae bucket y ruta de la URL guardada), por eso conservar el enlace
    // temporal no rompe el archivo.
    final cuerpo = cuerpoConFormato ?? _parrafos(texto);
    await _accion('nota_editar', {
      'id_nota': idNota,
      'contenido': '$cuerpo${_htmlDeAdjuntos(adjuntos)}',
    });
  }

  @override
  Future<void> eliminarNota(int idNota) async =>
      _accion('nota_borrar', {'id_nota': idNota}).then((_) {});

  Map<String, dynamic> _persona(DatosProspecto d) => {
    'tipo_persona': d.tipoPersona,
    'nombre_legal': d.nombre,
    'email': d.email,
    'telefono': d.telefono,
    'clave_pais_telefono': d.clavePaisTelefono,
    'rfc': d.rfc,
    'curp': d.curp,
  };

  /// Texto del agente a párrafos HTML, que es como la plataforma guarda las
  /// notas. Se escapa siempre: un `<` escrito por el agente rompería el
  /// contenido de la nota para todos los que la lean después.
  static String _parrafos(String texto) {
    final lineas = texto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    return lineas.map((l) => '<p>${_escapar(l)}</p>').join();
  }

  static String _htmlDeAdjuntos(List<AdjuntoNota> adjuntos) => adjuntos
      .map(
        (a) => a.esImagen
            ? '<p><img src="${a.url}" /></p>'
            : '<p><a href="${a.url}" class="crm-attachment" '
                  'target="_blank" rel="noopener noreferrer">'
                  '\u{1F4CE} ${_escapar(a.nombre)}</a></p>',
      )
      .join();

  static String _escapar(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
