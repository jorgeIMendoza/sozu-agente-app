import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/archivos_del_perfil.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/mensajes_del_perfil.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Alta o corrección de la cuenta a la que SOZU le dispersa las comisiones.
///
/// El agente no puede darla de baja desde aquí cuando ya está validada: eso lo
/// hace SOZU, porque es la cuenta que recibe el dinero (ver
/// `borrarCuentaBancaria`, que responde `cuenta_validada`).
///
/// Devuelve `true` si guardó.
Future<bool?> mostrarHojaDeCuentaBancaria(
  BuildContext context, {
  required List<OpcionDeCatalogo> bancos,

  /// Cuenta a corregir; null da de alta una nueva.
  CuentaDeDispersion? cuenta,

  /// Nombre legal del agente, para el atajo "el titular soy yo".
  String? nombreDelAgente,
}) => mostrarHojaDePerfil<bool>(
  context,
  child: _HojaDeCuentaBancaria(
    bancos: bancos,
    cuenta: cuenta,
    nombreDelAgente: nombreDelAgente,
  ),
);

class _HojaDeCuentaBancaria extends ConsumerStatefulWidget {
  final List<OpcionDeCatalogo> bancos;
  final CuentaDeDispersion? cuenta;
  final String? nombreDelAgente;

  const _HojaDeCuentaBancaria({
    required this.bancos,
    this.cuenta,
    this.nombreDelAgente,
  });

  @override
  ConsumerState<_HojaDeCuentaBancaria> createState() =>
      _HojaDeCuentaBancariaState();
}

class _HojaDeCuentaBancariaState extends ConsumerState<_HojaDeCuentaBancaria> {
  final _numeroCuenta = TextEditingController();
  final _clabe = TextEditingController();
  final _titular = TextEditingController();

  int? _idBanco;
  bool _titularSoyYo = false;
  Uint8List? _evidenciaBytes;
  String? _evidenciaNombre;

  bool _guardando = false;
  String? _error;
  final _erroresPorCampo = <String, String>{};

  bool get _esAlta => widget.cuenta == null;

  @override
  void initState() {
    super.initState();
    final c = widget.cuenta;
    if (c != null) {
      _idBanco = c.idBanco;
      _titular.text = c.titular ?? '';
      // El número de cuenta y la CLABE NO viajan completos en la lectura (solo
      // los últimos 4): corregir la cuenta obliga a capturarlos de nuevo, y así
      // se dice en el formulario en vez de dejar campos misteriosamente vacíos.
    }
  }

  @override
  void dispose() {
    _numeroCuenta.dispose();
    _clabe.dispose();
    _titular.dispose();
    super.dispose();
  }

  Future<void> _elegirEvidencia() async {
    final archivo = await elegirDocumento();
    if (archivo == null || !mounted) return;
    final motivo = motivoArchivoInvalido(archivo.nombre, archivo.bytes);
    if (motivo != null) {
      setState(() => _erroresPorCampo['evidencia'] = motivo);
      return;
    }
    setState(() {
      _evidenciaBytes = archivo.bytes;
      _evidenciaNombre = archivo.nombre;
      _erroresPorCampo.remove('evidencia');
    });
  }

  /// Validaciones locales, en el mismo orden que las del backend, para que el
  /// agente no gaste un viaje por un dígito.
  String? _validacionLocal() {
    if (_idBanco == null || _numeroCuenta.text.trim().isEmpty) {
      return 'Elige tu banco y captura el número de cuenta.';
    }
    if (_titular.text.trim().isEmpty) {
      return 'Escribe el nombre del titular de la cuenta.';
    }
    final numero = _numeroCuenta.text.trim();
    if (numero.length < 8 || numero.length > 34) {
      return 'El número de cuenta debe tener entre 8 y 34 dígitos.';
    }
    final clabe = _clabe.text.trim();
    if (clabe.isNotEmpty && clabe.length != 18) {
      return 'La CLABE debe tener exactamente 18 dígitos.';
    }
    if (clabe.isNotEmpty && clabe == numero) {
      return 'La CLABE y el número de cuenta no pueden ser iguales.';
    }
    // En el alta la carátula es obligatoria; al corregir se conserva la que ya
    // estaba si no se adjunta otra.
    if (_esAlta && _evidenciaBytes == null) {
      return 'Adjunta la carátula de tu estado de cuenta: sin ella no podemos '
          'validarla.';
    }
    return null;
  }

  Future<void> _guardar() async {
    final motivo = _validacionLocal();
    if (motivo != null) {
      setState(() => _error = motivo);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
      _erroresPorCampo.clear();
    });
    try {
      final bytes = _evidenciaBytes;
      await ref.read(perfilAgentePortProvider).guardarCuentaBancaria(
        id: widget.cuenta?.id,
        idBanco: _idBanco!,
        numeroCuenta: _numeroCuenta.text.trim(),
        titular: _titular.text.trim(),
        clabe: _clabe.text.trim(),
        evidenciaBase64: bytes == null ? null : base64Encode(bytes),
        evidenciaNombre: _evidenciaNombre,
        evidenciaContentType: _evidenciaNombre == null
            ? null
            : contentTypeDe(_evidenciaNombre!),
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
        setState(() => _error = 'No se pudo guardar la cuenta. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final validada = widget.cuenta?.validada ?? false;

    return HojaDePerfil(
      titulo: _esAlta ? 'Nueva cuenta bancaria' : 'Editar cuenta bancaria',
      subtitulo: _esAlta
          ? 'Queda pendiente de activación hasta que la validemos.'
          : 'Corrige los datos de tu cuenta registrada.',
      acciones: [
        SButton(
          label: 'Cancelar',
          onPressed: _guardando ? null : () => Navigator.of(context).maybePop(),
          variant: SButtonVariant.secondary,
          size: SButtonSize.md,
          fullWidth: false,
        ),
        SButton(
          label: _esAlta ? 'Registrar cuenta' : 'Guardar cambios',
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
          if (!_esAlta) ...[
            Container(
              padding: EdgeInsets.all(t.space.sm),
              decoration: BoxDecoration(
                color: validada ? t.color.warningSoft : t.color.surfaceAlt,
                border: Border.all(
                  color: validada ? t.color.warning : t.color.border,
                ),
                borderRadius: t.radius.mdBorder,
              ),
              child: Text(
                validada
                    ? 'Esta cuenta ya está validada. Si cambias el banco, el '
                          'número de cuenta o la CLABE, la validamos de nuevo '
                          'antes de dispersarte.'
                    : 'Esta cuenta está pendiente de activación. Si corriges '
                          'algo, la validamos de nuevo.',
                style: t.text.caption.copyWith(
                  color: validada ? t.color.warningFg : t.color.fgMuted,
                  height: 1.45,
                ),
              ),
            ),
            SizedBox(height: t.space.md),
          ],
          SSelectField<int>(
            label: 'Banco',
            requerido: true,
            hint: 'Selecciona un banco',
            value: _idBanco,
            opciones: [
              for (final b in widget.bancos)
                (value: int.tryParse(b.valor) ?? 0, label: b.nombre),
            ],
            onChanged: _guardando ? null : (v) => setState(() => _idBanco = v),
          ),
          SizedBox(height: t.space.md),
          STextField(
            controller: _numeroCuenta,
            label: 'Número de cuenta',
            hint: '0123456789',
            size: STextFieldSize.md,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(34),
            ],
            helper: _esAlta
                ? 'Entre 8 y 34 dígitos, sin espacios.'
                : 'Captúralo completo: por seguridad no lo mostramos.',
            errorText: _erroresPorCampo['numero_cuenta'],
          ),
          SizedBox(height: t.space.md),
          STextField(
            controller: _clabe,
            label: 'CLABE (opcional)',
            hint: '012345678901234567',
            size: STextFieldSize.md,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(18),
            ],
            helper: 'Si la capturas, deben ser exactamente 18 dígitos.',
            errorText: _erroresPorCampo['clabe'],
          ),
          SizedBox(height: t.space.md),
          if ((widget.nombreDelAgente ?? '').isNotEmpty)
            Row(
              children: [
                Checkbox(
                  value: _titularSoyYo,
                  onChanged: _guardando
                      ? null
                      : (v) => setState(() {
                          _titularSoyYo = v ?? false;
                          if (_titularSoyYo) {
                            _titular.text = widget.nombreDelAgente!;
                          }
                        }),
                ),
                Expanded(
                  child: Text(
                    'El titular soy yo (${widget.nombreDelAgente})',
                    style: t.text.caption.copyWith(color: t.color.fgMuted),
                  ),
                ),
              ],
            ),
          STextField(
            controller: _titular,
            label: 'Titular de la cuenta',
            hint: 'Juan Pérez García',
            size: STextFieldSize.md,
            enabled: !_titularSoyYo,
            textCapitalization: TextCapitalization.words,
            errorText: _erroresPorCampo['titular'],
          ),
          SizedBox(height: t.space.lg),
          const SFieldLabel('Carátula del estado de cuenta', requerido: true),
          SizedBox(height: t.space.xxs),
          SDropZone(
            titulo: _evidenciaNombre == null
                ? 'Adjuntar carátula'
                : 'Cambiar archivo',
            subtitulo: 'PDF o imagen del estado de cuenta, hasta 10 MB',
            archivo: _evidenciaNombre,
            habilitado: !_guardando,
            onSeleccionar: elegirDocumento,
            onArchivo: (nombre, bytes) {
              final motivo = motivoArchivoInvalido(nombre, bytes);
              setState(() {
                if (motivo != null) {
                  _erroresPorCampo['evidencia'] = motivo;
                  return;
                }
                _evidenciaBytes = bytes;
                _evidenciaNombre = nombre;
                _erroresPorCampo.remove('evidencia');
              });
            },
          ),
          if (!_esAlta && _evidenciaNombre == null) ...[
            SizedBox(height: t.space.xxs),
            Text(
              'Si no adjuntas otra, se conserva la que ya tenemos.',
              style: t.text.overline.copyWith(color: t.color.fgSubtle),
            ),
          ],
          if (_erroresPorCampo['evidencia'] != null) ...[
            SizedBox(height: t.space.xxs),
            Text(
              _erroresPorCampo['evidencia']!,
              style: t.text.caption.copyWith(color: t.color.danger),
            ),
          ],
          if (_error != null) ...[
            SizedBox(height: t.space.md),
            Text(
              _error!,
              style: t.text.caption.copyWith(color: t.color.danger),
            ),
          ],
          SizedBox(height: t.space.sm),
          // Botón mudo del selector: `SDropZone` solo arrastra en web, y en
          // teléfono el toque abre el selector; este atajo lo hace explícito.
          SButton(
            label: 'Elegir archivo',
            icon: Icons.attach_file,
            onPressed: _guardando ? null : _elegirEvidencia,
            variant: SButtonVariant.ghost,
            size: SButtonSize.sm,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}
