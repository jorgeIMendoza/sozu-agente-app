import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/mensajes_del_perfil.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/validaciones_del_perfil.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Formulario de identidad del agente: datos personales y domicilio particular.
///
/// País, estado y municipio SÍ van aquí aunque el portal web no los tenga en su
/// modal: la activación los exige para dar el paso "Identidad" por completo, y en
/// el app no hay otro capturador que los escriba. Sin ellos el agente se queda
/// atorado en 75 % sin saber por qué.
///
/// Devuelve `true` si guardó.
Future<bool?> mostrarHojaDeIdentidad(
  BuildContext context, {
  required Identidad identidad,
}) => mostrarHojaDePerfil<bool>(
  context,
  child: _HojaDeIdentidad(identidad: identidad),
);

class _HojaDeIdentidad extends ConsumerStatefulWidget {
  final Identidad identidad;

  const _HojaDeIdentidad({required this.identidad});

  @override
  ConsumerState<_HojaDeIdentidad> createState() => _HojaDeIdentidadState();
}

class _HojaDeIdentidadState extends ConsumerState<_HojaDeIdentidad> {
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _curp = TextEditingController();
  final _calle = TextEditingController();
  final _numExt = TextEditingController();
  final _numInt = TextEditingController();
  final _colonia = TextEditingController();
  final _codigoPostal = TextEditingController();

  DateTime? _fechaNacimiento;
  String? _sexo;
  String? _idPais;
  int? _idEstado;
  int? _idMunicipio;

  bool _guardando = false;
  String? _error;

  /// Error por campo, con el código que mandó el backend ya traducido. Va junto
  /// al campo y no en un aviso flotante: un "curp_invalido" en un toast no le
  /// dice al agente cuál de los ocho campos tiene que corregir.
  final _erroresPorCampo = <String, String>{};

  @override
  void initState() {
    super.initState();
    final i = widget.identidad;
    _nombre.text = i.nombreLegal ?? '';
    _telefono.text = i.telefono ?? '';
    _curp.text = i.curp ?? '';
    _calle.text = i.domicilio.calle ?? '';
    _numExt.text = i.domicilio.numExt ?? '';
    _numInt.text = i.domicilio.numInt ?? '';
    _colonia.text = i.domicilio.colonia ?? '';
    _codigoPostal.text = i.domicilio.codigoPostal ?? '';
    _fechaNacimiento = i.fechaNacimiento;
    _sexo = i.sexo;
    _idPais = i.domicilio.idPais;
    _idEstado = i.domicilio.idEstado;
    _idMunicipio = i.domicilio.idMunicipio;
  }

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _telefono,
      _curp,
      _calle,
      _numExt,
      _numInt,
      _colonia,
      _codigoPostal,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate:
          _fechaNacimiento ?? DateTime(hoy.year - 30, hoy.month, hoy.day),
      firstDate: DateTime(1920),
      lastDate: hoy,
      helpText: 'Tu fecha de nacimiento',
    );
    if (elegida != null) setState(() => _fechaNacimiento = elegida);
  }

  /// Faltantes en el idioma del agente, antes de gastar el viaje al backend.
  List<String> get _faltantes => [
    if (_nombre.text.trim().isEmpty) 'Nombre completo',
    if (_telefono.text.trim().length != 10) 'Teléfono (10 dígitos)',
    if (!curpValido(_curp.text)) 'CURP (18 caracteres con el formato oficial)',
  ];

  Future<void> _guardar() async {
    final faltantes = _faltantes;
    if (faltantes.isNotEmpty) {
      setState(
        () => _error = 'Faltan campos obligatorios: ${faltantes.join(', ')}.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
      _erroresPorCampo.clear();
    });
    try {
      await ref
          .read(perfilAgentePortProvider)
          .guardarIdentidad(
            nombreLegal: _nombre.text.trim(),
            telefono: _telefono.text.trim(),
            curp: _curp.text.trim().toUpperCase(),
            fechaNacimiento: _fechaNacimiento,
            sexo: _sexo,
            domicilio: Domicilio(
              calle: _vacioANulo(_calle.text),
              numExt: _vacioANulo(_numExt.text),
              numInt: _vacioANulo(_numInt.text),
              colonia: _vacioANulo(_colonia.text),
              codigoPostal: _vacioANulo(_codigoPostal.text),
              idPais: _idPais,
              idEstado: _idEstado,
              idMunicipio: _idMunicipio,
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (!mounted) return;
      final campo = campoDelError(e.code);
      setState(() {
        if (campo != null) {
          _erroresPorCampo[campo] = mensajeDeError(e);
        } else {
          _error = mensajeDeError(e);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar la información.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  static String? _vacioANulo(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // Los municipios llegan solo del estado elegido: el catálogo completo son
    // miles de filas y no cabe en una respuesta de arranque.
    final catalogos = ref.watch(catalogosDeDomicilioProvider(_idEstado));
    final datos = catalogos.valueOrNull;

    final estadosDelPais = (datos?.estados ?? const <OpcionDeCatalogo>[])
        .where((e) => _idPais == null || e.padre == null || e.padre == _idPais)
        .toList();

    return HojaDePerfil(
      titulo: 'Editar información',
      subtitulo: 'Tus datos personales y tu domicilio particular.',
      acciones: [
        SButton(
          label: 'Cancelar',
          onPressed: _guardando ? null : () => Navigator.of(context).maybePop(),
          variant: SButtonVariant.secondary,
          size: SButtonSize.md,
          fullWidth: false,
        ),
        SButton(
          label: 'Guardar',
          onPressed: _guardar,
          loading: _guardando,
          loadingLabel: 'Guardando…',
          size: SButtonSize.md,
          fullWidth: false,
        ),
      ],
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El correo es la llave de la cuenta: se muestra para que el agente
          // confirme cuál es, pero no se toca desde aquí.
          STextField(
            controller: TextEditingController(
              text: widget.identidad.email ?? '',
            ),
            label: 'Correo · solo lectura',
            readOnly: true,
            enabled: false,
            size: STextFieldSize.md,
          ),
          SizedBox(height: t.space.md),
          STextField(
            controller: _nombre,
            label: 'Nombre completo',
            hint: 'Juan Pérez García',
            size: STextFieldSize.md,
            textCapitalization: TextCapitalization.words,
            errorText: _erroresPorCampo['nombre'],
          ),
          SizedBox(height: t.space.md),
          STextField(
            controller: _telefono,
            label: 'Teléfono',
            hint: '5512345678',
            size: STextFieldSize.md,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            errorText: _erroresPorCampo['telefono'],
          ),
          SizedBox(height: t.space.md),
          STextField(
            controller: _curp,
            label: 'CURP',
            hint: 'GARC850101HDFRRL09',
            size: STextFieldSize.md,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(18),
              _EnMayusculas(),
            ],
            helper: '18 caracteres, como aparece en tu constancia de CURP.',
            errorText: _erroresPorCampo['curp'],
          ),
          SizedBox(height: t.space.md),
          _Fecha(
            valor: _fechaNacimiento,
            onElegir: _guardando ? null : _elegirFecha,
          ),
          SizedBox(height: t.space.md),
          SSelectField<String>(
            label: 'Sexo',
            hint: 'Sin especificar',
            value: _sexo,
            opciones: const [
              (value: 'M', label: 'Hombre'),
              (value: 'F', label: 'Mujer'),
              (value: 'O', label: 'Otro'),
            ],
            onChanged: _guardando ? null : (v) => setState(() => _sexo = v),
          ),
          SizedBox(height: t.space.lg),
          const SSectionLabel(text: 'Domicilio particular'),
          SizedBox(height: t.space.xs),
          Text(
            'Tu activación pide el domicilio completo, incluidos país, estado y '
            'municipio.',
            style: t.text.overline.copyWith(
              color: t.color.fgSubtle,
              height: 1.5,
            ),
          ),
          SizedBox(height: t.space.sm),
          STextField(
            controller: _calle,
            label: 'Calle',
            hint: 'Av. Insurgentes Sur',
            size: STextFieldSize.md,
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: t.space.md),
          Row(
            children: [
              Expanded(
                child: STextField(
                  controller: _numExt,
                  label: 'Núm. exterior',
                  hint: '1234',
                  size: STextFieldSize.md,
                ),
              ),
              SizedBox(width: t.space.sm),
              Expanded(
                child: STextField(
                  controller: _numInt,
                  label: 'Núm. interior',
                  hint: '4B',
                  size: STextFieldSize.md,
                ),
              ),
            ],
          ),
          SizedBox(height: t.space.md),
          STextField(
            controller: _colonia,
            label: 'Colonia',
            hint: 'Del Valle',
            size: STextFieldSize.md,
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: t.space.md),
          STextField(
            controller: _codigoPostal,
            label: 'Código postal',
            hint: '03100',
            size: STextFieldSize.md,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
          ),
          SizedBox(height: t.space.md),
          if (catalogos.hasError)
            Text(
              'No pudimos cargar los catálogos de país, estado y municipio. '
              'Guarda lo demás y vuelve a intentarlo.',
              style: t.text.caption.copyWith(color: t.color.warningFg),
            )
          else ...[
            SSelectField<String>(
              label: 'País',
              hint: datos == null ? 'Cargando…' : 'Selecciona tu país',
              value: _idPais,
              opciones: [
                for (final p in datos?.paises ?? const <OpcionDeCatalogo>[])
                  (value: p.valor, label: p.nombre),
              ],
              onChanged: _guardando || datos == null
                  ? null
                  : (v) => setState(() {
                      _idPais = v;
                      // Cambiar de país invalida estado y municipio: dejarlos
                      // guardaría un municipio de otro país.
                      _idEstado = null;
                      _idMunicipio = null;
                    }),
            ),
            SizedBox(height: t.space.md),
            SSelectField<int>(
              label: 'Estado',
              hint: datos == null ? 'Cargando…' : 'Selecciona tu estado',
              value: _idEstado,
              opciones: [
                for (final e in estadosDelPais)
                  (value: int.tryParse(e.valor) ?? 0, label: e.nombre),
              ],
              onChanged: _guardando || datos == null
                  ? null
                  : (v) => setState(() {
                      _idEstado = v;
                      _idMunicipio = null;
                    }),
            ),
            SizedBox(height: t.space.md),
            SSelectField<int>(
              label: 'Municipio',
              hint: _idEstado == null
                  ? 'Elige primero tu estado'
                  : datos == null
                  ? 'Cargando…'
                  : 'Selecciona tu municipio',
              value: _idMunicipio,
              opciones: [
                for (final m in datos?.municipios ?? const <OpcionDeCatalogo>[])
                  (value: int.tryParse(m.valor) ?? 0, label: m.nombre),
              ],
              onChanged: _guardando || _idEstado == null || datos == null
                  ? null
                  : (v) => setState(() => _idMunicipio = v),
            ),
          ],
          if (_error != null) ...[
            SizedBox(height: t.space.md),
            Text(
              _error!,
              style: t.text.caption.copyWith(color: t.color.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fecha de nacimiento: se elige con el calendario del sistema. No es un
/// `STextField` con máscara porque una fecha escrita a mano en teléfono es la
/// principal fuente de datos basura.
class _Fecha extends StatelessWidget {
  final DateTime? valor;
  final VoidCallback? onElegir;

  const _Fecha({required this.valor, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final texto = valor == null
        ? 'Sin especificar'
        : '${valor!.day.toString().padLeft(2, '0')}/'
              '${valor!.month.toString().padLeft(2, '0')}/${valor!.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SFieldLabel('Fecha de nacimiento'),
        SizedBox(height: t.space.xxs),
        SPressable(
          onTap: onElegir,
          borderRadius: t.radius.mdBorder,
          semanticLabel: 'Elegir tu fecha de nacimiento',
          child: Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: t.space.sm),
            decoration: BoxDecoration(
              border: Border.all(color: tone.border),
              borderRadius: t.radius.mdBorder,
              color: tone.surface,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                  color: tone.fgMuted,
                ),
                SizedBox(width: t.space.xs),
                Expanded(
                  child: Text(
                    texto,
                    style: t.text.body.copyWith(
                      color: valor == null ? tone.fgSubtle : tone.fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// La CURP se guarda en mayúsculas: se fuerza al escribir para que el agente vea
/// exactamente lo que se va a mandar.
class _EnMayusculas extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) => TextEditingValue(
    text: nuevo.text.toUpperCase(),
    selection: nuevo.selection,
    composing: TextRange.empty,
  );
}
