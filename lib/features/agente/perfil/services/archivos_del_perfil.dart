import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Selección y validación de los archivos que el agente sube desde su perfil:
/// documentos del expediente, carátulas bancarias y foto de perfil.
///
/// La validación se hace ANTES de mandar el archivo. No sustituye a la del
/// backend (que la repite): evita el viaje y le responde al agente al instante.

/// Tope de tamaño del backend. Pasarse devuelve `413`.
const int kMaxBytesArchivo = 10 * 1024 * 1024;

/// Extensiones que acepta el backend para documentos y carátulas.
const _extensionesDocumento = {'pdf', 'jpg', 'jpeg', 'png', 'webp'};

/// Imágenes que acepta el backend para la foto de perfil (por su MIME).
const _mimesDeFoto = <String, String>{
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
};

/// Un archivo elegido por el agente.
typedef ArchivoElegido = ({String nombre, Uint8List bytes});

/// Extensión en minúsculas, sin punto; vacío si el nombre no la trae.
String extensionDe(String nombre) {
  final i = nombre.lastIndexOf('.');
  if (i < 0 || i == nombre.length - 1) return '';
  return nombre.substring(i + 1).toLowerCase();
}

/// `Content-Type` que corresponde al archivo, para que Storage lo sirva bien.
String contentTypeDe(String nombre) => switch (extensionDe(nombre)) {
  'pdf' => 'application/pdf',
  'png' => 'image/png',
  'webp' => 'image/webp',
  _ => 'image/jpeg',
};

/// MIME de una foto de perfil, o null si la extensión no se acepta.
String? mimeDeFoto(String nombre) => _mimesDeFoto[extensionDe(nombre)];

/// Firma de un PDF: los bytes `%PDF-` al inicio del archivo.
const List<int> _firmaPdf = [0x25, 0x50, 0x44, 0x46, 0x2d];

/// true si los bytes son realmente un PDF.
///
/// Se mira el CONTENIDO y no la extensión: un `.jpg` renombrado a `.pdf` pasa
/// cualquier filtro por nombre. Sirve para decidir cómo previsualizarlo.
bool esPdf(Uint8List bytes) {
  if (bytes.length <= _firmaPdf.length) return false;
  for (var i = 0; i < _firmaPdf.length; i++) {
    if (bytes[i] != _firmaPdf[i]) return false;
  }
  return true;
}

/// Por qué no se puede mandar el archivo, o null si está bien. El texto se le
/// muestra al agente tal cual.
String? motivoArchivoInvalido(String nombre, Uint8List bytes) {
  if (bytes.isEmpty) return 'El archivo está vacío. Elige otro.';
  if (bytes.length > kMaxBytesArchivo) {
    return 'El archivo pesa más de 10 MB. Vuelve a exportarlo más ligero.';
  }
  if (!_extensionesDocumento.contains(extensionDe(nombre))) {
    return 'Solo se aceptan archivos PDF, JPG, PNG o WebP.';
  }
  return null;
}

/// Mismo criterio que [motivoArchivoInvalido] pero para la foto de perfil, que
/// no admite PDF.
String? motivoFotoInvalida(String nombre, Uint8List bytes) {
  if (bytes.isEmpty) return 'La imagen está vacía. Elige otra.';
  if (bytes.length > kMaxBytesArchivo) {
    return 'La imagen pesa más de 10 MB. Elige una más ligera.';
  }
  if (mimeDeFoto(nombre) == null) {
    return 'Solo se aceptan imágenes JPG, PNG o WebP.';
  }
  return null;
}

/// Abre el selector del sistema para un documento del expediente o una
/// carátula. Devuelve null si el agente canceló.
Future<ArchivoElegido?> elegirDocumento() async {
  const grupo = XTypeGroup(
    label: 'Documento',
    extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: [
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
    ],
  );
  final archivo = await openFile(acceptedTypeGroups: const [grupo]);
  if (archivo == null) return null;
  return (nombre: archivo.name, bytes: await archivo.readAsBytes());
}

/// Abre el selector del sistema para la foto de perfil.
Future<ArchivoElegido?> elegirFoto() async {
  const grupo = XTypeGroup(
    label: 'Imagen',
    extensions: ['jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
  );
  final archivo = await openFile(acceptedTypeGroups: const [grupo]);
  if (archivo == null) return null;
  return (nombre: archivo.name, bytes: await archivo.readAsBytes());
}
