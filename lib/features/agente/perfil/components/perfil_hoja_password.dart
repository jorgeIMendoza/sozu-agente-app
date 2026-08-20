import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja.dart';
import 'package:sozu_agente_app/features/auth/components/password_rules.dart';
import 'package:sozu_agente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Cambio voluntario de contraseña desde el Perfil.
Future<void> mostrarHojaDePassword(BuildContext context) =>
    mostrarHojaDePerfil<void>(
      context,
      child: const _HojaDePassword(),
      anchoMaximo: 460,
    );

class _HojaDePassword extends ConsumerStatefulWidget {
  const _HojaDePassword();

  @override
  ConsumerState<_HojaDePassword> createState() => _HojaDePasswordState();
}

class _HojaDePasswordState extends ConsumerState<_HojaDePassword> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmacion = TextEditingController();

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  /// La nueva contraseña no puede ser la actual: Auth lo rechaza con
  /// `same_password` y el viaje se ahorra diciéndoselo antes.
  bool get _repiteLaActual =>
      _nueva.text.isNotEmpty && _nueva.text == _actual.text;

  bool get _valido =>
      _actual.text.isNotEmpty &&
      isValidPassword(_nueva.text) &&
      !_repiteLaActual &&
      _confirmacion.text == _nueva.text;

  Future<void> _guardar() async {
    if (!_valido || _guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(authProvider).changePassword(_actual.text, _nueva.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      // El motivo exacto lo traduce auth (contraseña actual incorrecta, ya es
      // la tuya, filtrada, 429, sesión expirada): sin eso el agente ve un
      // "no se pudo" con las cinco palomitas en verde y reintenta lo mismo.
      setState(() {
        _error = AuthController.changePasswordErrorMessage(e);
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;

    return HojaDePerfil(
      titulo: 'Cambiar contraseña',
      subtitulo: 'Actualiza tu contraseña de acceso',
      acciones: [
        SButton(
          label: 'Cancelar',
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          variant: SButtonVariant.ghost,
          fullWidth: false,
        ),
        SButton(
          label: 'Actualizar contraseña',
          onPressed: _valido ? _guardar : null,
          loading: _guardando,
          loadingLabel: 'Guardando…',
          fullWidth: false,
        ),
      ],
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SFieldLabel('Contraseña actual', requerido: true),
          STextField.password(
            controller: _actual,
            hint: '••••••••',
            size: STextFieldSize.md,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: t.space.sm),
          SFieldLabel('Nueva contraseña', requerido: true),
          STextField.password(
            controller: _nueva,
            hint: '••••••••',
            size: STextFieldSize.md,
            autofillHints: const [AutofillHints.newPassword],
            errorText: _repiteLaActual
                ? 'La nueva contraseña debe ser distinta a la actual.'
                : null,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: t.space.xs),
          PasswordRulesChecklist(value: _nueva.text),
          SizedBox(height: t.space.sm),
          SFieldLabel('Confirmar nueva contraseña', requerido: true),
          STextField.password(
            controller: _confirmacion,
            hint: '••••••••',
            size: STextFieldSize.md,
            autofillHints: const [AutofillHints.newPassword],
            errorText:
                _confirmacion.text.isNotEmpty &&
                    _confirmacion.text != _nueva.text
                ? 'Las contraseñas no coinciden.'
                : null,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: t.space.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: SButton.link(
              label: '¿Olvidaste tu contraseña?',
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/forgot-password');
              },
              size: SButtonSize.sm,
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: t.space.sm),
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
