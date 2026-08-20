import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/citas/providers/citas_providers.dart';
import 'package:sozu_agente_app/features/agente/citas/services/seleccion_de_cita.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/compartir_negocio.dart';
import 'package:sozu_agente_app/features/agente/pipeline/components/pipeline_modal.dart';
import 'package:sozu_agente_app/features/agente/pipeline/ports/pipeline_port.dart';
import 'package:sozu_agente_app/features/agente/pipeline/providers/pipeline_providers.dart';
import 'package:sozu_agente_app/features/agente/pipeline/services/pipeline_textos.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/prospecto_form_hoja.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/prospectos_reglas.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Configuración de la oferta de una unidad: el paso que convierte una unidad
/// del inventario en un negocio del pipeline.
///
/// Reúne lo que `crear_oferta` necesita (prospecto, plan, forma de entrega) y,
/// ya creada, ofrece compartirla. Los montos son solo de lectura: la oferta no
/// guarda importes y ninguno viaja al servidor.

/// Extra de la unidad que se cobra aparte: cada uno genera su propia oferta.
class ExtraParaOferta {
  final String etiqueta;

  /// `false` = estacionamiento. Solo decide el icono.
  final bool esBodega;

  final double costo;

  const ExtraParaOferta({
    required this.etiqueta,
    this.esBodega = false,
    this.costo = 0,
  });
}

/// Lo que la hoja necesita saber de la unidad.
///
/// Lo arma la pantalla del inventario a partir de su propio DTO: así ninguna de
/// las dos features depende de los modelos de la otra.
class UnidadParaOferta {
  final int idPropiedad;

  /// Número de la unidad tal como se le muestra al agente ("A-301").
  final String etiqueta;

  final String desarrollo;

  /// Precio de lista más los extras que se cobran aparte.
  final double precioTotal;

  /// Plan elegido en el detalle de la unidad; null = sin plan, que el servidor
  /// acepta y se puede fijar después.
  final int? idEsquemaPago;

  final String esquemaNombre;

  final List<ExtraParaOferta> extras;

  const UnidadParaOferta({
    required this.idPropiedad,
    this.etiqueta = '',
    this.desarrollo = '',
    this.precioTotal = 0,
    this.idEsquemaPago,
    this.esquemaNombre = '',
    this.extras = const [],
  });
}

/// De dónde sale el prospecto de la oferta.
enum _OrigenProspecto { cartera, captura }

/// Abre la configuración de la oferta. Devuelve la oferta creada, o null si el
/// agente cerró la hoja sin generarla.
///
/// [onAgendarCapacitacion] lleva a agendar la capacitación: es la única salida
/// cuando el servidor responde `capacitacion_pendiente`.
Future<OfertaCreada?> configurarNuevaOferta(
  BuildContext context, {
  required UnidadParaOferta unidad,
  required VoidCallback onAgendarCapacitacion,
}) => mostrarHojaPipeline<OfertaCreada>(
  context,
  _NuevaOfertaHoja(
    unidad: unidad,
    onAgendarCapacitacion: onAgendarCapacitacion,
  ),
);

/// Ladas soportadas por la plataforma para el teléfono del prospecto. Mismo
/// catálogo que el alta de Prospectos.
const _ladas = <SSelectOption<String>>[
  (value: 'MX', label: 'MX'),
  (value: 'US', label: 'US'),
  (value: 'CO', label: 'CO'),
];

/// Cuántos prospectos caben en un desplegable antes de pasar al buscador. Mismo
/// corte que la hoja de agendado.
const int _maxProspectosEnLista = 12;

class _NuevaOfertaHoja extends ConsumerStatefulWidget {
  final UnidadParaOferta unidad;
  final VoidCallback onAgendarCapacitacion;

  const _NuevaOfertaHoja({
    required this.unidad,
    required this.onAgendarCapacitacion,
  });

  @override
  ConsumerState<_NuevaOfertaHoja> createState() => _NuevaOfertaHojaState();
}

class _NuevaOfertaHojaState extends ConsumerState<_NuevaOfertaHoja> {
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _rfc = TextEditingController();
  final _curp = TextEditingController();

  _OrigenProspecto _origen = _OrigenProspecto.cartera;
  ProspectoParaCita? _elegido;
  String _lada = 'MX';
  String _tipoPersona = 'pf';

  /// Encendido por omisión: sin link no hay oferta digital que mandar. Solo
  /// aplica con permiso de oferta digital; sin él se queda apagado y la casilla
  /// no se ofrece (ver [_puedeOfertaDigital]).
  bool _crearLink = true;

  bool _enviarEmail = false;
  bool _adjuntarPdf = false;

  bool _creando = false;

  /// ¿El rol puede emitir la oferta digital? El permiso llega en la sesión
  /// (`generar_oferta_digital`, por omisión falso, igual que en la web).
  bool get _puedeOfertaDigital => ref
      .watch(permisosVistaProvider(VistaAgente.inventario))
      .generarOfertaDigital;

  /// Fallo del último intento. Se pinta DENTRO de la hoja: un toast se va antes
  /// de que el agente lo lea y cerrar la hoja perdería lo capturado.
  String? _error;

  /// El servidor bloqueó la oferta por capacitación: se ofrece el atajo.
  bool _faltaCapacitacion = false;

  /// Oferta ya creada. Mientras es null la hoja es el formulario.
  OfertaCreada? _creada;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _telefono.dispose();
    _rfc.dispose();
    _curp.dispose();
    super.dispose();
  }

  /// Ficha completa del prospecto elegido: la lista de citas solo trae id y
  /// nombre, y es el correo el que decide si el link se puede emitir.
  Prospecto? get _fichaElegida {
    final id = _elegido?.idPersona;
    if (id == null) return null;
    final cartera = ref.read(carteraProspectosProvider).valueOrNull;
    for (final p in cartera?.prospectos ?? const <Prospecto>[]) {
      if (p.idPersona == id) return p;
    }
    return null;
  }

  /// El link y el correo se emiten A UN CORREO: sin él el servidor responde
  /// `email_invalido` y no crea nada, así que se frena aquí.
  bool get _faltaCorreoDeCartera =>
      _origen == _OrigenProspecto.cartera &&
      _elegido != null &&
      (_crearLink || _enviarEmail) &&
      (_fichaElegida?.email ?? '').trim().isEmpty;

  /// Nombre capturado sin espacios de sobra: es como lo guarda el servidor.
  String get _nombreCapturado => _nombre.text.trim();

  bool get _capturaCompleta =>
      _nombreCapturado.isNotEmpty &&
      errorEmail(_email.text) == null &&
      errorTelefono(_telefono.text) == null &&
      errorRfc(_rfc.text) == null &&
      errorCurp(_curp.text) == null;

  bool get _sePuedeGenerar {
    if (_creando || _faltaCorreoDeCartera) return false;
    return _origen == _OrigenProspecto.cartera
        ? _elegido != null
        : _capturaCompleta;
  }

  /// Por qué el botón está apagado. Un botón gris sin motivo se reporta como bug.
  String? get _nota {
    if (_creada != null) return null;
    if (_faltaCorreoDeCartera) {
      return 'Ese prospecto no tiene correo registrado y el link de la oferta '
          'se emite a un correo. Captúralo en Prospectos, o apaga el link para '
          'cotizar sin él.';
    }
    if (_origen == _OrigenProspecto.cartera && _elegido == null) {
      return 'Elige al prospecto de tu cartera o captura uno nuevo.';
    }
    if (_origen == _OrigenProspecto.captura && !_capturaCompleta) {
      return 'Captura nombre, correo y un teléfono de 10 dígitos.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final creada = _creada;
    return HojaPipeline(
      icono: Icons.request_quote_outlined,
      titulo: creada == null ? 'Configurar la oferta' : 'Oferta generada',
      subtitulo: _tituloUnidad,
      cuerpo: creada == null
          ? _formulario(context)
          : _resultado(context, creada),
      nota: _nota,
      acciones: [
        if (creada == null)
          SButton(
            label: 'Generar la oferta',
            icon: Icons.check,
            fullWidth: false,
            loading: _creando,
            loadingLabel: 'Generando la oferta...',
            onPressed: _sePuedeGenerar ? _generar : null,
          )
        else
          SButton(
            label: 'Listo',
            fullWidth: false,
            onPressed: () => Navigator.of(context).pop(creada),
          ),
      ],
    );
  }

  String get _tituloUnidad => [
    widget.unidad.etiqueta,
    widget.unidad.desarrollo,
  ].where((s) => s.isNotEmpty).join(' · ');

  // ── Formulario ────────────────────────────────────────────────────────────

  List<Widget> _formulario(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final u = widget.unidad;

    return [
      const SSectionLabel(text: 'Prospecto'),
      SizedBox(height: t.space.xs),
      Wrap(
        spacing: t.space.xxs,
        runSpacing: t.space.xxs,
        children: [
          SChoiceChip(
            label: 'De mi cartera',
            icon: Icons.folder_shared_outlined,
            selected: _origen == _OrigenProspecto.cartera,
            enabled: !_creando,
            onSelected: (_) => _cambiarOrigen(_OrigenProspecto.cartera),
          ),
          SChoiceChip(
            label: 'Capturar aquí',
            icon: Icons.person_add_alt_outlined,
            selected: _origen == _OrigenProspecto.captura,
            enabled: !_creando,
            onSelected: (_) => _cambiarOrigen(_OrigenProspecto.captura),
          ),
        ],
      ),
      SizedBox(height: t.space.xs),
      if (_origen == _OrigenProspecto.cartera)
        ..._selectorDeCartera(context)
      else
        ..._camposDeCaptura(context),

      SizedBox(height: t.space.md),
      const SSectionLabel(text: 'Plan de pago'),
      SizedBox(height: t.space.xs),
      SCard.outlined(
        child: Row(
          children: [
            Icon(
              Icons.payments_outlined,
              size: _iconoFila,
              color: tone.fgMuted,
            ),
            SizedBox(width: t.space.xs),
            Expanded(
              child: Text(
                _planElegido,
                style: t.text.bodySmall.copyWith(color: tone.fg),
              ),
            ),
          ],
        ),
      ),

      if (u.extras.isNotEmpty) ...[
        SizedBox(height: t.space.md),
        SSectionLabel(
          text: 'Extras que se cobran aparte',
          trailing: SBadge(label: '${u.extras.length}', size: SBadgeSize.sm),
        ),
        SizedBox(height: t.space.xs),
        SCard.outlined(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in u.extras) ...[
                Row(
                  children: [
                    Icon(
                      e.esBodega
                          ? Icons.warehouse_outlined
                          : Icons.directions_car_outlined,
                      size: _iconoFila,
                      color: tone.primary,
                    ),
                    SizedBox(width: t.space.xs),
                    Expanded(
                      child: Text(
                        e.etiqueta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.text.bodySmall.copyWith(color: tone.fg),
                      ),
                    ),
                    Text(
                      formatMXN(e.costo),
                      style: t.text.caption.copyWith(color: tone.fgMuted),
                    ),
                  ],
                ),
                SizedBox(height: t.space.xxs),
              ],
              Text(
                'Cada uno genera su propia oferta. Si no eliges plan, el '
                'servidor toma el primer plan activo de ese producto.',
                style: t.text.caption.copyWith(color: tone.fgMuted),
              ),
            ],
          ),
        ),
      ],

      // El permiso `generar_oferta_digital` decide si el agente puede emitir el
      // link del cliente, igual que en la web. Sin él no se ofrece ni se manda:
      // se parseaba en la sesión y no lo leía nadie, así que la app prometía una
      // oferta digital a quien no la tiene otorgada.
      if (_puedeOfertaDigital) ...[
        SizedBox(height: t.space.md),
        const SSectionLabel(text: 'Cómo se le entrega'),
        _Casilla(
          etiqueta: 'Generar el link para el cliente',
          valor: _crearLink,
          habilitado: !_creando,
          onCambio: (v) => setState(() {
            _crearLink = v;
            _error = null;
          }),
        ),
        // Mandarla por correo tambien depende del link: la function contesta 500
        // si no hay ni link ni adjunto, asi que sin oferta digital no se ofrece.
        _Casilla(
          etiqueta: 'Mandárselo por correo',
          valor: _enviarEmail,
          habilitado: !_creando,
          onCambio: (v) => setState(() {
            _enviarEmail = v;
            if (!v) _adjuntarPdf = false;
            _error = null;
          }),
        ),
        if (_enviarEmail)
          _Casilla(
            etiqueta: 'Adjuntar el PDF de la oferta',
            valor: _adjuntarPdf,
            habilitado: !_creando,
            onCambio: (v) => setState(() => _adjuntarPdf = v),
          ),
      ],

      SizedBox(height: t.space.md),
      _Total(precio: u.precioTotal, conExtras: u.extras.isNotEmpty),

      if (_error != null) ...[
        SizedBox(height: t.space.sm),
        Text(_error!, style: t.text.bodySmall.copyWith(color: tone.danger)),
        if (_faltaCapacitacion) ...[
          SizedBox(height: t.space.xs),
          SButton.secondary(
            label: 'Agendar mi capacitación',
            icon: Icons.school_outlined,
            onPressed: () {
              Navigator.of(context).pop();
              widget.onAgendarCapacitacion();
            },
          ),
        ],
      ],
    ];
  }

  String get _planElegido {
    final u = widget.unidad;
    if (u.idEsquemaPago == null) {
      return 'Sin plan elegido: la oferta sale sin esquema y se puede fijar '
          'después desde el pipeline.';
    }
    return u.esquemaNombre.isEmpty
        ? 'Plan elegido en el detalle de la unidad.'
        : u.esquemaNombre;
  }

  /// Prospectos de la cartera. Es el MISMO universo que el de agendar una cita:
  /// el servidor revalida la pertenencia al cotizar (`not_owner`).
  List<Widget> _selectorDeCartera(BuildContext context) {
    final t = context.s;
    final prospectos = ref.watch(prospectosParaCitaProvider);
    return [
      prospectos.when(
        loading: () => const SSkeleton(height: _altoSelector),
        error: (e, _) => SErrorState(
          title: 'No pudimos cargar tus prospectos',
          message: mensajeDeError(e),
          onRetry: () => ref.invalidate(carteraProspectosProvider),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return SEmptyState.card(
              icon: Icons.person_off_outlined,
              title: 'Todavía no tienes prospectos',
              message: 'Captura uno aquí mismo o dalo de alta en tu cartera.',
              action: SButton.secondary(
                label: 'Capturar aquí',
                fullWidth: false,
                onPressed: () => _cambiarOrigen(_OrigenProspecto.captura),
              ),
            );
          }
          if (lista.length > _maxProspectosEnLista) {
            return SAutocompleteField<ProspectoParaCita>(
              options: lista,
              value: _elegido,
              labelOf: (p) => p.nombre,
              hintText: 'Busca a tu prospecto...',
              prefixIcon: Icons.person_outline,
              enabled: !_creando,
              onSelected: (p) => setState(() => _elegido = p),
            );
          }
          return SSelectField<int>(
            value: _elegido?.idPersona,
            hint: 'Elige a tu prospecto',
            opciones: [
              for (final p in lista) (value: p.idPersona, label: p.nombre),
            ],
            onChanged: _creando
                ? null
                : (id) => setState(
                    () => _elegido = lista.firstWhere((p) => p.idPersona == id),
                  ),
          );
        },
      ),
      SizedBox(height: t.space.xxs),
      SButton.ghost(
        label: 'Dar de alta un prospecto',
        icon: Icons.person_add_alt_outlined,
        fullWidth: true,
        onPressed: _creando ? null : _altaEnCartera,
      ),
    ];
  }

  /// Prospecto capturado en la hoja: viaja como `prospecto` y lo da de alta el
  /// servidor, que ya deduplica por RFC y por correo.
  List<Widget> _camposDeCaptura(BuildContext context) {
    final t = context.s;
    return [
      Wrap(
        spacing: t.space.xxs,
        runSpacing: t.space.xxs,
        children: [
          for (final opcion in const [
            (clave: 'pf', texto: 'Persona física'),
            (clave: 'pm', texto: 'Persona moral'),
          ])
            SChoiceChip(
              label: opcion.texto,
              size: SChoiceChipSize.sm,
              selected: _tipoPersona == opcion.clave,
              enabled: !_creando,
              onSelected: (_) => setState(() => _tipoPersona = opcion.clave),
            ),
        ],
      ),
      SizedBox(height: t.space.xs),
      STextField(
        controller: _nombre,
        label: 'Nombre completo',
        hint: 'Como aparece en su identificación',
        size: STextFieldSize.md,
        enabled: !_creando,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => _revalidar(),
      ),
      SizedBox(height: t.space.xs),
      STextField(
        controller: _email,
        label: 'Correo',
        hint: 'prospecto@dominio.com',
        size: STextFieldSize.md,
        enabled: !_creando,
        keyboardType: TextInputType.emailAddress,
        errorText: _email.text.isEmpty ? null : errorEmail(_email.text),
        onChanged: (_) => _revalidar(),
      ),
      SizedBox(height: t.space.xs),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _anchoLada,
            child: SSelectField<String>(
              value: _lada,
              label: 'País',
              opciones: _ladas,
              onChanged: _creando
                  ? null
                  : (v) => setState(() => _lada = v ?? 'MX'),
            ),
          ),
          SizedBox(width: t.space.xs),
          Expanded(
            child: STextField(
              controller: _telefono,
              label: 'Teléfono',
              hint: '10 dígitos',
              size: STextFieldSize.md,
              enabled: !_creando,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              errorText: _telefono.text.isEmpty
                  ? null
                  : errorTelefono(_telefono.text),
              onChanged: (_) => _revalidar(),
            ),
          ),
        ],
      ),
      SizedBox(height: t.space.xs),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: STextField(
              controller: _rfc,
              label: 'RFC (opcional)',
              size: STextFieldSize.md,
              enabled: !_creando,
              textCapitalization: TextCapitalization.characters,
              errorText: errorRfc(_rfc.text),
              onChanged: (_) => _revalidar(),
            ),
          ),
          SizedBox(width: t.space.xs),
          Expanded(
            child: STextField(
              controller: _curp,
              label: 'CURP (opcional)',
              size: STextFieldSize.md,
              enabled: !_creando,
              textCapitalization: TextCapitalization.characters,
              errorText: errorCurp(_curp.text),
              onChanged: (_) => _revalidar(),
            ),
          ),
        ],
      ),
    ];
  }

  // ── Resultado ─────────────────────────────────────────────────────────────

  List<Widget> _resultado(BuildContext context, OfertaCreada creada) {
    final t = context.s;
    final tone = t.color;
    return [
      Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: _iconoResultado,
            color: tone.positive,
          ),
          SizedBox(width: t.space.xs),
          Expanded(
            child: WebSelectable(
              child: Text(
                folioDeOferta(creada.idOferta),
                style: t.text.h3.copyWith(color: tone.fg),
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: t.space.xxs),
      Text(
        creada.esRecotizacion
            ? 'Es otra versión de una oferta que ya le habías hecho a este '
                  'prospecto por esta unidad: no es un negocio nuevo.'
            : 'La oferta ya está en tu pipeline.',
        style: t.text.bodySmall.copyWith(color: tone.fgMuted),
      ),
      if (creada.prospectoCreado) ...[
        SizedBox(height: t.space.xxs),
        Text(
          'El prospecto se dio de alta en tu cartera.',
          style: t.text.caption.copyWith(color: tone.fgMuted),
        ),
      ],
      if (creada.idNegocio == null) ...[
        SizedBox(height: t.space.xxs),
        Text(
          'No pudimos confirmar el negocio del pipeline. Refresca Pipeline en '
          'un momento; si no aparece, avísale al administrador.',
          style: t.text.caption.copyWith(color: tone.warningFg),
        ),
      ],

      if (creada.ofertasProducto.isNotEmpty) ...[
        SizedBox(height: t.space.md),
        const SSectionLabel(text: 'Ofertas de los extras'),
        SizedBox(height: t.space.xs),
        SCard.outlined(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final o in creada.ofertasProducto)
                Padding(
                  padding: EdgeInsets.only(bottom: t.space.xxs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.bodySmall.copyWith(color: tone.fg),
                        ),
                      ),
                      SizedBox(width: t.space.xs),
                      Text(
                        folioDeOferta(o.idOferta, esProducto: true),
                        style: t.text.caption.copyWith(color: tone.fgMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],

      // Los avisos vienen redactados por el servidor: se pintan TAL CUAL.
      if (creada.avisos.isNotEmpty) ...[
        SizedBox(height: t.space.md),
        for (final aviso in creada.avisos)
          Padding(
            padding: EdgeInsets.only(bottom: t.space.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: _iconoFila,
                  color: tone.warningFg,
                ),
                SizedBox(width: t.space.xs),
                Expanded(
                  child: Text(
                    aviso,
                    style: t.text.caption.copyWith(color: tone.warningFg),
                  ),
                ),
              ],
            ),
          ),
      ],

      SizedBox(height: t.space.md),
      if (creada.tieneLink) ...[
        BotonWhatsApp(onPressed: () => _compartirPorWhatsApp(context, creada)),
        SizedBox(height: t.space.xs),
        SButton.secondary(
          label: 'Copiar el link del cliente',
          icon: Icons.copy_outlined,
          onPressed: () => copiarLink(context, creada.link!.urlCompartible),
        ),
        SizedBox(height: t.space.xs),
        SButton.secondary(
          label: 'Más formas de compartirla',
          icon: Icons.ios_share_outlined,
          onPressed: () => _abrirCompartir(context, creada),
        ),
      ] else
        Text(
          'Esta oferta salió sin link del cliente. Ábrela en tu pipeline para '
          'emitirlo cuando lo necesites.',
          style: t.text.bodySmall.copyWith(color: tone.fgMuted),
        ),
      if (creada.emailEnviado) ...[
        SizedBox(height: t.space.xs),
        Text(
          'El correo con la oferta ya salió.',
          style: t.text.caption.copyWith(color: tone.positive),
        ),
      ],
    ];
  }

  // ── Acciones ──────────────────────────────────────────────────────────────

  void _cambiarOrigen(_OrigenProspecto origen) => setState(() {
    _origen = origen;
    _error = null;
    _faltaCapacitacion = false;
  });

  /// Repinta para que los errores de campo y el botón sigan al texto.
  void _revalidar() {
    setState(() {
      _error = null;
      _faltaCapacitacion = false;
    });
  }

  /// Alta en la cartera, encima de esta hoja. Al cerrarse se recarga la cartera
  /// y el nuevo prospecto aparece en el selector sin salir de la configuración.
  Future<void> _altaEnCartera() async {
    await editarProspecto(context);
    if (!mounted) return;
    ref.invalidate(carteraProspectosProvider);
  }

  Future<void> _generar() async {
    setState(() {
      _creando = true;
      _error = null;
      _faltaCapacitacion = false;
    });
    final deCartera = _origen == _OrigenProspecto.cartera;
    try {
      final creada = await ref
          .read(pipelineAccionesProvider)
          .crearOferta(
            idPropiedad: widget.unidad.idPropiedad,
            idEsquemaPago: widget.unidad.idEsquemaPago,
            // Excluyentes: con los dos el servidor responde `lead_conflict`.
            idPersonaLead: deCartera ? _elegido?.idPersona : null,
            prospecto: deCartera
                ? null
                : ProspectoNuevo(
                    nombreCompleto: _nombreCapturado,
                    email: _email.text.trim(),
                    telefono: _telefono.text.trim(),
                    clavePaisTelefono: _lada,
                    tipoPersona: _tipoPersona,
                    rfc: _rfc.text,
                    curp: _curp.text,
                  ),
            // Sin permiso van apagadas de todos modos: el servidor no valida
            // `generar_oferta_digital`, asi que el candado del cliente es el
            // unico que hay y no puede depender solo de esconder la casilla.
            crearLink: _puedeOfertaDigital && _crearLink,
            enviarEmail: _puedeOfertaDigital && _enviarEmail,
            adjuntarPdf: _puedeOfertaDigital && _adjuntarPdf,
          );
      if (!mounted) return;
      setState(() {
        _creando = false;
        _creada = creada;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creando = false;
        _error = mensajeDeErrorNuevaOferta(e);
        _faltaCapacitacion = esCapacitacionPendiente(e);
      });
    }
  }

  /// Nombre, teléfono y correo del prospecto de la oferta, para compartirla. Del
  /// elegido salen de la cartera; del capturado, de lo que se acaba de escribir.
  ({String nombre, String? telefono, String clavePais, String? email})
  get _contacto {
    if (_origen == _OrigenProspecto.captura) {
      return (
        nombre: _nombreCapturado,
        telefono: _telefono.text.trim(),
        clavePais: _lada,
        email: _email.text.trim(),
      );
    }
    final ficha = _fichaElegida;
    return (
      nombre: _elegido?.nombre ?? '',
      telefono: ficha?.telefono,
      clavePais: ficha?.clavePaisTelefono ?? 'MX',
      email: ficha?.email,
    );
  }

  String _mensaje(OfertaCreada creada) => mensajeDeOferta(
    url: creada.link?.urlCompartible ?? '',
    nombreLead: _contacto.nombre,
    unidad: widget.unidad.etiqueta,
    proyecto: widget.unidad.desarrollo,
  );

  Future<void> _compartirPorWhatsApp(
    BuildContext context,
    OfertaCreada creada,
  ) => compartirPorWhatsApp(
    context,
    mensaje: _mensaje(creada),
    telefono: _contacto.telefono,
    clavePais: _contacto.clavePais,
  );

  Future<void> _abrirCompartir(BuildContext context, OfertaCreada creada) {
    final contacto = _contacto;
    return mostrarCompartirOferta(
      context,
      idOferta: creada.idOferta,
      titulo: _tituloUnidad,
      urlCliente: creada.link?.url ?? '',
      urlPreview: creada.link?.urlPreview ?? '',
      mensaje: _mensaje(creada),
      telefono: contacto.telefono,
      clavePais: contacto.clavePais,
      email: contacto.email,
    );
  }
}

/// Casilla de una opción de entrega, con la misma piel que la hoja de compartir.
class _Casilla extends StatelessWidget {
  final String etiqueta;
  final bool valor;
  final bool habilitado;
  final ValueChanged<bool> onCambio;

  const _Casilla({
    required this.etiqueta,
    required this.valor,
    required this.habilitado,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Row(
      children: [
        Checkbox(
          value: valor,
          onChanged: habilitado ? (v) => onCambio(v ?? false) : null,
        ),
        Expanded(
          child: Text(
            etiqueta,
            style: t.text.bodySmall.copyWith(color: t.color.fg),
          ),
        ),
      ],
    );
  }
}

/// Total de la unidad con sus extras. Es de LECTURA: la oferta no guarda montos
/// y ninguno de estos números viaja al servidor.
class _Total extends StatelessWidget {
  final double precio;
  final bool conExtras;

  const _Total({required this.precio, required this.conExtras});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return Container(
      padding: EdgeInsets.all(t.space.md),
      decoration: BoxDecoration(
        color: tone.primarySoft,
        borderRadius: t.radius.lgBorder,
        border: Border.all(color: tone.primaryBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              conExtras ? 'TOTAL CON EXTRAS' : 'PRECIO DE LISTA',
              style: t.text.overline.copyWith(color: tone.primaryHover),
            ),
          ),
          SizedBox(width: t.space.xs),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatMXN(precio),
                style: t.text.h3.copyWith(color: tone.primaryHover),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icono de una fila de detalle (extra, aviso, plan).
const double _iconoFila = 14;

/// Palomita del resultado: acompaña al folio, que es lo que se lee.
const double _iconoResultado = 20;

/// Ancho del selector de país del teléfono.
const double _anchoLada = 92;

/// Alto de la silueta del selector de prospecto.
const double _altoSelector = 44;
