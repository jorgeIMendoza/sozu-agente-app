import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

/// Reglas del CRM de prospectos que no son interfaz: filtros de la cartera,
/// conteos del encabezado, validación de la ficha y traducción de los códigos
/// del servidor. Sin `material.dart`, para poder probarlas solas.

/// Conteo del encabezado de la cartera ("N prospectos · N unidades · N con
/// compra"). Se calcula sobre lo FILTRADO, no sobre la cartera completa: el
/// número tiene que corresponder con lo que se está viendo.
class TotalesCartera {
  final int prospectos;
  final int unidades;
  final int conCompra;

  const TotalesCartera({
    this.prospectos = 0,
    this.unidades = 0,
    this.conCompra = 0,
  });

  factory TotalesCartera.de(List<Prospecto> filtrados) => TotalesCartera(
    prospectos: filtrados.length,
    unidades: filtrados.fold(0, (n, p) => n + p.totalUnidades),
    conCompra: filtrados.where((p) => p.esCliente).length,
  );

  /// "12 prospectos · 3 unidades · 1 con compra".
  String get resumen =>
      '$prospectos ${prospectos == 1 ? 'prospecto' : 'prospectos'} · '
      '$unidades ${unidades == 1 ? 'unidad' : 'unidades'} · '
      '$conCompra con compra';
}

/// Filtra la cartera por texto libre, estado del lead y desarrollo.
///
/// El texto busca en nombre, correo, teléfono y nombre de desarrollo; los otros
/// dos aciertan si CUALQUIERA de sus desarrollos cumple, porque el filtro es
/// sobre la persona y el estado vive en la relación persona × desarrollo.
List<Prospecto> filtrarProspectos(
  List<Prospecto> prospectos, {
  String busqueda = '',
  int? idEstadoLead,
  int? idDesarrollo,
}) {
  final q = busqueda.trim().toLowerCase();
  return prospectos
      .where((p) {
        if (q.isNotEmpty) {
          final coincide =
              p.nombre.toLowerCase().contains(q) ||
              (p.email ?? '').toLowerCase().contains(q) ||
              (p.telefono ?? '').toLowerCase().contains(q) ||
              p.desarrollos.any((d) => d.desarrollo.toLowerCase().contains(q));
          if (!coincide) return false;
        }
        if (idEstadoLead != null &&
            !p.desarrollos.any((d) => d.idEstadoLead == idEstadoLead)) {
          return false;
        }
        if (idDesarrollo != null &&
            !p.desarrollos.any((d) => d.idDesarrollo == idDesarrollo)) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

/// Desarrollos presentes en la cartera, para el filtro de la barra. Se arma con
/// lo que hay en las filas: ofrecer desarrollos sin prospectos solo produce
/// listas vacías.
List<({int id, String nombre})> desarrollosDeLaCartera(
  List<Prospecto> prospectos,
) {
  final porId = <int, String>{};
  for (final p in prospectos) {
    for (final d in p.desarrollos) {
      if (d.idDesarrollo != null) porId[d.idDesarrollo!] = d.desarrollo;
    }
  }
  final lista = porId.entries.map((e) => (id: e.key, nombre: e.value)).toList();
  lista.sort((a, b) => a.nombre.compareTo(b.nombre));
  return lista;
}

/// Etapas del pipeline de ventas, en orden. Espejo de `ETAPAS` del portal web:
/// la etapa la calcula el servidor y aquí solo se traduce a su nombre.
const Map<String, String> etapasPipeline = {
  'nuevo': 'Nuevo',
  'contactado': 'Contactado',
  'cita_programada': 'Cita programada',
  'cita_asistida': 'Asistió a la cita',
  'negociando': 'Negociando',
  'oferta_enviada': 'Oferta enviada',
  'apartado_pagado': 'Apartado pagado',
  'enganche_contrato': 'Enganche y contrato',
  'ganado': 'Cierre ganado',
  'perdido': 'Cierre perdido',
};

/// Nombre de una etapa; una clave desconocida se humaniza en vez de mostrarse
/// como slug.
String etiquetaEtapa(String clave) {
  final fija = etapasPipeline[clave];
  if (fija != null) return fija;
  final t = clave.replaceAll('_', ' ').trim();
  return t.isEmpty ? 'Sin etapa' : '${t[0].toUpperCase()}${t.substring(1)}';
}

/// Texto de una nota listo para editar: su contenido plano SIN los nombres de
/// los archivos pegados.
///
/// Los adjuntos viven dentro del contenido de la nota, así que su nombre
/// aparece también en el texto plano ("\u{1F4CE} contrato.pdf"). Si se dejara,
/// al guardar quedaría escrito dos veces: como texto y como archivo.
String textoEditableDeNota(String detalle, List<AdjuntoNota> adjuntos) {
  var texto = detalle;
  for (final a in adjuntos.where((a) => !a.esImagen)) {
    texto = texto.replaceAll('\u{1F4CE} ${a.nombre}', '');
  }
  return texto.replaceAll(RegExp(r'\s+'), ' ').trim();
}

// ── Validación de la ficha (espejo de la del servidor) ───────────────────────

final _reRfc = RegExp(r'^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$');
final _reCurp = RegExp(r'^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$');
final _reTelefono = RegExp(r'^\d{10}$');
final _reEmail = RegExp(r'^\S+@\S+\.\S+$');

/// Motivo por el que el correo no sirve, o null si está bien.
String? errorEmail(String valor) {
  if (valor.trim().isEmpty) return 'El correo es obligatorio';
  return _reEmail.hasMatch(valor.trim()) ? null : 'Correo con formato inválido';
}

String? errorTelefono(String valor) {
  if (valor.trim().isEmpty) return 'El teléfono es obligatorio';
  return _reTelefono.hasMatch(valor.trim()) ? null : 'Deben ser 10 dígitos';
}

String? errorRfc(String valor) {
  final v = valor.trim().toUpperCase();
  if (v.isEmpty) return null;
  return _reRfc.hasMatch(v) ? null : 'Formato inválido (12 a 13 caracteres)';
}

String? errorCurp(String valor) {
  final v = valor.trim().toUpperCase();
  if (v.isEmpty) return null;
  return _reCurp.hasMatch(v) ? null : 'Formato inválido (18 caracteres)';
}

// ── Códigos del servidor ─────────────────────────────────────────────────────

/// Mensajes por código de negocio. Cada uno dice qué pasó Y qué hacer: un
/// "error inesperado" deja al agente sin siguiente paso.
const Map<String, String> _mensajes = {
  'not_owner':
      'Este prospecto ya no es tuyo. Si lo transferiste, ahora lo atiende el '
      'otro agente.',
  'persona_no_encontrada': 'Ese prospecto ya no existe.',
  'datos_incompletos': 'Faltan nombre, correo o teléfono.',
  'email_invalido': 'El correo tiene un formato inválido.',
  'email_duplicado':
      'Ese correo ya está registrado con otra persona. Búscala antes de '
      'volver a darla de alta.',
  'rfc_invalido': 'El RFC tiene un formato inválido.',
  'rfc_duplicado': 'Ese RFC ya está registrado con otra persona.',
  'curp_invalido': 'La CURP tiene un formato inválido.',
  'curp_duplicado': 'Esa CURP ya está registrada con otra persona.',
  'telefono_invalido': 'El teléfono debe tener 10 dígitos, sin espacios.',
  'tipo_persona_invalido': 'Elige si es persona física o moral.',
  'proyectos_requeridos': 'Elige al menos un desarrollo de interés.',
  'proyecto_invalido': 'Uno de los desarrollos elegidos ya no está activo.',
  'proyecto_duplicado':
      'El prospecto ya tiene interés registrado en ese desarrollo.',
  'proyecto_no_permitido':
      'No vendes ese desarrollo, así que no puedes ligarlo a un prospecto.',
  'estatus_invalido': 'Ese estado ya no está en el catálogo.',
  'estatus_no_guardado':
      'No se pudo guardar el estado. Vuelve a intentarlo en un momento.',
  'destino_invalido': 'Ese agente ya no está activo. Elige otro.',
  'reasignacion_fallida':
      'No se pudo transferir el prospecto. Vuelve a intentarlo.',
  'notas_no_disponibles':
      'Las notas no están disponibles en este momento. Tu nota NO se guardó.',
  'contenido_requerido': 'Escribe algo o adjunta un archivo.',
  'adjunto_invalido': 'Ese archivo no se pudo leer. Elige otro.',
  'archivo_demasiado_grande': 'El archivo supera el límite de 10 MB.',
  'upload_failed': 'No se pudo subir el archivo. Vuelve a intentarlo.',
  'forbidden_role': 'Tu usuario no tiene acceso al portal de agentes.',
  'network_error': 'Sin conexión. Revisa tu red e intenta de nuevo.',
};

/// Mensaje para el agente a partir de un fallo del puerto.
String mensajeDeErrorProspecto(Object? error, {String? porDefecto}) {
  if (error is ApiError) {
    final m = _mensajes[error.code];
    if (m != null) return m;
  }
  return porDefecto ?? 'No se pudo completar la operación. Intenta de nuevo.';
}
