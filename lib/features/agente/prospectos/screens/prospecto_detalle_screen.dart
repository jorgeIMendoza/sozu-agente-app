import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/core/open_media.dart';
import 'package:sozu_agente_app/core/open_document.dart';
import 'package:sozu_agente_app/features/agente/citas/components/agendar_cita_hoja.dart';
import 'package:sozu_agente_app/features/agente/citas/services/seleccion_de_cita.dart';
import 'package:sozu_agente_app/features/agente/layouts/portal_top_bar.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/actividad_prospecto_lista.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/nota_hoja.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/prospecto_form_hoja.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/shared/providers/modo_presentacion_provider.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/prospectos_reglas.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/fx.dart';

/// Página con la que la web etiqueta los CTA de esta pantalla.
const _paginaCta = 'agent_prospecto_detalle';

/// Alto máximo de la línea de tiempo antes de darle su propio scroll, como en la
/// web. En teléfono NO se acota: un área con scroll dentro del scroll de la
/// página se convierte en una trampa para el dedo.
const double _altoMaxActividad = 440;

/// Ficha de un prospecto: quién es, en qué desarrollos está interesado, sus
/// ofertas digitales y toda su actividad.
class ProspectoDetalleScreen extends ConsumerStatefulWidget {
  final int idPersona;

  const ProspectoDetalleScreen({super.key, required this.idPersona});

  @override
  ConsumerState<ProspectoDetalleScreen> createState() =>
      _ProspectoDetalleScreenState();
}

class _ProspectoDetalleScreenState
    extends ConsumerState<ProspectoDetalleScreen> {
  int get idPersona => widget.idPersona;

  @override
  void initState() {
    super.initState();
    final telemetria = ref.read(telemetriaPortProvider);
    unawaited(
      telemetria.registrarVista(
        '/admin/agent/prospectos/$idPersona',
        datos: {'persona_id': idPersona},
      ),
    );
    unawaited(
      telemetria.registrarCta(
        pagina: _paginaCta,
        elementoId: 'page_view',
        tipo: 'page',
        metadata: {'persona_id': idPersona},
      ),
    );
  }

  void _aviso(BuildContext context, String mensaje) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(mensaje)));

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final detalle = ref.watch(detalleProspectoProvider(idPersona));
    final modo = ref.watch(modoPresentacionProvider);

    return Scaffold(
      appBar: const PortalTopBar(title: 'Prospecto'),
      body: SafeArea(
        child: ContentFrame(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(detalleProspectoProvider(idPersona));
              try {
                await ref.read(detalleProspectoProvider(idPersona).future);
              } catch (_) {
                // El estado de error lo pinta el cuerpo.
              }
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                t.space.md,
                t.space.md,
                t.space.md,
                t.space.xxl,
              ),
              // Con la ficha ya cargada se conserva en pantalla durante un
              // refresco: cambiarla por el esqueleto en cada guardado la hace
              // parpadear.
              children: [
                // En el marco ancho la barra de sección se colapsa y con ella
                // la flecha de regresar: sin esto no hay cómo volver a la
                // cartera más que por el menú.
                if (context.bp.hasSidebar)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SButton(
                      label: 'Volver a prospectos',
                      icon: Icons.arrow_back,
                      variant: SButtonVariant.ghost,
                      size: SButtonSize.sm,
                      fullWidth: false,
                      isNavigation: true,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                if (detalle.valueOrNull case final ficha?)
                  ..._contenido(context, ref, ficha, modo)
                else if (detalle.hasError)
                  SErrorState(
                    title: 'No pudimos abrir este prospecto',
                    message: mensajeDeErrorProspecto(
                      detalle.error,
                      porDefecto: 'Vuelve a intentarlo en un momento.',
                    ),
                    onRetry: () =>
                        ref.invalidate(detalleProspectoProvider(idPersona)),
                  )
                else
                  const _EsqueletoFicha(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contenido(
    BuildContext context,
    WidgetRef ref,
    DetalleProspecto d,
    ModoPresentacion modo,
  ) {
    final t = context.s;
    final tone = t.color;
    final p = d.persona;
    final tel = p.telefono == null || p.telefono!.isEmpty
        ? null
        : '${p.clavePaisTelefono == 'MX' ? '+52 ' : ''}${p.telefono}';

    Future<void> recargar() async {
      ref.invalidate(detalleProspectoProvider(idPersona));
    }

    return [
      SCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Las iniciales también se tapan: dos letras bastan para
                // reconocer a quién se está viendo en una pantalla compartida.
                SAvatar(
                  initials: modo.activo ? '••' : initials(p.nombre),
                  size: 52,
                ),
                SizedBox(width: t.space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modo.enmascarar(p.nombre),
                        style: t.text.h3.copyWith(color: tone.fg),
                      ),
                      SizedBox(height: t.space.xxs),
                      Wrap(
                        spacing: t.space.xs,
                        runSpacing: t.space.xxs,
                        children: [
                          // Un conteo no es un logro: va en el tono neutral que
                          // la insignia reserva para eso. La web lo pinta con el
                          // color de marca, que no es un tono de SBadge.
                          SBadge(
                            label: d.desarrollos.length == 1
                                ? '1 desarrollo'
                                : '${d.desarrollos.length} desarrollos',
                            size: SBadgeSize.sm,
                          ),
                          SBadge(
                            label: p.esPersonaMoral
                                ? 'Persona Moral'
                                : 'Persona Física',
                            size: SBadgeSize.sm,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: t.space.md),
            _Dato(etiqueta: 'Email', valor: modo.enmascararOpcional(p.email)),
            _Dato(etiqueta: 'Teléfono', valor: modo.enmascararOpcional(tel)),
            _Dato(etiqueta: 'RFC', valor: modo.enmascararOpcional(p.rfc)),
            _Dato(etiqueta: 'CURP', valor: modo.enmascararOpcional(p.curp)),
            SizedBox(height: t.space.md),
            Wrap(
              spacing: t.space.xs,
              runSpacing: t.space.xs,
              children: [
                SButton.secondary(
                  label: 'Editar',
                  icon: Icons.edit_outlined,
                  size: SButtonSize.sm,
                  fullWidth: false,
                  onPressed: () async {
                    final ok = await editarProspecto(
                      context,
                      persona: p,
                      desarrollos: d.desarrollos,
                    );
                    if (ok != true) return;
                    await recargar();
                    ref.invalidate(carteraProspectosProvider);
                  },
                ),
                SButton(
                  label: 'Agendar visita',
                  icon: Icons.event_available_outlined,
                  variant: SButtonVariant.ghost,
                  size: SButtonSize.sm,
                  fullWidth: false,
                  onPressed: () async {
                    final cita = await mostrarAgendarCita(
                      context,
                      prospecto: ProspectoParaCita(
                        idPersona: p.id,
                        nombre: p.nombre,
                        desarrollos: desarrollosDeFicha(d.desarrollos),
                      ),
                    );
                    if (cita == null || !context.mounted) return;
                    await recargar();
                    if (!context.mounted) return;
                    _aviso(context, cita.aviso ?? 'Cita agendada.');
                  },
                ),
                // La web solo lleva al inventario, sin arrastrar el prospecto:
                // la oferta se genera desde la unidad que se elija ahí.
                SButton(
                  label: 'Generar oferta',
                  icon: Icons.description_outlined,
                  variant: SButtonVariant.ghost,
                  size: SButtonSize.sm,
                  fullWidth: false,
                  onPressed: () => context.push('/inventario'),
                ),
              ],
            ),
            SizedBox(height: t.space.md),
            const SSectionLabel(text: 'Desarrollos de interés'),
            SizedBox(height: t.space.xs),
            if (d.desarrollos.isEmpty)
              Text(
                'Sin desarrollos. Agrégalos desde "Editar".',
                style: t.text.caption.copyWith(color: tone.fgSubtle),
              )
            else
              Wrap(
                spacing: t.space.xs,
                runSpacing: t.space.xs,
                children: [
                  for (final e in d.desarrollos)
                    SBadge(
                      label: e.nombre,
                      icon: Icons.check,
                      tone: SBadgeTone.positive,
                      size: SBadgeSize.sm,
                    ),
                ],
              ),
          ],
        ),
      ),
      SizedBox(height: t.space.md),

      if (d.ofertas.isNotEmpty) ...[
        SSectionLabel.heading(
          icon: Icons.description_outlined,
          text: 'Ofertas digitales',
        ),
        SizedBox(height: t.space.xs),
        for (final o in d.ofertas)
          Padding(
            padding: EdgeInsets.only(bottom: t.space.xs),
            child: _FilaOferta(oferta: o),
          ),
        SizedBox(height: t.space.md),
      ],

      SSectionLabel.heading(
        icon: Icons.forum_outlined,
        text: 'Actividad',
        trailing: SButton.secondary(
          label: 'Nota',
          icon: Icons.add,
          size: SButtonSize.sm,
          fullWidth: false,
          // Sin desarrollos no hay dónde colgar la nota: el servidor la
          // rechazaría con not_owner.
          onPressed: d.desarrollos.isEmpty
              ? null
              : () async {
                  final ok = await escribirNota(
                    context,
                    idPersona: idPersona,
                    idRelacion: d.desarrollos.first.idRelacion,
                  );
                  if (ok != true) return;
                  await recargar();
                },
        ),
      ),
      SizedBox(height: t.space.xs),
      SCard(
        child: _ConScrollPropio(
          // En pantalla ancha la actividad se acota y hace su propio scroll,
          // como la web; en teléfono crece con la página.
          altoMaximo: context.bp.isMobile ? null : _altoMaxActividad,
          child: ActividadProspectoLista(
            actividad: d.actividad,
            onAbrirNota: (nota) => _abrirNota(nota, recargar),
            onVerNota: (nota) => _abrirNota(nota, recargar, soloLectura: true),
            onVerAdjunto: (a) => openMedia(context, a.url, titulo: a.nombre),
          ),
        ),
      ),
    ];
  }

  /// Abre una nota propia. En [soloLectura] se ve completa y con su formato, y
  /// desde ahí se puede pasar a editarla.
  Future<void> _abrirNota(
    ActividadProspecto nota,
    Future<void> Function() recargar, {
    bool soloLectura = false,
  }) async {
    final ok = await abrirNota(
      context,
      idNota: nota.idNota!,
      texto: textoEditableDeNota(nota.detalle, nota.adjuntos),
      html: nota.html,
      adjuntos: nota.adjuntos,
      soloLectura: soloLectura,
    );
    if (ok != true) return;
    await recargar();
  }
}

/// Acota el alto de su hijo y le da scroll propio. Con [altoMaximo] en null se
/// pinta tal cual.
class _ConScrollPropio extends StatelessWidget {
  final double? altoMaximo;
  final Widget child;

  const _ConScrollPropio({required this.altoMaximo, required this.child});

  @override
  Widget build(BuildContext context) {
    if (altoMaximo == null) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: altoMaximo!),
      child: SingleChildScrollView(child: child),
    );
  }
}

/// Renglón etiqueta / valor de la ficha. "Sin datos" se pinta apagado para que
/// se distinga de un dato real.
class _Dato extends StatelessWidget {
  final String etiqueta;
  final String? valor;

  const _Dato({required this.etiqueta, this.valor});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final vacio = valor == null || valor!.isEmpty;
    return Container(
      padding: EdgeInsets.symmetric(vertical: t.space.xxs),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tone.borderSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: t.text.caption.copyWith(color: tone.fgSubtle),
            ),
          ),
          Text(
            vacio ? 'Sin datos' : valor!,
            style: t.text.caption.copyWith(
              fontWeight: vacio ? FontWeight.w400 : FontWeight.w700,
              color: vacio ? tone.fgSubtle : tone.fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Oferta digital con el enlace que se le manda al cliente.
class _FilaOferta extends StatelessWidget {
  final OfertaDigital oferta;

  const _FilaOferta({required this.oferta});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final nota = <String>[
      if (oferta.fecha != null) formatDateEsMX(oferta.fecha),
      if (oferta.tieneCuenta)
        'Ya no está disponible para venta'
      else if (!oferta.tieneLinkCliente)
        'Sin link de cliente',
    ].join(' · ');

    return SCard.outlined(
      padding: EdgeInsets.all(t.space.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oferta.unidad.isNotEmpty
                      ? 'Unidad ${oferta.unidad}'
                      : 'Oferta #${oferta.id}'
                            '${oferta.idProducto != null ? ' · producto' : ''}',
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone.fg,
                  ),
                ),
                if (nota.isNotEmpty)
                  Text(
                    nota,
                    style: t.text.caption.copyWith(color: tone.fgMuted),
                  ),
              ],
            ),
          ),
          SButton.secondary(
            label: 'Ver oferta',
            icon: Icons.open_in_new,
            size: SButtonSize.sm,
            fullWidth: false,
            isNavigation: true,
            onPressed: () => openDoc(context, oferta.urlCliente),
          ),
        ],
      ),
    );
  }
}

/// Carga de la ficha, con la misma silueta que el contenido real.
class _EsqueletoFicha extends StatelessWidget {
  const _EsqueletoFicha();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SSkeleton.circle(size: 52),
                  SizedBox(width: t.space.sm),
                  const Expanded(child: SSkeleton.text(lines: 2)),
                ],
              ),
              SizedBox(height: t.space.md),
              const SSkeleton.text(lines: 4),
            ],
          ),
        ),
        SizedBox(height: t.space.md),
        SCard(child: const SSkeleton.text(lines: 5)),
      ],
    );
  }
}
