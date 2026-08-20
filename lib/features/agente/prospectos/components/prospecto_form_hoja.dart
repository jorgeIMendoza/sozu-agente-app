import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/prospectos/components/prospecto_modal.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/prospectos_reglas.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Espera antes de preguntar por duplicados, igual que el portal web: sin ella
/// escribir un correo dispara una petición por letra.
const _esperaDeDuplicados = Duration(milliseconds: 600);

/// Ladas soportadas por la plataforma para el teléfono del prospecto.
const _ladas = <SSelectOption<String>>[
  (value: 'MX', label: 'MX'),
  (value: 'US', label: 'US'),
  (value: 'CO', label: 'CO'),
];

/// Abre el alta o la edición de un prospecto. Devuelve `true` si se guardó,
/// para que la pantalla que la abrió recargue sus datos.
///
/// Con [persona] en null es un alta y arriba sale el buscador de duplicados; con
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

  /// Persona que se está editando. Es MUTABLE: el buscador de duplicados
  /// convierte un alta en edición sin cerrar la hoja.
  int? _idPersona;

  /// Prospecto elegido en el buscador de duplicados.
  Prospecto? _existente;

  /// Coincidencias del último criterio buscado (correo o teléfono).
  CoincidenciasDeProspecto _coincidencias = CoincidenciasDeProspecto.vacio;

  Timer? _debounceDuplicados;

  /// Marca de la búsqueda en vuelo: solo la última en volver pinta su resultado.
  int _ultimaBusqueda = 0;

  bool _cargandoExistente = false;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => _idPersona != null;

  /// La hoja se abrió sobre una persona concreta (botón "Editar" de la ficha):
  /// ahí no hay nada que desambiguar y el buscador de duplicados no aplica.
  bool get _abiertaComoEdicion => widget.persona != null;

  bool get _bloqueado => _guardando || _cargandoExistente;

  /// Quitarle el ÚLTIMO desarrollo a un prospecto que ya existe lo saca de la
  /// cartera y desde el app no hay forma de recuperarlo (el servidor desactiva
  /// todas sus relaciones sin avisar). En un alta todavía no hay nada que
  /// perder, así que ahí sí se puede vaciar la lista.
  bool get _puedeQuitarDesarrollo => !_esEdicion || _elegidos.length > 1;

  @override
  void initState() {
    super.initState();
    final p = widget.persona;
    _idPersona = p?.id;
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
    _debounceDuplicados?.cancel();
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
    if (_elegidos.isEmpty) return 'Elige al menos un desarrollo de interés.';
    return null;
  }

  /// Desarrollos donde ya está registrada la persona que el servidor
  /// reutilizaría al guardar. Solo cuenta la coincidencia por CORREO: un
  /// teléfono repetido puede ser de un familiar y sus desarrollos no son estos.
  Set<int> get _yaRegistrados {
    for (final c in _coincidencias.coincidencias) {
      if (c.motivo != MotivoCoincidencia.telefono) {
        return c.desarrollosRegistrados.toSet();
      }
    }
    return const {};
  }

  /// Reprograma la búsqueda de duplicados al escribir correo o teléfono. En
  /// edición no aplica: la persona ya está elegida y no hay qué desambiguar.
  void _programarBusquedaDeDuplicados() {
    _debounceDuplicados?.cancel();
    if (_esEdicion) return;
    final correo = _email.text;
    final telefono = _telefono.text;
    if (!hayCriterioDeDuplicados(email: correo, telefono: telefono)) {
      _olvidarCoincidencias();
      return;
    }
    _debounceDuplicados = Timer(
      _esperaDeDuplicados,
      () => _buscarDuplicados(correo, telefono),
    );
  }

  void _olvidarCoincidencias() {
    if (_coincidencias.coincidencias.isEmpty && !_coincidencias.noDisponible) {
      return;
    }
    setState(() => _coincidencias = CoincidenciasDeProspecto.vacio);
  }

  /// El aviso no es un requisito del alta: si la búsqueda falla se pinta la nota
  /// discreta y el agente puede guardar igual.
  Future<void> _buscarDuplicados(String email, String telefono) async {
    final marca = ++_ultimaBusqueda;
    var resultado = const CoincidenciasDeProspecto(noDisponible: true);
    try {
      resultado = await ref
          .read(prospectosPortProvider)
          .buscarExistente(
            email: errorEmail(email) == null ? email.trim() : null,
            telefono: telefono.trim(),
            excluirIdPersona: _idPersona,
          );
    } catch (_) {
      // Sin rastro del error: el correo y el teléfono del prospecto son PII.
    }
    if (!mounted || marca != _ultimaBusqueda) return;
    setState(() => _coincidencias = resultado);
  }

  /// Carga los datos de un prospecto que ya existe y convierte el alta en
  /// edición. La cartera no trae RFC, CURP ni tipo de persona: eso solo viene en
  /// la ficha, así que se pide.
  Future<void> _usarExistente(Prospecto? p) async {
    if (p == null) {
      setState(() {
        _existente = null;
        _idPersona = null;
        _elegidos.clear();
        _error = null;
        _coincidencias = CoincidenciasDeProspecto.vacio;
        for (final c in [_nombre, _email, _telefono, _rfc, _curp]) {
          c.clear();
        }
        _tipoPersona = 'pf';
        _lada = 'MX';
      });
      return;
    }
    setState(() {
      _existente = p;
      _cargandoExistente = true;
      _error = null;
      _coincidencias = CoincidenciasDeProspecto.vacio;
    });
    try {
      final ficha = await ref.read(prospectosPortProvider).detalle(p.idPersona);
      if (!mounted) return;
      final persona = ficha.persona;
      setState(() {
        _cargandoExistente = false;
        _idPersona = persona.id;
        _nombre.text = persona.nombre;
        _email.text = persona.email ?? '';
        _telefono.text = persona.telefono ?? '';
        _rfc.text = persona.rfc ?? '';
        _curp.text = persona.curp ?? '';
        _tipoPersona = persona.tipoPersona;
        _lada = persona.clavePaisTelefono ?? 'MX';
        _elegidos
          ..clear()
          ..addEntries(
            ficha.desarrollos
                .where((d) => d.idDesarrollo != null)
                .map((d) => MapEntry(d.idDesarrollo!, d.nombre)),
          );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoExistente = false;
        _existente = null;
        _error = mensajeDeErrorProspecto(
          e,
          porDefecto: 'No pudimos abrir ese prospecto. Intenta de nuevo.',
        );
      });
    }
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
          idPersona: _idPersona!,
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
    final yaRegistrados = _yaRegistrados;

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
          onPressed: _bloqueado ? null : () => Navigator.of(context).pop(),
        ),
        SButton(
          label: _esEdicion ? 'Actualizar' : 'Guardar',
          fullWidth: false,
          loading: _guardando,
          loadingLabel: 'Guardando…',
          onPressed: _bloqueado ? null : _guardar,
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

        // Buscador de duplicados: elegir uno convierte el alta en edición y
        // precarga sus datos, en vez de dar de alta a la misma persona otra vez.
        if (!_abiertaComoEdicion) ...[
          _BuscadorDeProspecto(
            prospectos:
                ref.watch(carteraProspectosProvider).valueOrNull?.prospectos ??
                const [],
            valor: _existente,
            cargando: _cargandoExistente,
            onElegido: _usarExistente,
          ),
          SizedBox(height: t.space.md),
        ],

        // Desarrollos de interés
        const SFieldLabel('Desarrollos de interés', requerido: true),
        if (_elegidos.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: t.space.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: t.space.xs,
                  runSpacing: t.space.xs,
                  children: [
                    for (final e in _elegidos.entries)
                      SChoiceChip(
                        label: e.value,
                        icon: Icons.check,
                        selected: true,
                        size: SChoiceChipSize.sm,
                        enabled: !_bloqueado && _puedeQuitarDesarrollo,
                        // Tocar la pastilla la quita de la lista: es el mismo
                        // gesto de "deseleccionar" del filtro.
                        onSelected: (_) =>
                            setState(() => _elegidos.remove(e.key)),
                      ),
                  ],
                ),
                if (!_puedeQuitarDesarrollo) ...[
                  SizedBox(height: t.space.xxs),
                  Text(
                    'El último desarrollo no se puede quitar: el prospecto '
                    'saldría de tu cartera.',
                    style: t.text.caption.copyWith(color: tone.fgSubtle),
                  ),
                ],
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
            // Un desarrollo que la persona encontrada ya tiene no se puede
            // volver a agregar: el servidor lo rechaza y desde aquí no se ve de
            // quién es ese lead.
            final registrados = disponibles
                .where((d) => yaRegistrados.contains(d.id))
                .toList(growable: false);
            final agregables = disponibles
                .where((d) => !yaRegistrados.contains(d.id))
                .toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (agregables.isEmpty)
                  Text(
                    lista.isEmpty
                        ? 'No tienes desarrollos asignados. Pide acceso a tu '
                              'administrador para poder ligar prospectos.'
                        : 'Ya agregaste todos tus desarrollos.',
                    style: t.text.caption.copyWith(color: tone.fgSubtle),
                  )
                else
                  SSelectField<int>(
                    value: null,
                    hint: 'Agregar desarrollo…',
                    opciones: [
                      for (final d in agregables)
                        (value: d.id, label: d.nombre),
                    ],
                    onChanged: _bloqueado
                        ? null
                        : (id) {
                            if (id == null) return;
                            final nombre = agregables
                                .firstWhere((d) => d.id == id)
                                .nombre;
                            setState(() => _elegidos[id] = nombre);
                          },
                  ),
                if (registrados.isNotEmpty) ...[
                  SizedBox(height: t.space.xs),
                  Wrap(
                    spacing: t.space.xs,
                    runSpacing: t.space.xs,
                    children: [
                      for (final d in registrados)
                        SChoiceChip(
                          label: '${d.nombre} · Ya registrado',
                          icon: Icons.block,
                          selected: false,
                          enabled: false,
                          size: SChoiceChipSize.sm,
                          onSelected: (_) {},
                        ),
                    ],
                  ),
                  SizedBox(height: t.space.xxs),
                  Text(
                    'Ya tiene interés registrado ahí: no se puede agregar otra '
                    'vez.',
                    style: t.text.caption.copyWith(color: tone.fgSubtle),
                  ),
                ],
              ],
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
              enabled: !_bloqueado,
              onSelected: (_) => setState(() => _tipoPersona = 'pf'),
            ),
            SizedBox(width: t.space.xs),
            SChoiceChip(
              label: 'Moral',
              selected: _tipoPersona == 'pm',
              enabled: !_bloqueado,
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
          enabled: !_bloqueado,
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
          enabled: !_esEdicion && !_bloqueado,
          onChanged: (_) => _programarBusquedaDeDuplicados(),
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
                onChanged: _bloqueado
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
                enabled: !_bloqueado,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (_) => _programarBusquedaDeDuplicados(),
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
          enabled: !_bloqueado,
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
          enabled: !_bloqueado,
          maxLength: 18,
          inputFormatters: [_mayusculas, LengthLimitingTextInputFormatter(18)],
          errorText: errorCurp(_curp.text),
          onChanged: (_) => setState(() {}),
        ),

        // Aviso de duplicados. Nunca bloquea el guardado: la verificación puede
        // no estar disponible y un teléfono repetido a veces es legítimo.
        if (!_esEdicion && _coincidencias.hayCoincidencias) ...[
          SizedBox(height: t.space.md),
          _AvisoDeDuplicados(_coincidencias.coincidencias),
        ] else if (!_esEdicion && _coincidencias.noDisponible) ...[
          SizedBox(height: t.space.md),
          Text(
            duplicadosNoDisponibles,
            style: t.text.caption.copyWith(color: tone.fgSubtle),
          ),
        ],
      ],
    );
  }
}

/// Aviso de que la persona que se está capturando ya existe. Es informativo a
/// propósito: el alta sigue disponible porque el duplicado a veces es legítimo
/// (un familiar con el mismo teléfono) y la verificación puede fallar.
class _AvisoDeDuplicados extends StatelessWidget {
  final List<ProspectoCoincidencia> coincidencias;

  const _AvisoDeDuplicados(this.coincidencias);

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return SCard.outlined(
      borderColor: tone.warning,
      padding: EdgeInsets.zero,
      clip: true,
      child: ColoredBox(
        color: tone.warningSoft,
        child: Padding(
          padding: EdgeInsets.all(t.space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: tone.warningFg,
                  ),
                  SizedBox(width: t.space.xs),
                  Expanded(
                    child: Text(
                      encabezadoDeDuplicados(coincidencias.length),
                      style: t.text.caption.copyWith(
                        color: tone.warningFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              for (final c in coincidencias) ...[
                SizedBox(height: t.space.xs),
                _FichaDeCoincidencia(c),
              ],
              SizedBox(height: t.space.xs),
              Text(
                cierreDeDuplicados,
                style: t.text.caption.copyWith(color: tone.warningFg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una coincidencia: quién es, por qué coincidió y en qué desarrollos está, con
/// el dueño de cada lead. Del dueño ajeno solo se sabe su nombre.
class _FichaDeCoincidencia extends StatelessWidget {
  final ProspectoCoincidencia coincidencia;

  const _FichaDeCoincidencia(this.coincidencia);

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final c = coincidencia;

    return SCard.outlined(
      padding: EdgeInsets.all(t.space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.nombre,
                  style: t.text.bodySmall.copyWith(
                    color: tone.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (c.esCliente)
                const SBadge(
                  label: 'Cliente',
                  tone: SBadgeTone.positive,
                  size: SBadgeSize.sm,
                ),
            ],
          ),
          Text(
            'Porque ${motivoEnPalabras(c.motivo)}',
            style: t.text.caption.copyWith(color: tone.fgSubtle),
          ),
          SizedBox(height: t.space.xxs),
          Text(
            describirCoincidencia(c),
            style: t.text.caption.copyWith(color: tone.warningFg),
          ),
          for (final l in c.leads) ...[
            SizedBox(height: t.space.xxs),
            Wrap(
              spacing: t.space.xxs,
              runSpacing: t.space.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l.desarrollo,
                  style: t.text.caption.copyWith(
                    color: tone.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '· ${l.dueno ?? 'otro asesor'}',
                  style: t.text.caption.copyWith(color: tone.fgSubtle),
                ),
                if (l.estado != null && l.estado!.isNotEmpty)
                  Text(
                    '· ${l.estado}',
                    style: t.text.caption.copyWith(color: tone.fgSubtle),
                  ),
                if (l.esMio)
                  const SBadge(
                    label: 'Tuyo',
                    tone: SBadgeTone.info,
                    size: SBadgeSize.sm,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Buscador de la propia cartera para no dar de alta dos veces a la misma
/// persona. Elegir un prospecto convierte el alta en edición.
class _BuscadorDeProspecto extends StatelessWidget {
  final List<Prospecto> prospectos;
  final Prospecto? valor;
  final bool cargando;
  final ValueChanged<Prospecto?> onElegido;

  const _BuscadorDeProspecto({
    required this.prospectos,
    required this.valor,
    required this.cargando,
    required this.onElegido,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SAutocompleteField<Prospecto>(
          labelText: '¿Ya lo tienes registrado? Búscalo para no duplicar',
          hintText: 'Escribe su nombre o correo…',
          prefixIcon: Icons.search,
          options: prospectos,
          labelOf: (p) => p.nombre,
          searchTextOf: (p) => '${p.nombre} ${p.email ?? ''}',
          value: valor,
          enabled: !cargando,
          onSelected: onElegido,
        ),
        if (cargando) ...[
          SizedBox(height: t.space.xxs),
          Text(
            'Cargando sus datos…',
            style: t.text.caption.copyWith(color: t.color.fgSubtle),
          ),
        ],
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
