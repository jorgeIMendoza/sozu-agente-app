import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/core/open_media.dart';
import 'package:sozu_agente_app/core/open_document.dart';
import 'package:sozu_agente_app/features/agente/layouts/portal_top_bar.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/actividad_prospecto_lista.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/nota_hoja.dart';
import 'package:sozu_agente_app/features/agente/prospectos/components/prospecto_form_hoja.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/modo_presentacion_provider.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/prospectos_reglas.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/fx.dart';

/// Ficha de un prospecto: quién es, en qué desarrollos está interesado, sus
/// ofertas digitales y toda su actividad.
class ProspectoDetalleScreen extends ConsumerWidget {
  final int idPersona;

  const ProspectoDetalleScreen({super.key, required this.idPersona});

  void _aviso(BuildContext context, String mensaje) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(mensaje)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final detalle = ref.watch(detalleProspectoProvider(idPersona));
    final permisos = ref.watch(permisosVistaProvider(VistaAgente.prospectos));
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
                  ..._contenido(context, ref, ficha, permisos, modo)
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
    PermisosVista permisos,
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
                        modo.oculta(p.nombre),
                        style: t.text.h3.copyWith(color: tone.fg),
                      ),
                      SizedBox(height: t.space.xxs),
                      Wrap(
                        spacing: t.space.xs,
                        runSpacing: t.space.xxs,
                        children: [
                          SBadge(
                            label: d.desarrollos.length == 1
                                ? '1 desarrollo'
                                : '${d.desarrollos.length} desarrollos',
                            tone: SBadgeTone.positive,
                            size: SBadgeSize.sm,
                          ),
                          SBadge(
                            label: p.esPersonaMoral
                                ? 'Persona moral'
                                : 'Persona física',
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
            _Dato(etiqueta: 'Correo', valor: modo.oculta(p.email)),
            _Dato(etiqueta: 'Teléfono', valor: modo.oculta(tel)),
            _Dato(etiqueta: 'RFC', valor: modo.oculta(p.rfc)),
            _Dato(etiqueta: 'CURP', valor: modo.oculta(p.curp)),
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
                  // Sin permiso de actualizar el servidor lo rechaza, así que el
                  // botón se ve pero no se puede usar.
                  onPressed: permisos.actualizar
                      ? () async {
                          final ok = await editarProspecto(
                            context,
                            persona: p,
                            desarrollos: d.desarrollos,
                          );
                          if (ok != true) return;
                          await recargar();
                          ref.invalidate(carteraProspectosProvider);
                        }
                      : null,
                ),
                // Agendar visita y generar oferta viven en las features de citas
                // e inventario; aquí queda el punto de entrada para no perder el
                // recorrido de la web cuando aterricen.
                SButton(
                  label: 'Agendar visita',
                  icon: Icons.event_available_outlined,
                  variant: SButtonVariant.ghost,
                  size: SButtonSize.sm,
                  fullWidth: false,
                  onPressed: () =>
                      _aviso(context, 'Disponible en la siguiente tanda'),
                ),
                SButton(
                  label: 'Generar oferta',
                  icon: Icons.description_outlined,
                  variant: SButtonVariant.ghost,
                  size: SButtonSize.sm,
                  fullWidth: false,
                  onPressed: () =>
                      _aviso(context, 'Disponible en la siguiente tanda'),
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
        child: ActividadProspectoLista(
          actividad: d.actividad,
          onAbrirNota: (nota) async {
            final ok = await abrirNota(
              context,
              idNota: nota.idNota!,
              texto: textoEditableDeNota(nota.detalle, nota.adjuntos),
              adjuntos: nota.adjuntos,
            );
            if (ok != true) return;
            await recargar();
          },
          onVerAdjunto: (a) => openMedia(context, a.url, titulo: a.nombre),
        ),
      ),
    ];
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
        'Ya no está disponible'
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
