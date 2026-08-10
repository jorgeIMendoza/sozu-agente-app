import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/shared/adapters/edge_function.dart';

/// Implementación de [PerfilAgentePort] sobre la Edge Function `agente-perfil`.
///
/// Único archivo de la feature que nombra la tecnología: aquí viven los nombres
/// de las acciones, las claves del JSON y la traducción de los estados. Todo lo
/// demás (pantallas, providers, componentes) habla el lenguaje del puerto.
class PerfilAgenteAdapter implements PerfilAgentePort {
  /// `id_persona` del agente que un admin está viendo; null = su propia sesión.
  final int? impersonate;

  final EdgeFunctions _fn;

  PerfilAgenteAdapter({this.impersonate})
    : _fn = EdgeFunctions(impersonate: impersonate);

  static const _funcion = 'agente-perfil';

  @override
  Future<PerfilAgente> cargar() async =>
      PerfilAgente.desde(await _fn.call(_funcion));

  @override
  Future<CatalogosDeDomicilio> catalogosDeDomicilio({int? idEstado}) async {
    final res = await _fn.call(
      _funcion,
      body: {
        'action': 'catalogos',
        if (idEstado != null) 'id_estado': idEstado,
      },
    );
    List<OpcionDeCatalogo> leer(String clave, String? campoPadre) =>
        listaDe(res[clave])
            .map(
              (e) => OpcionDeCatalogo(
                valor: '${e['id'] ?? ''}',
                nombre: '${e['nombre'] ?? ''}',
                padre: campoPadre == null || e[campoPadre] == null
                    ? null
                    : '${e[campoPadre]}',
              ),
            )
            .toList();

    return CatalogosDeDomicilio(
      paises: leer('paises', null),
      estados: leer('estados', 'id_pais'),
      municipios: leer('municipios', 'id_estado'),
    );
  }

  @override
  Future<void> guardarIdentidad({
    required String nombreLegal,
    required String telefono,
    required String curp,
    DateTime? fechaNacimiento,
    String? sexo,
    Domicilio? domicilio,
  }) async {
    await _fn.call(
      _funcion,
      body: {
        'action': 'guardar_identidad',
        'nombre_legal': nombreLegal,
        'telefono': telefono,
        'curp': curp,
        'fecha_nacimiento': _soloFecha(fechaNacimiento),
        'sexo': sexo,
        // Se mandan SIEMPRE (aunque vengan nulos): el backend distingue
        // "ausente" de "null" y solo pisa la columna cuando la clave viaja.
        if (domicilio != null) ...{
          'direccion_calle': domicilio.calle,
          'direccion_num_ext': domicilio.numExt,
          'direccion_num_int': domicilio.numInt,
          'direccion_colonia': domicilio.colonia,
          'direccion_codigo_postal': domicilio.codigoPostal,
          'direccion_id_pais': domicilio.idPais,
          'direccion_id_estado': domicilio.idEstado,
          'direccion_id_municipio': domicilio.idMunicipio,
        },
      },
    );
  }

  @override
  Future<void> guardarUsoCfdi(String? codigo) async {
    await _fn.call(
      _funcion,
      body: {'action': 'guardar_uso_cfdi', 'uso_cfdi': codigo},
    );
  }

  @override
  Future<String?> guardarPresentacion(String? frase) async {
    final res = await _fn.call(
      _funcion,
      body: {'action': 'guardar_frase', 'frase_perfil': frase},
    );
    return res['frase_perfil'] as String?;
  }

  @override
  Future<String?> guardarFoto({
    required String base64,
    required String mime,
  }) async {
    final res = await _fn.call(
      _funcion,
      body: {'action': 'guardar_foto', 'base64': base64, 'mime': mime},
    );
    return res['foto_perfil_url'] as String?;
  }

  @override
  Future<void> borrarFoto() async {
    await _fn.call(_funcion, body: {'action': 'borrar_foto'});
  }

  @override
  Future<EstadoDocumento> subirDocumento({
    required int tipo,
    required String base64,
    required String nombre,
    String? contentType,
    bool validado = false,
    DatosDeConstancia? datos,
  }) async {
    final actualizaciones = _camposDeConstancia(datos);
    final res = await _fn.call(
      _funcion,
      body: {
        'action': 'subir_documento',
        'tipo': tipo,
        'base64': base64,
        'nombre': nombre,
        if (contentType != null) 'content_type': contentType,
        // 2 = validado, 1 = pendiente, la misma codificación del back office.
        'estatus': validado ? 2 : 1,
        if (actualizaciones.isNotEmpty) 'persona_updates': actualizaciones,
      },
    );
    return EstadoDocumento.desde(res['estatus']);
  }

  @override
  Future<int> guardarCuentaBancaria({
    int? id,
    required int idBanco,
    required String numeroCuenta,
    required String titular,
    String? clabe,
    String? evidenciaBase64,
    String? evidenciaNombre,
    String? evidenciaContentType,
  }) async {
    final res = await _fn.call(
      _funcion,
      body: {
        'action': 'guardar_cuenta_bancaria',
        if (id != null) 'id': id,
        'id_banco': idBanco,
        'numero_cuenta': numeroCuenta,
        'titular': titular,
        if (clabe != null && clabe.isNotEmpty) 'cuenta_clabe': clabe,
        if (evidenciaBase64 != null) 'evidencia_base64': evidenciaBase64,
        if (evidenciaNombre != null) 'evidencia_nombre': evidenciaNombre,
        if (evidenciaContentType != null)
          'evidencia_content_type': evidenciaContentType,
      },
    );
    return intDe(res['id']) ?? id ?? 0;
  }

  @override
  Future<void> borrarCuentaBancaria(int id) async {
    await _fn.call(
      _funcion,
      body: {'action': 'borrar_cuenta_bancaria', 'id': id},
    );
  }

  @override
  Future<FirmaDeCarta> iniciarFirmaDeCarta({String? firmaAutografa}) async {
    final res = await _fn.call(
      _funcion,
      body: {
        'action': 'firma_carta_crear',
        if (firmaAutografa != null) 'firma_autografa': firmaAutografa,
      },
    );
    return FirmaDeCarta(
      // El backend no devuelve estado al crear: si respondió, el documento
      // quedó abierto y esperando la firma del agente.
      estado: EstadoFirmaCarta.enviado,
      folio: res['document_id'] as String?,
      urlParaFirmar: _urlDeFirma(res['widget_id'] as String?),
    );
  }

  @override
  Future<FirmaDeCarta> consultarFirmaDeCarta() async {
    final res = await _fn.call(_funcion, body: {'action': 'firma_carta_estado'});
    return FirmaDeCarta(
      estado: EstadoFirmaCarta.desde(res['estado']),
      folio: res['mifiel_document_id'] as String?,
      urlParaFirmar: _urlDeFirma(res['widget_id'] as String?),
      pdfUrl: res['pdf_url'] as String?,
    );
  }

  // ── Traducciones ─────────────────────────────────────────────────────────

  /// `YYYY-MM-DD`: la columna es `date`, la hora sobra y desalinea zonas.
  static String? _soloFecha(DateTime? d) {
    if (d == null) return null;
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// Columnas de `personas` que el backend acepta al subir la Constancia. La
  /// whitelist es del servidor; aquí solo se mandan las que el agente confirmó
  /// (una extracción incompleta no debe borrar lo que ya había).
  static Map<String, dynamic> _camposDeConstancia(DatosDeConstancia? d) {
    if (d == null) return const {};
    final out = <String, dynamic>{};
    void poner(String clave, String? valor) {
      final v = valor?.trim();
      if (v != null && v.isNotEmpty) out[clave] = v;
    }

    poner('rfc', d.rfc);
    poner('nombre_legal', d.nombreLegal);
    poner('regimen', d.regimen);
    poner('direccion_fiscal_codigo_postal', d.codigoPostal);
    poner('direccion_fiscal_calle', d.calle);
    poner('direccion_fiscal_num_ext', d.numExt);
    poner('direccion_fiscal_num_int', d.numInt);
    poner('direccion_fiscal_colonia', d.colonia);
    return out;
  }

  /// Liga donde el agente firma su carta.
  ///
  /// El portal web NO navega a una URL: monta el web component
  /// `<mifiel-widget id="…" environment="…">` con el script
  /// `https://{host}/widget-component/index.js`
  /// (`app.mifiel.com` en producción, `app-sandbox.mifiel.com` fuera de ella; ver
  /// `sozu-admin/src/components/admin/MifielSigningDialog.tsx`). Un custom
  /// element no existe en Flutter, así que aquí se abre la página del proveedor
  /// que hospeda ese mismo widget y se refresca el estado al volver.
  ///
  /// ⚠️ La ruta `/widget/{id}` NO está documentada en el repo web: se deduce del
  /// host y del id del widget. Por eso la pantalla nunca depende solo de ella —
  /// siempre ofrece "Actualizar estado" y le recuerda al agente que el proveedor
  /// también le manda la carta por correo. Si el backend algún día devuelve la
  /// liga real, solo cambia esta función.
  static String? _urlDeFirma(String? idWidget) {
    if (idWidget == null || idWidget.isEmpty) return null;
    return 'https://$_hostDeFirma/widget/$idWidget';
  }

  /// El entorno lo decide el backend (compara contra `metadata.environment`), y
  /// el app no tiene forma de leerlo. Se usa el de producción porque es el único
  /// con el que corren los dispositivos publicados; en desarrollo la liga puede
  /// no abrir y ahí queda el camino del correo.
  static const _hostDeFirma = 'app.mifiel.com';
}
