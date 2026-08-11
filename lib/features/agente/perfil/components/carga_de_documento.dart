import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/archivos_del_perfil.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/mensajes_del_perfil.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Entrega un documento del expediente: elegir tipo, adjuntar, revisar y guardar.
///
/// Devuelve el mensaje de resultado para que la pantalla lo anuncie, o null si el
/// agente canceló.
///
/// Reusa `showSDocUpload` del design system, que ya resuelve la hoja partida
/// (formulario a la izquierda, vista previa a la derecha), el `Esc` de escritorio
/// y la confirmación de condiciones antes de guardar.
Future<String?> cargarDocumentoDelExpediente(
  BuildContext context,
  WidgetRef ref, {
  required DocumentoDelExpediente documento,

  /// Catálogo de regímenes, para que el agente elija el suyo al confirmar la
  /// Constancia en vez de escribir una clave a mano.
  List<OpcionDeCatalogo> regimenes = const [],
}) async {
  final esConstancia = documento.tipos.contains(
    TiposDocumento.constanciaFiscal,
  );
  final esIdentificacion = documento.clave == 'identidad';

  final resultado = await showSDocUpload(
    context,
    titulo: esIdentificacion ? 'Identificación oficial' : documento.nombre,
    descripcion: esIdentificacion
        ? 'Elige con qué te identificas, adjunta el archivo y revísalo antes '
              'de guardar'
        : 'Adjunta el archivo y revísalo antes de guardar',
    // La identidad admite dos formas del MISMO requisito y solo una queda
    // vigente: subir las dos deja dos identificaciones y verificación no sabe
    // cuál manda.
    tipos: esIdentificacion
        ? const [
            (
              value: TiposDocumento.ineCompleto,
              label: 'INE (frente y reverso en un solo archivo)',
            ),
            (value: TiposDocumento.pasaporte, label: 'Pasaporte (página de datos)'),
          ]
        : const [],
    tipoId: esIdentificacion
        ? (documento.identificacion ?? TipoIdentificacion.ine).tipoDocumento
        : documento.tipos.firstOrNull,
    onSeleccionar: elegirDocumento,
    // Aquí solo se puede juzgar el contenido: la extensión ya la filtró el
    // selector del sistema.
    validar: (bytes) {
      if (bytes.isEmpty) return 'El archivo está vacío. Elige otro.';
      if (bytes.length > kMaxBytesArchivo) {
        return 'El archivo pesa más de 10 MB. Vuelve a exportarlo más ligero.';
      }
      return null;
    },
    // Las imágenes no las puede rasterizar el visor de PDF.
    preview: (bytes, nombre) => esPdf(bytes)
        ? SPdfPreview(bytes: bytes, nombre: nombre)
        : _VistaPreviaImagen(bytes: bytes),
    onAnalizar: esConstancia
        ? (tipo, nombre, bytes) async => _camposDeLaConstancia(regimenes)
        : null,
    condiciones: (_) => _condiciones(documento),
    etiquetaGuardar: 'Guardar',
  );
  if (resultado == null) return null;

  try {
    final estado = await ref.read(perfilAgentePortProvider).subirDocumento(
      tipo: resultado.tipoId,
      base64: base64Encode(resultado.bytes),
      nombre: resultado.nombre,
      contentType: contentTypeDe(resultado.nombre),
      // NUNCA se pide "validado" desde el app. El portal web lo hace solo cuando
      // pudo leer el PDF original del SAT (sello + frases + fecha ≤ 3 meses) con
      // pdf.js; aquí no hay forma equivalente de comprobarlo, y marcar validado
      // sin comprobar dejaría datos fiscales sin respaldo en las facturas.
      validado: false,
      datos: esConstancia ? _datosDesde(resultado.campos) : null,
    );
    ref.invalidate(perfilAgenteProvider);
    return estado == EstadoDocumento.validado
        ? 'Documento validado.'
        : 'Documento enviado. Queda pendiente de validación.';
  } on ApiError catch (e) {
    return mensajeDeError(e);
  } catch (_) {
    return 'No se pudo subir el documento. Intenta de nuevo.';
  }
}

/// Condiciones que el agente acepta antes de guardar. Van en el diálogo y no
/// junto a la zona de carga: ahí se leen de pasada, aquí hay que aceptarlas, y
/// así queda claro que un rechazo lo resuelve él volviendo a cargar.
List<String> _condiciones(DocumentoDelExpediente documento) {
  if (documento.tipos.contains(TiposDocumento.constanciaFiscal)) {
    return const [
      'Es el PDF original que descargas del portal del SAT.',
      'Tiene menos de 3 meses de emitido.',
      'Se ve completo y legible.',
    ];
  }
  return const [
    'El documento está completo y legible.',
    'Está vigente.',
    'Si no cumple estas condiciones, la revisión se rechaza y tendrás que '
        'cargarlo de nuevo.',
  ];
}

/// Datos fiscales que el agente confirma al entregar su Constancia.
///
/// Salen vacíos: el app NO lee el PDF. En el portal web pdf.js extrae el texto y
/// los precarga, y aquí no hay equivalente que valga la pena mantener, así que se
/// le piden y se le advierte para qué son. Los que bloquean son los mismos del
/// back office (RFC, régimen, calle, colonia y CP); los números exterior e
/// interior no.
SDocAnalisis _camposDeLaConstancia(List<OpcionDeCatalogo> regimenes) => (
  campos: [
    const SDocFieldSpec(
      key: 'rfc',
      label: 'RFC',
      requerido: true,
      kind: SDocFieldKind.rfc,
    ),
    const SDocFieldSpec(
      key: 'nombre',
      label: 'Nombre / Razón social',
      requerido: true,
    ),
    SDocFieldSpec(
      key: 'regimen',
      label: 'Régimen fiscal',
      requerido: true,
      kind: SDocFieldKind.catalogo,
      opciones: [
        for (final r in regimenes) (id: r.valor, nombre: r.etiqueta),
      ],
    ),
    const SDocFieldSpec(
      key: 'codigo_postal',
      label: 'Código postal',
      requerido: true,
      kind: SDocFieldKind.cp,
    ),
    const SDocFieldSpec(key: 'calle', label: 'Calle', requerido: true),
    const SDocFieldSpec(key: 'num_ext', label: 'Núm. exterior'),
    const SDocFieldSpec(key: 'num_int', label: 'Núm. interior'),
    const SDocFieldSpec(key: 'colonia', label: 'Colonia', requerido: true),
  ],
  aviso:
      'Captura los datos tal como aparecen en tu Constancia: con ellos '
      'facturas tus comisiones a SOZU, así que tienen que coincidir con el '
      'SAT. El documento queda pendiente de validación manual.',
  tono: SDocTone.warning,
  rechazo: null,
);

DatosDeConstancia _datosDesde(Map<String, String> campos) {
  String? v(String clave) {
    final s = campos[clave]?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  return DatosDeConstancia(
    rfc: v('rfc')?.toUpperCase(),
    nombreLegal: v('nombre'),
    regimen: v('regimen'),
    codigoPostal: v('codigo_postal'),
    calle: v('calle'),
    numExt: v('num_ext'),
    numInt: v('num_int'),
    colonia: v('colonia'),
  );
}

/// Vista previa de una carátula o identificación que viene como imagen.
class _VistaPreviaImagen extends StatelessWidget {
  final Uint8List bytes;

  const _VistaPreviaImagen({required this.bytes});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.s.color.surfaceAlt,
    child: Center(
      child: InteractiveViewer(
        maxScale: 4,
        child: Image.memory(bytes, fit: BoxFit.contain),
      ),
    ),
  );
}
