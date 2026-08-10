import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sozu_agente_app/core/open_media.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/carga_de_documento.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/documento_del_expediente_fila.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_aviso.dart';
import 'package:sozu_agente_app/features/agente/perfil/expediente/layouts/expediente_layout.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/mensajes_del_perfil.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Expediente del agente: los documentos que SOZU le pide, en qué estado está
/// cada uno y cómo los entrega.
class ExpedienteScreen extends ConsumerStatefulWidget {
  const ExpedienteScreen({super.key});

  @override
  ConsumerState<ExpedienteScreen> createState() => _ExpedienteScreenState();
}

class _ExpedienteScreenState extends ConsumerState<ExpedienteScreen> {
  /// Clave del documento cuya entrega está en curso.
  String? _enCurso;

  void _volver() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/perfil');
    }
  }

  void _aviso(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: Duration(seconds: error ? 7 : 4),
      ),
    );
  }

  Future<void> _entregar(
    DocumentoDelExpediente documento,
    List<OpcionDeCatalogo> regimenes,
  ) async {
    setState(() => _enCurso = documento.clave);
    try {
      final mensaje = await cargarDocumentoDelExpediente(
        context,
        ref,
        documento: documento,
        regimenes: regimenes,
      );
      if (mensaje != null) _aviso(mensaje);
    } finally {
      if (mounted) setState(() => _enCurso = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final asyncPerfil = ref.watch(perfilAgenteProvider);
    final permisos = ref.watch(permisosVistaProvider(VistaAgente.perfil));
    final notaConstancia = ref.watch(
      notaSoloLecturaProvider(CampoRestringido.constancia),
    );
    final identidad = ref.watch(identidadAgenteProvider);

    return ExpedienteLayout(
      titulo: 'Mis documentos',
      descripcion:
          'Cada documento que entregas alimenta tu perfil y sube tu porcentaje '
          'de activación. Súbelos completos y legibles: así los validamos a la '
          'primera.',
      onVolver: _volver,
      child: asyncPerfil.when(
        loading: () => Column(
          children: [
            const SSkeleton(height: 72),
            SizedBox(height: t.space.xs),
            const SSkeleton(height: 72),
            SizedBox(height: t.space.xs),
            const SSkeleton(height: 72),
          ],
        ),
        error: (e, _) => SErrorState(
          title: tituloDeErrorDeCarga(e),
          message: mensajeDeErrorDeCarga(e),
          onRetry: () => ref.invalidate(perfilAgenteProvider),
        ),
        data: (perfil) {
          final documentos = perfil.expediente.documentos;
          if (documentos.isEmpty) {
            return const SEmptyState.card(
              icon: Icons.folder_open_outlined,
              title: 'Todavía no hay documentos configurados en tu expediente.',
            );
          }

          final puedeEntregar = permisos.actualizar && perfil.puedeEditar;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sin identificación vigente no hay expediente que valga: se dice
              // arriba, antes de la lista.
              if (perfil.expediente.documento('identidad')?.estado ==
                  EstadoDocumento.pendiente) ...[
                _AvisoIdentidad(),
                SizedBox(height: t.space.md),
              ],
              if (notaConstancia != null) ...[
                PerfilAvisoSoloLectura(
                  nota: notaConstancia,
                  inmobiliaria: identidad?.inmobiliariaNombre,
                ),
                SizedBox(height: t.space.md),
              ],
              for (final documento in documentos) ...[
                DocumentoDelExpedienteFila(
                  documento: documento,
                  ocupado: _enCurso == documento.clave,
                  bloqueado: _enCurso != null || !puedeEntregar,
                  onEntregar: () =>
                      _entregar(documento, perfil.catalogos.regimenes),
                  onVer: documento.tieneArchivo
                      ? () => openMedia(
                          context,
                          documento.urlArchivo,
                          titulo: documento.nombre,
                        )
                      : null,
                ),
                SizedBox(height: t.space.xs),
              ],
              // La carta no se sube: se firma, y su estado vive fuera del perfil.
              if (perfil.expediente.documento('carta') != null) ...[
                SizedBox(height: t.space.sm),
                FirmaDeCartaPanel(habilitado: puedeEntregar),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AvisoIdentidad extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      padding: EdgeInsets.all(t.space.sm),
      decoration: BoxDecoration(
        color: t.color.warningSoft,
        border: Border.all(color: t.color.warning),
        borderRadius: t.radius.mdBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.badge_outlined, size: 17, color: t.color.warningFg),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(
              'Aún no has registrado tu identificación oficial. Sube tu INE '
              '(frente y reverso en un solo archivo) o tu pasaporte. El tipo se '
              'elige al adjuntarlo.',
              style: t.text.caption.copyWith(
                color: t.color.warningFg,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel de firma de la Carta de comercialización.
///
/// El estado real vive con el proveedor de firma y la lectura del perfil NO sale
/// a la red con él, así que se consulta aparte y se vuelve a consultar cuando el
/// agente regresa de firmar.
class FirmaDeCartaPanel extends ConsumerStatefulWidget {
  final bool habilitado;

  const FirmaDeCartaPanel({super.key, this.habilitado = true});

  @override
  ConsumerState<FirmaDeCartaPanel> createState() => _FirmaDeCartaPanelState();
}

class _FirmaDeCartaPanelState extends ConsumerState<FirmaDeCartaPanel> {
  bool _ocupado = false;
  bool _abrio = false;
  String? _error;

  void _aviso(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: Duration(seconds: error ? 7 : 4),
      ),
    );
  }

  /// Abre la liga de firma en el navegador del sistema.
  ///
  /// El portal web monta el widget del proveedor como componente web dentro de la
  /// página; eso no existe en Flutter, así que se abre la página del proveedor y
  /// al volver se vuelve a consultar el estado. No se usa una vista web embebida
  /// a propósito: la firma pide cámara y credenciales del proveedor, y en un
  /// WebView embebido eso se rompe en iOS y además esconde la barra de dirección
  /// (el agente no puede verificar en qué sitio está poniendo su firma).
  Future<void> _abrir(String url) async {
    final destino = Uri.tryParse(url);
    if (destino == null) {
      setState(() => _error = 'La liga de tu carta no es válida.');
      return;
    }
    final abrio = await launchUrl(destino, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!abrio) {
      setState(
        () => _error =
            'No pudimos abrir tu carta. Revisa que tengas un navegador '
            'disponible.',
      );
      return;
    }
    setState(() {
      _abrio = true;
      _error = null;
    });
  }

  Future<void> _firmar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      // La firma autógrafa (el trazo ilustrativo) todavía no se captura en el
      // app: se manda sin ella y el documento se firma digitalmente, que es la
      // firma con validez legal.
      final firma = await ref
          .read(perfilAgentePortProvider)
          .iniciarFirmaDeCarta();
      ref.invalidate(firmaDeCartaProvider);
      final url = firma.urlParaFirmar;
      if (url == null) {
        _aviso(
          'Tu carta se generó. Revisa tu correo para firmarla y vuelve a '
          'actualizar el estado.',
        );
        return;
      }
      await _abrir(url);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos preparar tu carta en este momento. Intenta más tarde.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _actualizar() async {
    setState(() => _ocupado = true);
    ref.invalidate(firmaDeCartaProvider);
    try {
      final firma = await ref.read(firmaDeCartaProvider.future);
      // El estado de la firma también mueve el estatus del documento 48 y con él
      // el porcentaje de activación.
      ref.invalidate(perfilAgenteProvider);
      if (mounted) _aviso('Estado de tu carta: ${firma.estado.etiqueta}');
    } on ApiError catch (e) {
      if (mounted) _aviso(mensajeDeError(e), error: true);
    } catch (_) {
      if (mounted) {
        _aviso('No pudimos consultar el estado de tu carta.', error: true);
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final asyncFirma = ref.watch(firmaDeCartaProvider);
    final firma = asyncFirma.valueOrNull ?? const FirmaDeCarta();
    final cargando = asyncFirma.isLoading && asyncFirma.valueOrNull == null;

    return SCard.outlined(
      padding: EdgeInsets.all(t.space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.draw_outlined, size: 18, color: t.color.primary),
              SizedBox(width: t.space.xs),
              Expanded(
                child: Text(
                  'Firma de tu Carta de comercialización',
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: t.color.fg,
                  ),
                ),
              ),
              if (cargando)
                const SSkeleton(width: 70, height: 18)
              else
                SBadge(
                  label: firma.estado.etiqueta,
                  tone: switch (firma.estado) {
                    EstadoFirmaCarta.completado => SBadgeTone.positive,
                    EstadoFirmaCarta.cancelado => SBadgeTone.negative,
                    EstadoFirmaCarta.sinFirmar => SBadgeTone.neutral,
                    _ => SBadgeTone.pending,
                  },
                  size: SBadgeSize.sm,
                ),
            ],
          ),
          SizedBox(height: t.space.xs),
          Text(
            firma.ayuda,
            style: t.text.caption.copyWith(
              color: t.color.fgMuted,
              height: 1.5,
            ),
          ),
          if (_abrio) ...[
            SizedBox(height: t.space.xs),
            Text(
              'Cuando termines de firmar, vuelve aquí y toca "Actualizar '
              'estado". Si no pudiste firmar en el navegador, también te '
              'mandamos la carta por correo.',
              style: t.text.overline.copyWith(
                color: t.color.fgSubtle,
                height: 1.5,
              ),
            ),
          ],
          if (_error != null) ...[
            SizedBox(height: t.space.xs),
            Text(
              _error!,
              style: t.text.caption.copyWith(color: t.color.danger),
            ),
          ],
          SizedBox(height: t.space.sm),
          Wrap(
            spacing: t.space.xs,
            runSpacing: t.space.xs,
            children: [
              if (firma.estado != EstadoFirmaCarta.completado &&
                  firma.estado != EstadoFirmaCarta.pendienteContraparte)
                SButton(
                  // Generar un segundo documento cuesta una verificación de
                  // identidad, así que cuando ya hay una firma abierta se
                  // continúa la que existe en vez de crear otra.
                  label: firma.estado.enCurso ? 'Continuar firma' : 'Firmar carta',
                  icon: Icons.draw_outlined,
                  onPressed: !widget.habilitado || _ocupado || cargando
                      ? null
                      : () {
                          final url = firma.urlParaFirmar;
                          if (firma.estado.enCurso && url != null) {
                            _abrir(url);
                          } else {
                            _firmar();
                          }
                        },
                  loading: _ocupado,
                  loadingLabel: 'Preparando…',
                  size: SButtonSize.md,
                  fullWidth: false,
                ),
              SButton(
                label: 'Actualizar estado',
                icon: Icons.refresh,
                onPressed: _ocupado ? null : _actualizar,
                variant: SButtonVariant.secondary,
                size: SButtonSize.md,
                fullWidth: false,
              ),
              if ((firma.pdfUrl ?? '').isNotEmpty)
                SButton(
                  label: 'Ver carta firmada',
                  icon: Icons.visibility_outlined,
                  onPressed: () => openMedia(
                    context,
                    firma.pdfUrl,
                    titulo: 'Carta de comercialización',
                  ),
                  variant: SButtonVariant.ghost,
                  size: SButtonSize.md,
                  fullWidth: false,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
