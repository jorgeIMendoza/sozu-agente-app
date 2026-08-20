import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_selectores_de_domicilio.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/mensajes_del_perfil.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/validaciones_del_perfil.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Capturador de la información fiscal del agente: RFC, régimen, uso del CFDI y
/// domicilio fiscal. Es el paso que le habilita las comisiones.
///
/// Espejo de las pestañas Datos y Dirección del capturador de la web
/// (`AgentOnboardingStepDialog`), incluido el atajo de copiar el domicilio
/// particular. Solo lo abre el agente que administra sus datos: al dependiente se
/// los lleva su inmobiliaria y el backend responde `forbidden_field`.
///
/// Devuelve `true` si guardó.
Future<bool?> mostrarHojaDeFiscal(
  BuildContext context, {
  required DatosFiscales fiscal,
  required CatalogosDelPerfil catalogos,

  /// Domicilio particular del agente, para el atajo "es el mismo".
  required Domicilio domicilioParticular,
}) => mostrarHojaDePerfil<bool>(
  context,
  child: _HojaDeFiscal(
    fiscal: fiscal,
    catalogos: catalogos,
    domicilioParticular: domicilioParticular,
  ),
);

class _HojaDeFiscal extends ConsumerStatefulWidget {
  final DatosFiscales fiscal;
  final CatalogosDelPerfil catalogos;
  final Domicilio domicilioParticular;

  const _HojaDeFiscal({
    required this.fiscal,
    required this.catalogos,
    required this.domicilioParticular,
  });

  @override
  ConsumerState<_HojaDeFiscal> createState() => _HojaDeFiscalState();
}

class _HojaDeFiscalState extends ConsumerState<_HojaDeFiscal> {
  final _rfc = TextEditingController();
  final _calle = TextEditingController();
  final _numExt = TextEditingController();
  final _numInt = TextEditingController();
  final _colonia = TextEditingController();
  final _codigoPostal = TextEditingController();

  String? _regimen;
  String? _usoCfdi;
  String? _idPais;
  int? _idEstado;
  int? _idMunicipio;

  /// El domicilio fiscal es el particular: los campos se muestran llenos y en
  /// solo lectura, como el "el titular soy yo" de la cuenta bancaria.
  bool _copiarParticular = false;

  bool _guardando = false;
  String? _error;

  /// Error por campo, con el código del backend ya traducido: un
  /// "rfc_duplicado" en un aviso flotante no dice cuál de los diez campos
  /// corregir.
  final _erroresPorCampo = <String, String>{};

  @override
  void initState() {
    super.initState();
    final f = widget.fiscal;
    _rfc.text = f.rfc ?? '';
    _regimen = f.regimen;
    _usoCfdi = f.usoCfdi;
    _escribirDomicilio(f.domicilio);
  }

  @override
  void dispose() {
    for (final c in [_rfc, _calle, _numExt, _numInt, _colonia, _codigoPostal]) {
      c.dispose();
    }
    super.dispose();
  }

  void _escribirDomicilio(Domicilio d) {
    _calle.text = d.calle ?? '';
    _numExt.text = d.numExt ?? '';
    _numInt.text = d.numInt ?? '';
    _colonia.text = d.colonia ?? '';
    _codigoPostal.text = d.codigoPostal ?? '';
    _idPais = d.idPais;
    _idEstado = d.idEstado;
    _idMunicipio = d.idMunicipio;
  }

  /// Faltantes en el idioma del agente, antes de gastar el viaje al backend. Son
  /// los mismos obligatorios que exige `guardar_fiscal`: todo menos el interior.
  List<String> get _faltantes => [
    if (!rfcValido(_rfc.text))
      'RFC (12 o 13 caracteres con el formato oficial)',
    if ((_regimen ?? '').isEmpty) 'Régimen fiscal',
    if ((_usoCfdi ?? '').isEmpty) 'Uso del CFDI',
    if (_calle.text.trim().isEmpty) 'Calle',
    if (_numExt.text.trim().isEmpty) 'Número exterior',
    if (_colonia.text.trim().isEmpty) 'Colonia',
    if (_codigoPostal.text.trim().length != 5) 'Código postal (5 dígitos)',
    if ((_idPais ?? '').isEmpty) 'País',
    if (_idEstado == null) 'Estado',
    if (_idMunicipio == null) 'Municipio',
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
          .guardarFiscal(
            rfc: _rfc.text.trim().toUpperCase(),
            regimen: _regimen!,
            usoCfdi: _usoCfdi!,
            domicilio: Domicilio(
              calle: _calle.text.trim(),
              numExt: _numExt.text.trim(),
              numInt: _numInt.text.trim().isEmpty ? null : _numInt.text.trim(),
              colonia: _colonia.text.trim(),
              codigoPostal: _codigoPostal.text.trim(),
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
        setState(() => _error = 'No se pudo guardar tu información fiscal.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final editable = !_guardando && !_copiarParticular;

    return HojaDePerfil(
      titulo: 'Editar información fiscal',
      subtitulo:
          'Con estos datos facturas tus comisiones a SOZU, así que tienen que '
          'coincidir con el SAT (CFDI 4.0).',
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
          STextField(
            controller: _rfc,
            label: 'RFC',
            hint: 'PEGJ850101H2A',
            size: STextFieldSize.md,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(13),
              const MayusculasAlEscribir(),
            ],
            helper: '13 caracteres si eres persona física, 12 si eres moral.',
            errorText: _erroresPorCampo['rfc'],
          ),
          SizedBox(height: t.space.md),
          SSelectField<String>(
            label: 'Régimen fiscal',
            requerido: true,
            hint: 'Selecciona tu régimen',
            value: _regimen,
            opciones: [
              for (final r in widget.catalogos.regimenes)
                (value: r.valor, label: r.etiqueta),
            ],
            onChanged: _guardando ? null : (v) => setState(() => _regimen = v),
            errorText: _erroresPorCampo['regimen'],
          ),
          SizedBox(height: t.space.md),
          SSelectField<String>(
            label: 'Uso del CFDI',
            requerido: true,
            hint: 'Selecciona el uso',
            value: _usoCfdi,
            opciones: [
              for (final u in widget.catalogos.usosCfdi)
                (value: u.valor, label: u.etiqueta),
            ],
            onChanged: _guardando ? null : (v) => setState(() => _usoCfdi = v),
          ),
          SizedBox(height: t.space.lg),
          const SSectionLabel(text: 'Domicilio fiscal'),
          SizedBox(height: t.space.xs),
          Text(
            'Es el que aparece en tu Constancia. La activación lo pide completo, '
            'incluidos país, estado y municipio.',
            style: t.text.overline.copyWith(
              color: t.color.fgSubtle,
              height: 1.5,
            ),
          ),
          SizedBox(height: t.space.sm),
          Row(
            children: [
              Checkbox(
                value: _copiarParticular,
                onChanged: _guardando
                    ? null
                    : (v) => setState(() {
                        _copiarParticular = v ?? false;
                        if (_copiarParticular) {
                          _escribirDomicilio(widget.domicilioParticular);
                        }
                      }),
              ),
              Expanded(
                child: Text(
                  'Copiar mi domicilio particular',
                  style: t.text.caption.copyWith(color: t.color.fgMuted),
                ),
              ),
            ],
          ),
          SizedBox(height: t.space.xs),
          STextField(
            controller: _calle,
            label: 'Calle',
            hint: 'Av. Insurgentes Sur',
            size: STextFieldSize.md,
            enabled: editable,
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
                  enabled: editable,
                ),
              ),
              SizedBox(width: t.space.sm),
              Expanded(
                child: STextField(
                  controller: _numInt,
                  label: 'Núm. interior',
                  hint: '4B',
                  size: STextFieldSize.md,
                  enabled: editable,
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
            enabled: editable,
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: t.space.md),
          STextField(
            controller: _codigoPostal,
            label: 'Código postal',
            hint: '03100',
            size: STextFieldSize.md,
            enabled: editable,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
          ),
          SizedBox(height: t.space.md),
          PerfilSelectoresDeDomicilio(
            valor: (
              idPais: _idPais,
              idEstado: _idEstado,
              idMunicipio: _idMunicipio,
            ),
            habilitado: editable,
            onCambio: (v) => setState(() {
              _idPais = v.idPais;
              _idEstado = v.idEstado;
              _idMunicipio = v.idMunicipio;
            }),
          ),
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
