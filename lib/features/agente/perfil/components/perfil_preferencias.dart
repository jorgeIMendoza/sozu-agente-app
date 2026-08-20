import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/core/push_service.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/theme_selector.dart';
import 'package:sozu_agente_app/features/auth/components/biometric_toggle_card.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Preferencias del app (no del perfil): apariencia, notificaciones y acceso
/// biométrico. Van al final de la pantalla para no competir con el expediente,
/// que es lo que activa al agente.
class PerfilPreferencias extends StatelessWidget {
  const PerfilPreferencias({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SSectionLabel(text: 'Apariencia'),
        const SCard(child: ThemeSelector()),
        SizedBox(height: t.space.md),
        const SSectionLabel(text: 'Notificaciones'),
        const _Notificaciones(),
        // Se colapsa sola donde no hay biometría (web incluido).
        const BiometricToggleCard(),
      ],
    );
  }
}

class _Notificaciones extends StatelessWidget {
  const _Notificaciones();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 20,
                color: t.color.primary,
              ),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notificaciones push',
                      style: t.text.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: t.color.fg,
                      ),
                    ),
                    SizedBox(height: t.space.xxs),
                    // Diagnóstico, para soporte en campo.
                    ValueListenableBuilder<String>(
                      valueListenable: PushService.estado,
                      builder: (_, estado, __) => Text(
                        estado,
                        style: t.text.caption.copyWith(color: t.color.fgMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // La preferencia solo se ofrece donde hay push; en web vive la campana.
          if (PushService.soportado) ...[
            Divider(color: t.color.borderSoft, height: t.space.lg),
            const _InterruptorDePush(),
          ],
        ],
      ),
    );
  }
}

/// "Recibir notificaciones push": la preferencia vive en el backend y el envío la
/// respeta. Los tokens del dispositivo NO se dan de baja al desactivarla.
class _InterruptorDePush extends ConsumerStatefulWidget {
  const _InterruptorDePush();

  @override
  ConsumerState<_InterruptorDePush> createState() => _InterruptorDePushState();
}

class _InterruptorDePushState extends ConsumerState<_InterruptorDePush> {
  bool _activo = true;
  bool _cargando = true;

  /// false si la lectura falló (p. ej. backend sin la acción): el interruptor se
  /// muestra con el valor por defecto pero deshabilitado: degradación limpia.
  bool _disponible = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final activo = await ref.read(pushPortProvider).enabled();
      if (!mounted) return;
      setState(() {
        _activo = activo;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _disponible = false;
      });
    }
  }

  Future<void> _cambiar(bool valor) async {
    final anterior = _activo;
    setState(() => _activo = valor); // optimista
    try {
      await ref.read(pushPortProvider).setEnabled(valor);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            valor ? 'Notificaciones activadas' : 'Notificaciones desactivadas',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _activo = anterior);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la preferencia. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Recibir notificaciones push',
            style: t.text.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: t.color.fg,
            ),
          ),
        ),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Switch(value: _activo, onChanged: _disponible ? _cambiar : null),
      ],
    );
  }
}
