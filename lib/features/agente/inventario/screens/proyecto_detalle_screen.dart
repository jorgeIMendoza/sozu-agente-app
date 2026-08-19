import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/core/open_media.dart';
import 'package:sozu_agente_app/core/portal_theme.dart';
import 'package:sozu_agente_app/features/agente/citas/components/agendar_cita_hoja.dart';
import 'package:sozu_agente_app/features/agente/citas/services/seleccion_de_cita.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/avance_obra_card.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/compartir_desarrollo.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/galeria_imagenes.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/inventario_seccion.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/modelo_card.dart';
import 'package:sozu_agente_app/features/agente/inventario/components/ubicacion_card.dart';
import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';
import 'package:sozu_agente_app/features/agente/inventario/providers/inventario_providers.dart';
import 'package:sozu_agente_app/features/agente/inventario/screens/como_llegar_screen.dart';
import 'package:sozu_agente_app/features/agente/inventario/services/mensajes_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/fx.dart';
import 'package:sozu_agente_app/widgets/network_image.dart';

/// Ficha de un desarrollo: portada, disponibilidad, concepto, vistas, modelos,
/// amenidades, avance de obra, ubicación y material comercial. Es lo que el
/// agente le muestra al cliente, así que todo lo que se pinta viene del
/// servidor: aquí no se calcula ningún dato comercial.
class ProyectoDetalleScreen extends ConsumerWidget {
  final int idProyecto;

  const ProyectoDetalleScreen({super.key, required this.idProyecto});

  void _volver(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/inventario');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ficha = ref.watch(fichaDesarrolloProvider(idProyecto));
    final portal = isPortalMode(context);

    return Scaffold(
      backgroundColor: portal ? Colors.transparent : null,
      appBar: portal
          ? null
          : AppBar(
              title: const Text('Desarrollo'),
              leading: BackButton(onPressed: () => _volver(context)),
            ),
      body: SafeArea(
        top: !portal,
        child: ficha.when(
          loading: () => const _FichaCargando(),
          error: (e, _) => Padding(
            padding: EdgeInsets.all(context.s.space.md),
            child: SErrorState(
              title: 'No pudimos cargar el desarrollo',
              message: mensajeErrorInventario(e),
              onRetry: () =>
                  ref.invalidate(fichaDesarrolloProvider(idProyecto)),
            ),
          ),
          data: (f) => _Ficha(ficha: f, portal: portal),
        ),
      ),
    );
  }
}

/// Silueta de la ficha mientras carga: portada, cifras y dos secciones.
class _FichaCargando extends StatelessWidget {
  const _FichaCargando();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return ListView(
      padding: EdgeInsets.all(t.space.md),
      children: [
        const AspectRatio(
          aspectRatio: 16 / 9,
          child: SSkeleton(height: double.infinity),
        ),
        SizedBox(height: t.space.md),
        const SSkeleton(height: 64),
        SizedBox(height: t.space.md),
        const SSkeleton(height: 120),
        SizedBox(height: t.space.md),
        const SSkeleton(height: 200),
      ],
    );
  }
}

class _Ficha extends ConsumerWidget {
  final FichaDesarrollo ficha;
  final bool portal;

  const _Ficha({required this.ficha, required this.portal});

  /// Abre una liga externa (video de obra) y avisa si no se pudo.
  Future<void> _abrirExterno(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No pudimos abrir el video.')),
      );
    }
  }

  /// Abre el agendado con el desarrollo ya resuelto y avisa cómo quedó.
  Future<void> _agendarCita(
    BuildContext context,
    DesarrolloParaCita desarrollo,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final cita = await mostrarAgendarCita(context, desarrollo: desarrollo);
    if (cita == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(cita.aviso ?? 'Cita agendada.')),
    );
  }

  void _comoLlegar(
    BuildContext context, {
    required double lat,
    required double lng,
    required String nombre,
    String? direccion,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ComoLlegarScreen(
          destinoLat: lat,
          destinoLng: lng,
          nombre: nombre,
          direccion: direccion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final tone = t.color;
    final d = ficha.desarrollo;
    final galeria = ficha.galeria.map((g) => g.url).toList(growable: false);
    final vistas = ficha.vistas.map((v) => v.url).toList(growable: false);
    // Dos columnas donde caben (tablet y escritorio): los carruseles laterales
    // del portal web se resuelven aquí con rejilla, no con scroll horizontal.
    final columnas = context.responsive(mobile: 1, tablet: 2, desktop: 3);

    return ContentFrame(
      maxWidth: _anchoFicha,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          portal ? 0 : t.space.md,
          portal ? t.space.lg : t.space.xs,
          portal ? 0 : t.space.md,
          t.space.xl,
        ),
        children: [
          // ── Portada ──
          SCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CarruselImagenes(
                  imagenes: galeria,
                  aspecto: _aspectoPortada,
                  conFlechas: true,
                  onTocar: (i) => mostrarVisorImagenes(
                    context,
                    galeria,
                    indice: i,
                    titulo: d.nombre,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(t.space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.nombre, style: t.text.h2.copyWith(color: tone.fg)),
                      if ((d.direccion ?? '').isNotEmpty) ...[
                        SizedBox(height: t.space.xxs),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: _iconoChico,
                              color: tone.fgSubtle,
                            ),
                            SizedBox(width: t.space.xxs),
                            Expanded(
                              child: Text(
                                d.direccion!,
                                style: t.text.bodySmall.copyWith(
                                  color: tone.fgMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: t.space.sm),
                      Row(
                        children: [
                          Expanded(
                            child: InventarioDato(
                              etiqueta: 'Disponibles',
                              valor: '${ficha.disponibles}',
                              destacado: true,
                            ),
                          ),
                          Expanded(
                            child: InventarioDato(
                              etiqueta: 'Total unidades',
                              valor: '${ficha.totalUnidades}',
                            ),
                          ),
                          if (ficha.avance.porcentaje > 0)
                            Expanded(
                              child: InventarioDato(
                                etiqueta: 'Avance de obra',
                                valor: '${ficha.avance.porcentaje}%',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: t.space.md),

          // ── Acciones ──
          SCard(
            child: Column(
              children: [
                Text(
                  '¿Tu cliente está interesado en este desarrollo?',
                  textAlign: TextAlign.center,
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fg,
                  ),
                ),
                SizedBox(height: t.space.sm),
                SButton(
                  label: 'Ver inventario',
                  icon: Icons.apartment_outlined,
                  isNavigation: true,
                  onPressed: () =>
                      context.push('/inventario/unidades?proyecto=${d.id}'),
                ),
                SizedBox(height: t.space.xs),
                Row(
                  children: [
                    Expanded(
                      child: SButton.secondary(
                        label: 'Agendar cita',
                        icon: Icons.event_available_outlined,
                        // El desarrollo ya se sabe; el prospecto lo elige el
                        // agente en la hoja.
                        onPressed: () => _agendarCita(
                          context,
                          DesarrolloParaCita(id: d.id, nombre: d.nombre),
                        ),
                      ),
                    ),
                    SizedBox(width: t.space.xs),
                    Expanded(
                      child: SButton.secondary(
                        label: 'Compartir',
                        icon: Icons.share_outlined,
                        onPressed: () => mostrarCompartirDesarrollo(
                          context,
                          nombre: d.nombre,
                          urlPublica: d.urlPublica,
                          ubicacion: d.direccion,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Concepto ──
          if ((d.descripcion ?? '').isNotEmpty) ...[
            SizedBox(height: t.space.lg),
            InventarioSeccion(
              icon: Icons.description_outlined,
              titulo: 'Concepto',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.descripcion!,
                    style: t.text.bodySmall.copyWith(color: tone.fg),
                  ),
                  if (ficha.fechaEntrega != null) ...[
                    SizedBox(height: t.space.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: _iconoChico,
                          color: tone.fgMuted,
                        ),
                        SizedBox(width: t.space.xxs),
                        Expanded(
                          child: Text(
                            'Posible fecha de entrega: '
                            '${formatDateEsMX(ficha.fechaEntrega)}',
                            style: t.text.caption.copyWith(color: tone.fgMuted),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Fecha estimada y sujeta a cambios según el avance de '
                      'obra. No constituye una fecha de entrega contractual.',
                      style: t.text.caption.copyWith(color: tone.fgSubtle),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Vistas ──
          if (vistas.isNotEmpty) ...[
            SizedBox(height: t.space.lg),
            InventarioSeccion(
              icon: Icons.photo_library_outlined,
              titulo: 'Vistas',
              child: _TiraORejilla(
                columnas: columnas,
                children: [
                  for (var i = 0; i < ficha.vistas.length; i++)
                    _MiniaturaVista(
                      vista: ficha.vistas[i],
                      onTocar: () => mostrarVisorImagenes(
                        context,
                        vistas,
                        indice: i,
                        titulo: 'Vistas',
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ── Modelos ──
          if (ficha.modelos.isNotEmpty) ...[
            SizedBox(height: t.space.lg),
            InventarioSeccion(
              icon: Icons.layers_outlined,
              titulo: 'Modelos',
              trailing: SBadge(
                label: '${ficha.modelos.length}',
                size: SBadgeSize.sm,
              ),
              child: _TiraORejilla(
                columnas: columnas,
                children: [
                  for (final m in ficha.modelos)
                    ModeloCard(
                      modelo: m,
                      onVerGaleria: (i) => mostrarVisorImagenes(
                        context,
                        m.multimedia,
                        indice: i,
                        titulo: m.nombre,
                      ),
                      onVerPlano: m.planoUrl == null
                          ? null
                          : () => openMedia(
                              context,
                              m.planoUrl,
                              titulo: 'Plano ${m.nombre}',
                            ),
                      onVerUnidades: m.disponibles == 0
                          ? null
                          : () => context.push(
                              '/inventario/unidades'
                              '?proyecto=${d.id}&modelo=${m.id}',
                            ),
                    ),
                ],
              ),
            ),
          ],

          // ── Amenidades ──
          if (ficha.amenidades.isNotEmpty) ...[
            SizedBox(height: t.space.lg),
            InventarioSeccion(
              icon: Icons.auto_awesome_outlined,
              titulo: 'Amenidades',
              child: _Rejilla(
                columnas: columnas + 1,
                children: [
                  for (final a in ficha.amenidades) _AmenidadTile(amenidad: a),
                ],
              ),
            ),
          ],

          // ── Avance de obra ──
          if (!ficha.avance.vacio) ...[
            SizedBox(height: t.space.lg),
            InventarioSeccion(
              icon: Icons.engineering_outlined,
              titulo: 'Avance de obra',
              child: AvanceObraCard(
                avance: ficha.avance,
                fechaEntrega: ficha.fechaEntrega,
                onVerVideo: ficha.avance.video?.urlReproduccion == null
                    ? null
                    : () => _abrirExterno(
                        context,
                        ficha.avance.video!.urlReproduccion!,
                      ),
              ),
            ),
          ],

          // ── Ubicación ──
          if (d.tieneCoordenadas ||
              (d.direccion ?? '').isNotEmpty ||
              ficha.showroom != null) ...[
            SizedBox(height: t.space.lg),
            InventarioSeccion(
              icon: Icons.map_outlined,
              titulo: 'Ubicación',
              child: _Rejilla(
                columnas: context.responsive(mobile: 1, tablet: 2),
                children: [
                  UbicacionLugar(
                    titulo: 'El desarrollo',
                    direccion: d.direccion,
                    latitud: d.latitud,
                    longitud: d.longitud,
                    onComoLlegar: !d.tieneCoordenadas
                        ? null
                        : () => _comoLlegar(
                            context,
                            lat: d.latitud!,
                            lng: d.longitud!,
                            nombre: d.nombre,
                            direccion: d.direccion,
                          ),
                  ),
                  if (ficha.showroom != null)
                    UbicacionLugar(
                      titulo: 'Showroom de ventas',
                      direccion: ficha.showroom!.direccion,
                      horarios: ficha.showroom!.horarios,
                      latitud: ficha.showroom!.latitud,
                      longitud: ficha.showroom!.longitud,
                      onComoLlegar: !ficha.showroom!.tieneCoordenadas
                          ? null
                          : () => _comoLlegar(
                              context,
                              lat: ficha.showroom!.latitud!,
                              lng: ficha.showroom!.longitud!,
                              nombre:
                                  ficha.showroom!.nombre ??
                                  'Showroom de ventas',
                              direccion: ficha.showroom!.direccion,
                            ),
                    ),
                ],
              ),
            ),
          ],

          // ── Puntos de interés ──
          if (ficha.puntosInteres.isNotEmpty) ...[
            SizedBox(height: t.space.lg),
            InventarioSeccion(
              icon: Icons.explore_outlined,
              titulo: 'Puntos de interés',
              child: PuntosInteresLista(puntos: ficha.puntosInteres),
            ),
          ],

          // ── Material comercial ──
          if (!ficha.material.vacio) ...[
            SizedBox(height: t.space.lg),
            InventarioSeccion(
              icon: Icons.folder_open_outlined,
              titulo: 'Material comercial',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ficha.material.brochure?.url != null)
                    _FilaDocumento(
                      titulo: 'Brochure',
                      detalle: 'PDF · Presentación',
                      onAbrir: () => openMedia(
                        context,
                        ficha.material.brochure!.url,
                        titulo: 'Brochure ${d.nombre}',
                      ),
                    ),
                  if (ficha.material.fichaTecnica?.url != null) ...[
                    SizedBox(height: t.space.xs),
                    _FilaDocumento(
                      titulo: 'Ficha técnica',
                      detalle: 'PDF · Especificaciones',
                      onAbrir: () => openMedia(
                        context,
                        ficha.material.fichaTecnica!.url,
                        titulo: 'Ficha técnica ${d.nombre}',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tira horizontal en teléfono y rejilla donde hay ancho.
///
/// En teléfono, seis tarjetas de modelo apiladas son media pantalla de scroll
/// antes de llegar a amenidades: la tira los deja recorrer de lado, igual que el
/// carrusel del portal web. En tablet y escritorio la tira dejaría medio ancho
/// vacío, así que ahí manda la rejilla.
class _TiraORejilla extends StatelessWidget {
  final int columnas;
  final List<Widget> children;

  const _TiraORejilla({required this.columnas, required this.children});

  @override
  Widget build(BuildContext context) {
    if (columnas > 1) return _Rejilla(columnas: columnas, children: children);
    final gap = context.s.space.xs;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            SizedBox(width: _anchoTarjetaTira, child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// Rejilla de ancho fijo por columna.
class _Rejilla extends StatelessWidget {
  final int columnas;
  final List<Widget> children;

  const _Rejilla({required this.columnas, required this.children});

  @override
  Widget build(BuildContext context) {
    final gap = context.s.space.xs;
    if (columnas <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = (c.maxWidth - gap * (columnas - 1)) / columnas;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final w in children) SizedBox(width: ancho, child: w),
          ],
        );
      },
    );
  }
}

/// Miniatura de una vista comercial, con su nombre encima.
class _MiniaturaVista extends StatelessWidget {
  final VistaDesarrollo vista;
  final VoidCallback onTocar;

  const _MiniaturaVista({required this.vista, required this.onTocar});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return SPressable(
      onTap: onTocar,
      borderRadius: t.radius.lgBorder,
      semanticLabel: vista.nombre ?? 'Vista del desarrollo',
      child: SCard.outlined(
        padding: EdgeInsets.zero,
        clip: true,
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: SozuNetworkImage(url: vista.url),
            ),
            if (vista.nombre != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: t.color.overlay,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.space.xs,
                      vertical: t.space.xxs,
                    ),
                    child: Text(
                      vista.nombre!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Sobre el velo oscuro: blanco fijo, no un rol de tema.
                      style: t.text.caption.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Amenidad: foto con su nombre encima, o solo el nombre si no tiene foto.
class _AmenidadTile extends StatelessWidget {
  final Amenidad amenidad;

  const _AmenidadTile({required this.amenidad});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    if (amenidad.foto == null) {
      return SCard.outlined(
        child: Center(
          child: Text(
            amenidad.nombre,
            textAlign: TextAlign.center,
            style: t.text.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: tone.fg,
            ),
          ),
        ),
      );
    }
    return SCard.outlined(
      padding: EdgeInsets.zero,
      clip: true,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: SozuNetworkImage(url: amenidad.foto!),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: tone.overlay,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: t.space.xs,
                  vertical: t.space.xxs,
                ),
                child: Text(
                  amenidad.nombre,
                  maxLines: 2,
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    // Sobre el velo oscuro: blanco fijo, no un rol de tema.
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de un documento comercial: icono, nombre y detalle, abre el visor.
class _FilaDocumento extends StatelessWidget {
  final String titulo;
  final String detalle;
  final VoidCallback onAbrir;

  const _FilaDocumento({
    required this.titulo,
    required this.detalle,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return SPressable(
      onTap: onAbrir,
      borderRadius: t.radius.lgBorder,
      semanticLabel: 'Abrir $titulo',
      child: SCard.outlined(
        child: Row(
          children: [
            Container(
              width: _ladoIcono,
              height: _ladoIcono,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.primarySoftStrong,
                borderRadius: t.radius.mdBorder,
              ),
              child: Icon(
                Icons.picture_as_pdf_outlined,
                color: tone.primaryHover,
              ),
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: t.text.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                  Text(
                    detalle,
                    style: t.text.caption.copyWith(color: tone.fgMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: tone.fgSubtle),
          ],
        ),
      ),
    );
  }
}

/// Ancho de lectura de la ficha en el portal ancho.
const double _anchoFicha = 1100;

/// Ancho de una tarjeta en la tira horizontal de teléfono: cabe una completa y
/// se asoma la siguiente, que es lo que avisa de que hay más.
const double _anchoTarjetaTira = 250;
const double _aspectoPortada = 16 / 9;
const double _iconoChico = 14;
const double _ladoIcono = 40;
