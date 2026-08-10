import 'package:sozu_agente_app/shared/adapters/edge_function.dart';

/// Rutas del portal. Son las mismas que las del portal web (`/admin/agent/*`)
/// SIN el prefijo, porque `submenus.vista_front_end` en la BD guarda la ruta
/// web y el permiso se resuelve por esa clave: si aquí se inventaran rutas
/// nuevas, ningún permiso casaría y el portal saldría vacío para todos.
abstract final class VistaAgente {
  static const inicio = '/admin/agent/inicio';
  static const inventario = '/admin/agent/inventario';
  static const pipeline = '/admin/agent/pipeline';
  static const prospectos = '/admin/agent/prospectos';
  static const comisiones = '/admin/agent/comisiones';
  static const perfil = '/admin/agent/perfil';

  /// Ruta del app (go_router) para cada vista de la BD.
  static const rutaApp = <String, String>{
    inicio: '/inicio',
    inventario: '/inventario',
    pipeline: '/pipeline',
    prospectos: '/prospectos',
    comisiones: '/comisiones',
    perfil: '/perfil',
  };
}

/// Permisos efectivos de una vista. Espejo de `useAgentPortalPermissions` del
/// portal web: salen de `submenus_permisos` para el rol EFECTIVO, y sin al menos
/// `leer` la vista no existe para ese rol.
class PermisosVista {
  final bool leer;
  final bool crear;
  final bool actualizar;
  final bool eliminar;
  final bool generarOferta;
  final bool generarOfertaDigital;

  const PermisosVista({
    this.leer = false,
    this.crear = false,
    this.actualizar = false,
    this.eliminar = false,
    this.generarOferta = false,
    this.generarOfertaDigital = false,
  });

  factory PermisosVista.fromJson(Map<String, dynamic> j) => PermisosVista(
    leer: j['leer'] == true,
    crear: j['crear'] == true,
    actualizar: j['actualizar'] == true,
    eliminar: j['eliminar'] == true,
    generarOferta: j['generar_oferta'] == true,
    generarOfertaDigital: j['generar_oferta_digital'] == true,
  );

  static const todo = PermisosVista(
    leer: true,
    crear: true,
    actualizar: true,
    eliminar: true,
    generarOferta: true,
    generarOfertaDigital: true,
  );
}

/// Identidad del agente cuyos datos se están sirviendo. Cuando un admin
/// impersona, es la del agente impersonado — no la del admin.
class IdentidadAgente {
  final String email;
  final int? idPersona;
  final String? authUserId;
  final int? rolId;
  final String? rolNombre;

  /// Rol 3: aliado externo. Distinto de [esDependiente]: el 3 puede ser
  /// independiente (sin inmobiliaria detrás) y entonces administra sus propios
  /// datos fiscales y ve sus comisiones.
  final bool esAgenteInmobiliario;

  /// Cuelga de una inmobiliaria (`entidades_relacionadas.id_persona_duena_lead`).
  /// El portal le esconde Comisiones y le pone en solo-lectura fiscal y banco.
  final bool esDependiente;
  final String? inmobiliariaNombre;

  const IdentidadAgente({
    required this.email,
    this.idPersona,
    this.authUserId,
    this.rolId,
    this.rolNombre,
    this.esAgenteInmobiliario = false,
    this.esDependiente = false,
    this.inmobiliariaNombre,
  });

  factory IdentidadAgente.fromJson(Map<String, dynamic> j) => IdentidadAgente(
    email: (j['email'] ?? '') as String,
    idPersona: intDe(j['id_persona']),
    authUserId: j['auth_user_id'] as String?,
    rolId: intDe(j['rol_id']),
    rolNombre: j['rol_nombre'] as String?,
    esAgenteInmobiliario: j['es_agente_inmobiliario'] == true,
    esDependiente: j['es_dependiente'] == true,
    inmobiliariaNombre: j['inmobiliaria_nombre'] as String?,
  );
}

/// Recortes de vista del agente dependiente. `notas` explica al usuario POR QUÉ
/// un campo está en solo lectura ("La administra {inmobiliaria}"): sin la nota,
/// un campo gris sin explicación se reporta como bug.
class Restricciones {
  final List<String> rutasOcultas;
  final Map<String, String> soloLectura;

  const Restricciones({
    this.rutasOcultas = const [],
    this.soloLectura = const {},
  });

  factory Restricciones.fromJson(Map<String, dynamic> j) {
    final ro = mapaDe(j['read_only']);
    return Restricciones(
      rutasOcultas: (j['hidden_paths'] as List?)?.cast<String>() ?? const [],
      soloLectura: {
        for (final e in ro.entries)
          if (e.value != null) e.key: '${e.value}',
      },
    );
  }

  /// Nota de solo-lectura de un campo (`csf`, `fiscal`, `banco`, `carta`), o
  /// null si el agente sí puede editarlo.
  String? nota(String campo) => soloLectura[campo];
}

/// Paso del expediente de activación del agente.
class PasoOnboarding {
  final String clave;
  final String nombre;
  final bool completo;
  final List<String> faltantes;

  const PasoOnboarding({
    required this.clave,
    required this.nombre,
    this.completo = false,
    this.faltantes = const [],
  });

  factory PasoOnboarding.fromJson(Map<String, dynamic> j) => PasoOnboarding(
    clave: (j['clave'] ?? '') as String,
    nombre: (j['nombre'] ?? '') as String,
    completo: j['completo'] == true,
    faltantes: (j['faltantes'] as List?)?.cast<String>() ?? const [],
  );
}

/// Estado de activación. Gatea pantallas completas, no solo el badge: sin
/// capacitación no se puede generar oferta, y sin expediente completo no se ven
/// las comisiones.
class Onboarding {
  final int porcentaje;
  final List<PasoOnboarding> pasos;
  final bool puedeVerComisiones;
  final bool capacitacionCompleta;
  final bool identidadBasicaCompleta;
  final List<String> faltantesParaComisiones;

  const Onboarding({
    this.porcentaje = 0,
    this.pasos = const [],
    this.puedeVerComisiones = false,
    this.capacitacionCompleta = false,
    this.identidadBasicaCompleta = false,
    this.faltantesParaComisiones = const [],
  });

  factory Onboarding.fromJson(Map<String, dynamic> j) => Onboarding(
    porcentaje: intDe(j['percentage']) ?? 0,
    pasos: listaDe(j['steps']).map(PasoOnboarding.fromJson).toList(),
    puedeVerComisiones: j['can_access_comisiones'] == true,
    capacitacionCompleta: j['has_training_complete'] == true,
    identidadBasicaCompleta: j['has_basic_identity_complete'] == true,
    faltantesParaComisiones:
        (j['missing_for_comisiones'] as List?)?.cast<String>() ?? const [],
  );

  /// El badge "Verificado" del encabezado: solo al 100%.
  bool get verificado => porcentaje >= 100;
}

/// Encabezado del portal: foto, nombre y frase de presentación del agente.
class HeaderAgente {
  final String? nombre;
  final String? fotoPerfilUrl;
  final String? frasePerfil;
  final String? rol;

  const HeaderAgente({
    this.nombre,
    this.fotoPerfilUrl,
    this.frasePerfil,
    this.rol,
  });

  factory HeaderAgente.fromJson(Map<String, dynamic> j) => HeaderAgente(
    nombre: j['nombre'] as String?,
    fotoPerfilUrl: j['foto_perfil_url'] as String?,
    frasePerfil: j['frase_perfil'] as String?,
    rol: j['rol'] as String?,
  );
}

/// Agente que un admin puede ver ("Ver como agente").
class AgenteImpersonable {
  final String email;
  final String nombre;
  final int idPersona;
  final int? rolId;

  const AgenteImpersonable({
    required this.email,
    required this.nombre,
    required this.idPersona,
    this.rolId,
  });

  factory AgenteImpersonable.fromJson(Map<String, dynamic> j) =>
      AgenteImpersonable(
        email: (j['email'] ?? '') as String,
        nombre: (j['nombre'] ?? '') as String,
        idPersona: intDe(j['id_persona']) ?? 0,
        rolId: intDe(j['rol_id']),
      );
}

/// Todo lo que el portal necesita saber al abrir: identidad, permisos, tabs
/// visibles, recortes, activación y proyectos accesibles. Una sola llamada en
/// vez del waterfall de ocho consultas que hace el portal web en su layout.
class SesionAgente {
  final IdentidadAgente identidad;
  final Map<String, PermisosVista> permisos;
  final Restricciones restricciones;
  final bool accesoTotal;
  final HeaderAgente header;
  final Onboarding onboarding;

  /// Ids de proyecto a los que tiene acceso; null = todos (rol irrestricto).
  final List<int>? proyectosAccesibles;

  /// Agentes que puede ver un admin; null si no administra la app.
  final List<AgenteImpersonable>? impersonables;

  const SesionAgente({
    required this.identidad,
    this.permisos = const {},
    this.restricciones = const Restricciones(),
    this.accesoTotal = false,
    this.header = const HeaderAgente(),
    this.onboarding = const Onboarding(),
    this.proyectosAccesibles,
    this.impersonables,
  });

  factory SesionAgente.fromJson(Map<String, dynamic> j) {
    final permisosRaw = mapaDe(j['permisos']);
    return SesionAgente(
      identidad: IdentidadAgente.fromJson(mapaDe(j['identity'])),
      permisos: {
        for (final e in permisosRaw.entries)
          e.key: PermisosVista.fromJson(mapaDe(e.value)),
      },
      restricciones: Restricciones.fromJson(mapaDe(j['restricciones'])),
      accesoTotal: j['full_access'] == true,
      header: HeaderAgente.fromJson(mapaDe(j['header'])),
      onboarding: Onboarding.fromJson(mapaDe(j['onboarding'])),
      proyectosAccesibles: (j['proyectos_accesibles'] as List?)
          ?.map(intDe)
          .whereType<int>()
          .toList(),
      impersonables: j['impersonables'] == null
          ? null
          : listaDe(j['impersonables']).map(AgenteImpersonable.fromJson).toList(),
    );
  }

  /// Permisos de una vista (`VistaAgente.*`). El acceso total (super admin o
  /// rol con `puede_impersonar`) no consulta permisos: los tiene todos.
  PermisosVista permisosDe(String vista) {
    if (accesoTotal) return PermisosVista.todo;
    return permisos[vista] ?? const PermisosVista();
  }

  /// ¿Se muestra el tab de esa vista? Necesita `leer` y no estar recortada.
  bool vistaVisible(String vista) {
    if (restricciones.rutasOcultas.contains(vista)) return false;
    return permisosDe(vista).leer;
  }
}

/// Bootstrap del portal. Un solo método: se llama al entrar y en cada cambio de
/// agente impersonado.
abstract interface class SesionPort {
  Future<SesionAgente> cargar();
}
