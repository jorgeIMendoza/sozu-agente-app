import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/prospectos/components/prospecto_modal.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/prospectos_reglas.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Abre la transferencia de un prospecto a otro agente. Devuelve `true` si se
/// transfirió.
///
/// [idRelacion] es la relación prospecto × desarrollo: se transfiere el interés
/// en ESE desarrollo, no la persona completa.
Future<bool?> transferirProspecto(
  BuildContext context, {
  required int idRelacion,
  required String prospecto,
  required String desarrollo,
}) => mostrarHojaProspecto<bool>(
  context,
  _HojaTransferir(
    idRelacion: idRelacion,
    prospecto: prospecto,
    desarrollo: desarrollo,
  ),
);

class _HojaTransferir extends ConsumerStatefulWidget {
  final int idRelacion;
  final String prospecto;
  final String desarrollo;

  const _HojaTransferir({
    required this.idRelacion,
    required this.prospecto,
    required this.desarrollo,
  });

  @override
  ConsumerState<_HojaTransferir> createState() => _HojaTransferirState();
}

class _HojaTransferirState extends ConsumerState<_HojaTransferir> {
  final _motivo = TextEditingController();
  String? _destino;
  bool _transfiriendo = false;
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _transferir() async {
    final destino = _destino;
    if (destino == null) {
      setState(() => _error = 'Elige al agente que lo va a atender.');
      return;
    }
    setState(() {
      _transfiriendo = true;
      _error = null;
    });
    try {
      await ref
          .read(prospectosPortProvider)
          .transferir(
            idRelacion: widget.idRelacion,
            idAgenteDestino: destino,
            motivo: _motivo.text.trim().isEmpty ? null : _motivo.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _transfiriendo = false;
        _error = mensajeDeErrorProspecto(
          e,
          porDefecto: 'No se pudo transferir el prospecto.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final agentes = ref.watch(agentesDestinoProvider);

    return HojaProspecto(
      icono: Icons.swap_horiz,
      titulo: 'Transferir prospecto',
      subtitulo: 'Queda registro del traspaso',
      acciones: [
        SButton.secondary(
          label: 'Cancelar',
          fullWidth: false,
          onPressed: _transfiriendo ? null : () => Navigator.of(context).pop(),
        ),
        SButton(
          label: 'Transferir',
          fullWidth: false,
          loading: _transfiriendo,
          loadingLabel: 'Transfiriendo…',
          onPressed: _transfiriendo || _destino == null ? null : _transferir,
        ),
      ],
      children: [
        Container(
          padding: EdgeInsets.all(t.space.sm),
          decoration: BoxDecoration(
            color: tone.warningSoft,
            borderRadius: t.radius.mdBorder,
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: tone.warningFg),
              SizedBox(width: t.space.xs),
              Expanded(
                child: Text(
                  '${widget.prospecto} en ${widget.desarrollo}. '
                  'Al transferirlo dejarás de verlo en tu cartera.',
                  style: t.text.caption.copyWith(color: tone.warningFg),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: t.space.md),
        SFieldLabel('Agente destino', requerido: true),
        agentes.when(
          loading: () => const SSkeleton(height: 44),
          error: (e, _) => Text(
            mensajeDeErrorProspecto(
              e,
              porDefecto: 'No se pudo cargar la lista de agentes.',
            ),
            style: t.text.caption.copyWith(color: tone.danger),
          ),
          data: (lista) => lista.isEmpty
              ? Text(
                  'No hay agentes disponibles para recibir el prospecto.',
                  style: t.text.caption.copyWith(color: tone.fgSubtle),
                )
              : SSelectField<String>(
                  value: _destino,
                  hint: 'Elige al agente destino',
                  opciones: [
                    for (final a in lista) (value: a.id, label: a.etiqueta),
                  ],
                  onChanged: _transfiriendo
                      ? null
                      : (v) => setState(() => _destino = v),
                ),
        ),
        SizedBox(height: t.space.md),
        const SFieldLabel('Motivo'),
        STextField(
          controller: _motivo,
          hint: 'Opcional: por qué lo transfieres',
          size: STextFieldSize.md,
          maxLines: 2,
          enabled: !_transfiriendo,
        ),
        if (_error != null) ...[
          SizedBox(height: t.space.sm),
          Text(_error!, style: t.text.caption.copyWith(color: tone.danger)),
        ],
      ],
    );
  }
}
