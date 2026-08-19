import 'dart:typed_data';

import 'package:sozu_agente_app/shared/json.dart';

/// Por qué el agente no puede ver sus comisiones todavía, con la lista de lo que
/// le falta ("Identidad", "Cuenta bancaria"…).
///
/// Es un estado de la pantalla y no un error: el agente no hizo nada mal, le
/// falta terminar su expediente.
class BloqueoComisiones {
  final String motivo;
  final List<String> faltantes;

  const BloqueoComisiones({this.motivo = '', this.faltantes = const []});

  factory BloqueoComisiones.desdeJson(Map<String, dynamic> j) =>
      BloqueoComisiones(
        motivo: (j['motivo'] ?? '') as String,
        faltantes: (j['faltantes'] as List?)?.cast<String>() ?? const [],
      );
}

/// Dinero del agente: lo que ya cobró y lo que tiene por cobrar.
class TotalesComisiones {
  final double cobrado;
  final double porCobrar;

  const TotalesComisiones({this.cobrado = 0, this.porCobrar = 0});

  factory TotalesComisiones.desdeJson(Map<String, dynamic> j) =>
      TotalesComisiones(
        cobrado: numDe(j['cobrado']),
        porCobrar: numDe(j['por_cobrar']),
      );
}

/// Opción de un filtro con su valor interno y su rótulo.
class OpcionFiltro {
  final String valor;
  final String etiqueta;

  const OpcionFiltro({required this.valor, required this.etiqueta});

  factory OpcionFiltro.desdeJson(Map<String, dynamic> j) => OpcionFiltro(
    valor: (j['valor'] ?? '') as String,
    etiqueta: (j['etiqueta'] ?? '') as String,
  );
}

/// Valores que existen en las comisiones del agente, para no ofrecer filtros que
/// no devolverían nada.
class CatalogoFiltros {
  final List<String> proyectos;
  final List<OpcionFiltro> estatus;

  const CatalogoFiltros({this.proyectos = const [], this.estatus = const []});

  factory CatalogoFiltros.desdeJson(Map<String, dynamic> j) => CatalogoFiltros(
    proyectos: (j['proyectos'] as List?)?.cast<String>() ?? const [],
    estatus: listaDe(j['estatus']).map(OpcionFiltro.desdeJson).toList(),
  );
}

/// Comprador de la operación que generó la comisión.
class ClienteComision {
  final String nombre;
  final String email;

  /// Porcentaje de copropiedad. En una operación a nombre de dos personas
  /// explica por qué el mismo cliente aparece dos veces.
  final double porcentaje;

  const ClienteComision({
    this.nombre = '',
    this.email = '',
    this.porcentaje = 0,
  });

  factory ClienteComision.desdeJson(Map<String, dynamic> j) => ClienteComision(
    nombre: (j['nombre'] ?? '') as String,
    email: (j['email'] ?? '') as String,
    porcentaje: numDe(j['porcentaje']),
  );
}

/// En qué punto del camino va una comisión. Son los cuatro estados que el agente
/// distingue, ya resueltos por el backend a partir de un estatus más fino.
enum EtapaComision { pagada, aprobado, enRevision, pendiente }

extension EtapaComisionX on EtapaComision {
  /// Nombre de la etapa en el contrato. Es la clave con la que llegan las
  /// opciones del filtro de estatus, así que la traducción vive aquí, junto al
  /// parser, y no repartida por la pantalla.
  String get clave => switch (this) {
    EtapaComision.pagada => 'pagada',
    EtapaComision.aprobado => 'aprobado',
    EtapaComision.enRevision => 'en_revision',
    EtapaComision.pendiente => 'pendiente',
  };
}

EtapaComision _etapaDe(Object? valor) => switch (valor) {
  'pagada' => EtapaComision.pagada,
  'aprobado' => EtapaComision.aprobado,
  'en_revision' => EtapaComision.enRevision,
  _ => EtapaComision.pendiente,
};

/// Llave por la que se ordena el listado: las seis columnas ordenables de la
/// tabla del portal web.
enum OrdenComisiones {
  folio,
  proyecto,
  cliente,
  precioFinal,
  montoComision,
  fechaPago,
}

extension OrdenComisionesX on OrdenComisiones {
  /// Rótulo de la llave, para el desplegable de "Ordenar por".
  String get etiqueta => switch (this) {
    OrdenComisiones.folio => 'Folio',
    OrdenComisiones.proyecto => 'Proyecto',
    OrdenComisiones.cliente => 'Cliente',
    OrdenComisiones.precioFinal => 'Precio final',
    OrdenComisiones.montoComision => 'Monto de comisión',
    OrdenComisiones.fechaPago => 'Fecha de pago',
  };

  /// Compara dos comisiones por esta llave, en ascendente. Espeja los
  /// `sortAccessor` de la tabla web: el folio por el id de la cuenta, proyecto y
  /// cliente en minúsculas, y la fecha ausente al valor cero.
  int comparar(Comision a, Comision b) => switch (this) {
    OrdenComisiones.folio => a.idCuentaCobranza.compareTo(b.idCuentaCobranza),
    OrdenComisiones.proyecto => a.proyecto.toLowerCase().compareTo(
      b.proyecto.toLowerCase(),
    ),
    OrdenComisiones.cliente => _primerCliente(a).compareTo(_primerCliente(b)),
    OrdenComisiones.precioFinal => a.precioFinal.compareTo(b.precioFinal),
    OrdenComisiones.montoComision => a.montoComision.compareTo(b.montoComision),
    OrdenComisiones.fechaPago => _fechaOrdenable(
      a.fechaPago,
    ).compareTo(_fechaOrdenable(b.fechaPago)),
  };
}

/// Nombre del primer comprador en minúsculas, o vacío si la operación no trae
/// clientes: es lo que ordena la columna "Cliente" de la web.
String _primerCliente(Comision c) =>
    (c.clientes.isEmpty ? '' : c.clientes.first.nombre).toLowerCase();

/// Fecha de pago comparable. La comisión sin pagar vale 0 y queda primero en
/// ascendente, igual que el `fecha_pago ? getTime() : 0` de la web.
int _fechaOrdenable(String? fecha) =>
    DateTime.tryParse(fecha ?? '')?.millisecondsSinceEpoch ?? 0;

/// Una comisión del agente: la operación que la generó, cuánto es y cómo va.
class Comision {
  final int idCuentaCobranza;

  /// Folio de la cuenta de cobranza (`CC-000123` / `CCP-000123`).
  final String folio;

  final String proyecto;
  final String propiedad;
  final String productoNombre;
  final double precioFinal;
  final double porcentajeComision;
  final double montoComision;
  final EtapaComision etapa;

  /// Rótulo de la etapa tal como lo redacta el backend. Se usa tal cual: si la
  /// app lo reescribiera, el mismo estado se llamaría distinto en cada cliente.
  final String etapaEtiqueta;

  /// URL firmada de la factura que subió el agente, o null si no hay.
  final String? facturaUrl;

  /// URL firmada del comprobante de pago que subió SOZU. El agente nunca sube
  /// aquí: es su prueba de que le pagaron.
  final String? comprobanteUrl;

  /// `YYYY-MM-DD`, solo cuando la comisión ya se pagó.
  final String? fechaPago;

  final List<ClienteComision> clientes;

  /// Lo decide el backend con las mismas reglas que la web. La pantalla NO lo
  /// recalcula: duplicar la regla es garantizar que se desincronice.
  final bool puedeSubirFactura;

  const Comision({
    required this.idCuentaCobranza,
    this.folio = '',
    this.proyecto = '',
    this.propiedad = '',
    this.productoNombre = '',
    this.precioFinal = 0,
    this.porcentajeComision = 0,
    this.montoComision = 0,
    this.etapa = EtapaComision.pendiente,
    this.etapaEtiqueta = '',
    this.facturaUrl,
    this.comprobanteUrl,
    this.fechaPago,
    this.clientes = const [],
    this.puedeSubirFactura = false,
  });

  factory Comision.desdeJson(Map<String, dynamic> j) => Comision(
    idCuentaCobranza: intDe(j['id_cuenta_cobranza']) ?? 0,
    folio: (j['cuenta_label'] ?? '') as String,
    proyecto: (j['proyecto'] ?? '') as String,
    propiedad: (j['propiedad'] ?? '') as String,
    productoNombre: (j['producto_nombre'] ?? '') as String,
    precioFinal: numDe(j['precio_final']),
    porcentajeComision: numDe(j['porcentaje_comision']),
    montoComision: numDe(j['monto_comision']),
    etapa: _etapaDe(j['estatus_bucket']),
    etapaEtiqueta: (j['estatus_etiqueta'] ?? '') as String,
    facturaUrl: j['factura_url'] as String?,
    comprobanteUrl: j['url_evidencia_pago'] as String?,
    fechaPago: j['fecha_pago'] as String?,
    clientes: listaDe(j['clientes']).map(ClienteComision.desdeJson).toList(),
    puedeSubirFactura: j['puede_subir_factura'] == true,
  );

  /// Qué se vendió: el número de propiedad, o el nombre del producto cuando la
  /// operación no fue de una unidad.
  String get unidad => propiedad.isNotEmpty ? propiedad : productoNombre;

  /// ¿Alguno de sus clientes coincide con lo que se escribió en el buscador?
  bool coincideCliente(String texto) {
    final q = texto.trim().toLowerCase();
    if (q.isEmpty) return true;
    return clientes.any(
      (c) =>
          c.nombre.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q),
    );
  }
}

/// Todo lo que necesita la pantalla de Comisiones en una sola carga.
class ComisionesAgente {
  /// null = el agente sí puede ver sus comisiones.
  final BloqueoComisiones? bloqueo;

  final TotalesComisiones totales;
  final CatalogoFiltros filtros;
  final List<Comision> comisiones;

  const ComisionesAgente({
    this.bloqueo,
    this.totales = const TotalesComisiones(),
    this.filtros = const CatalogoFiltros(),
    this.comisiones = const [],
  });

  factory ComisionesAgente.desdeJson(Map<String, dynamic> j) {
    final bloqueo = j['bloqueo'];
    return ComisionesAgente(
      bloqueo: bloqueo == null
          ? null
          : BloqueoComisiones.desdeJson(mapaDe(bloqueo)),
      totales: TotalesComisiones.desdeJson(mapaDe(j['totales'])),
      filtros: CatalogoFiltros.desdeJson(mapaDe(j['filtros'])),
      comisiones: listaDe(j['comisiones']).map(Comision.desdeJson).toList(),
    );
  }
}

/// Comisiones del agente y la carga de su factura.
///
/// La instancia queda atada al agente que se está viendo (el propio, o el que
/// impersona un administrador), así que ningún método recibe ese destinatario.
/// Todos lanzan `ApiError`.
abstract interface class ComisionesPort {
  /// Comisiones, totales, filtros disponibles y el bloqueo de perfil si aplica.
  Future<ComisionesAgente> cargarComisiones();

  /// Sube la factura de una comisión. Devuelve la URL firmada del archivo
  /// guardado, o null si el backend no la regresó.
  Future<String?> subirFactura({
    required int idCuentaCobranza,
    required String nombreArchivo,
    required Uint8List archivo,
  });
}
