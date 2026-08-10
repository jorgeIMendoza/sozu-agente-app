import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/prospectos/components/prospecto_modal.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/prospectos_reglas.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Ladas soportadas por la plataforma para el teléfono del prospecto.
const _ladas = <SSelectOption<String>>[
  (value: 'MX', label: 'MX'),
  (value: 'US', label: 'US'),
  (value: 'CO', label: 'CO'),
];

/// Abre el alta o la edición de un prospecto. Devuelve `true` si se guardó,
/// para que la pantalla que la abrió recargue sus datos.
///
/// Con [persona] en null es un alta y los desarrollos son obligatorios; con
/// persona es una edición y [desarrollos] son los intereses que ya tiene.
Future<bool?> editarProspecto(
  BuildContext context, {
  PersonaProspecto? persona,
  List<DesarrolloDeInteres> desarrollos = const [],
}) => mostrarHojaProspecto<bool>(
  context,
  _HojaFormProspecto(persona: persona, desarrollosActuales: desarrollos),
);

class _HojaFormProspecto extends ConsumerStatefulWidget {
  final PersonaProspecto? persona;
  final List<DesarrolloDeInteres> desarrollosActuales;

  const _HojaFormProspecto({this.persona, this.desarrollosActuales = const []});

  @override
  ConsumerState<_HojaFormProspecto> createState() => _HojaFormProspectoState();
}

class _HojaFormProspectoState extends ConsumerState<_HojaFormProspecto> {
  late final TextEditingController _nombre;
  late final TextEditingController _email;
  late final TextEditingController _telefono;
  late final TextEditingController _rfc;
  late final TextEditingController _curp;

  late String _tipoPersona;
  late String _lada;

  /// Desarrollos elegidos: id → nombre. En edición es la lista COMPLETA que se
  /// manda, porque el servidor da de baja lo que no venga.
  final Map<int, String> _elegidos = {};

  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.persona != null;

  @override
  void initState() {
    super.initState();
    final p = widget.persona;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _telefono = TextEditingController(text: p?.telefono ?? '');
    _rfc = TextEditingController(text: p?.rfc ?? '');
    _curp = TextEditingController(text: p?.curp ?? '');
    _tipoPersona = p?.tipoPersona ?? 'pf';
    _lada = p?.clavePaisTelefono ?? 'MX';
    for (final d in widget.desarrollosActuales) {
      if (d.idDesarrollo != null) _elegidos[d.idDesarrollo!] = d.nombre;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _telefono.dispose();
    _rfc.dispose();
    _curp.dispose();
    super.dispose();
  }

  /// Primer motivo por el que no se puede guardar, o null si todo está bien.
  String? get _motivoInvalido {
    if (_nombre.text.trim().isEmpty) return 'Escribe el nombre completo.';
    final email = errorEmail(_email.text);
    if (email != null) return email;
    final tel = errorTelefono(_telefono.text);
    if (tel != null) return tel;
    final rfc = errorRfc(_rfc.text);
    if (rfc != null) return 'RFC: $rfc';
    final curp = errorCurp(_curp.text);
    if (curp != null) return 'CURP: $curp';
    if (!_esEdicion && _elegidos.isEmpty) {
      return 'Elige al menos un desarrollo de interés.';
    }
    return null;
  }

  Future<void> _guardar() async {
    final motivo = _motivoInvalido;
    if (motivo != null) {
      setState(() => _error = motivo);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });

    final datos = DatosProspecto(
      tipoPersona: _tipoPersona,
      nombre: _nombre.text.trim(),
      email: _email.text.trim().toLowerCase(),
      telefono: _telefono.text.trim(),
      clavePaisTelefono: _lada,
      rfc: _rfc.text.trim().isEmpty ? null : _rfc.text.trim().toUpperCase(),
      curp: _curp.text.trim().isEmpty ? null : _curp.text.trim().toUpperCase(),
    );

    try {
      final port = ref.read(prospectosPortProvider);
      if (_esEdicion) {
        await port.editar(
          idPersona: widget.persona!.id,
          datos: datos,
          desarrollos: _elegidos.keys.toList(growable: false),
        );
      } else {
        await port.crear(
          datos: datos,
          desarrollos: _elegidos.keys.toList(growable: false),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeDeErrorProspecto(
          e,
          porDefecto: 'No se pudo guardar el prospecto. Revisa los datos.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final vinculables = ref.watch(desarrollosVinculablesProvider);

    return HojaProspecto(
      icono: _esEdicion ? Icons.edit_outlined : Icons.person_add_alt,
      titulo: _esEdicion ? 'Editar prospecto' : 'Nuevo prospecto',
      subtitulo: _esEdicion
          ? 'Los desarrollos que quites dejan de aparecer en su ficha'
          : 'Se liga a los desarrollos que tú vendes',
      acciones: [
        SButton.secondary(
          label: 'Cancelar',
          fullWidth: false,
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
        ),
        SButton(
          label: _esEdicion ? 'Actualizar' : 'Guardar',
          fullWidth: false,
          loading: _guardando,
          loadingLabel: 'Guardando…',
          onPressed: _guardando ? null : _guardar,
        ),
      ],
      children: [
        if (_error != null) ...[
          Container(
            padding: EdgeInsets.all(t.space.sm),
            decoration: BoxDecoration(
              color: tone.dangerSoft,
              borderRadius: t.radius.mdBorder,
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: tone.danger),
                SizedBox(width: t.space.xs),
                Expanded(
                  child: Text(
                    _error!,
                    style: t.text.caption.copyWith(color: tone.danger),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: t.space.md),
        ],

        // Desarrollos de interés
        SFieldLabel('Desarrollos de interés', requerido: !_esEdicion),
        if (_elegidos.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: t.space.xs),
            child: Wrap(
              spacing: t.space.xs,
              runSpacing: t.space.xs,
              children: [
                for (final e in _elegidos.entries)
                  SChoiceChip(
                    label: e.value,
                    icon: Icons.check,
                    selected: true,
                    size: SChoiceChipSize.sm,
                    enabled: !_guardando,
                    // Tocar la pastilla la quita de la lista: es el mismo gesto
                    // de "deseleccionar" del filtro.
                    onSelected: (_) => setState(() => _elegidos.remove(e.key)),
                  ),
              ],
            ),
          ),
        vinculables.when(
          loading: () => const SSkeleton(height: 44),
          error: (e, _) => Text(
            mensajeDeErrorProspecto(
              e,
              porDefecto: 'No se pudieron cargar tus desarrollos.',
            ),
            style: t.text.caption.copyWith(color: tone.danger),
          ),
          data: (lista) {
            final disponibles = lista
                .where((d) => !_elegidos.containsKey(d.id))
                .toList(growable: false);
            if (disponibles.isEmpty) {
              return Text(
                lista.isEmpty
                    ? 'No tienes desarrollos asignados. Pide acceso a tu '
                          'administrador para poder ligar prospectos.'
                    : 'Ya agregaste todos tus desarrollos.',
                style: t.text.caption.copyWith(color: tone.fgSubtle),
              );
            }
            return SSelectField<int>(
              value: null,
              hint: 'Agregar desarrollo…',
              opciones: [
                for (final d in disponibles) (value: d.id, label: d.nombre),
              ],
              onChanged: _guardando
                  ? null
                  : (id) {
                      if (id == null) return;
                      final nombre = disponibles
                          .firstWhere((d) => d.id == id)
                          .nombre;
                      setState(() => _elegidos[id] = nombre);
                    },
            );
          },
        ),
        SizedBox(height: t.space.md),

        // Tipo de persona
        SFieldLabel('Tipo de persona', requerido: true),
        Row(
          children: [
            SChoiceChip(
              label: 'Física',
              selected: _tipoPersona == 'pf',
              enabled: !_guardando,
              onSelected: (_) => setState(() => _tipoPersona = 'pf'),
            ),
            SizedBox(width: t.space.xs),
            SChoiceChip(
              label: 'Moral',
              selected: _tipoPersona == 'pm',
              enabled: !_guardando,
              onSelected: (_) => setState(() => _tipoPersona = 'pm'),
            ),
          ],
        ),
        SizedBox(height: t.space.md),

        SFieldLabel('Nombre completo', requerido: true),
        STextField(
          controller: _nombre,
          hint: 'Juan Pérez García',
          size: STextFieldSize.md,
          enabled: !_guardando,
          textCapitalization: TextCapitalization.words,
        ),
        SizedBox(height: t.space.sm),

        SFieldLabel('Correo', requerido: true, habilitado: !_esEdicion),
        STextField(
          controller: _email,
          hint: 'juan.perez@correo.com',
          size: STextFieldSize.md,
          keyboardType: TextInputType.emailAddress,
          // En edición el correo identifica a la persona en la plataforma: se
          // cambia desde el panel, no desde aquí.
          enabled: !_esEdicion && !_guardando,
        ),
        SizedBox(height: t.space.sm),

        SFieldLabel('Teléfono', requerido: true),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: SSelectField<String>(
                value: _lada,
                opciones: _ladas,
                onChanged: _guardando
                    ? null
                    : (v) => setState(() => _lada = v ?? 'MX'),
              ),
            ),
            SizedBox(width: t.space.xs),
            Expanded(
              child: STextField(
                controller: _telefono,
                hint: '5512345678',
                size: STextFieldSize.md,
                enabled: !_guardando,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: t.space.sm),

        const SFieldLabel('RFC'),
        STextField(
          controller: _rfc,
          hint: 'PEGJ850101H2A',
          size: STextFieldSize.md,
          enabled: !_guardando,
          maxLength: 13,
          inputFormatters: [_mayusculas, LengthLimitingTextInputFormatter(13)],
          errorText: errorRfc(_rfc.text),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: t.space.sm),

        const SFieldLabel('CURP'),
        STextField(
          controller: _curp,
          hint: 'PEGJ850101HDFRRN09',
          size: STextFieldSize.md,
          enabled: !_guardando,
          maxLength: 18,
          inputFormatters: [_mayusculas, LengthLimitingTextInputFormatter(18)],
          errorText: errorCurp(_curp.text),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

/// RFC y CURP se guardan en mayúsculas: se convierten al escribir para que lo
/// que se ve sea lo que se manda.
final _mayusculas = TextInputFormatter.withFunction(
  (anterior, nuevo) => TextEditingValue(
    text: nuevo.text.toUpperCase(),
    selection: nuevo.selection,
  ),
);
