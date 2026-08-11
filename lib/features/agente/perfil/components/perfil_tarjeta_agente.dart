import 'package:flutter/material.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/ui/ui.dart';
import 'package:sozu_agente_app/widgets/network_image.dart';

/// Tarjeta de identidad del Perfil: foto, nombre, insignia de verificación,
/// desarrollos asignados, presentación editable y el panel de Activación.
///
/// Tonta: recibe los datos y qué hacer. Quien la monta decide si el agente puede
/// editar (su propio perfil) o solo mirar (un admin viéndolo).
class PerfilTarjetaAgente extends StatelessWidget {
  final PresentacionAgente presentacion;
  final Activacion activacion;

  /// El agente puede cambiar su foto y su presentación.
  final bool puedeEditar;

  /// Todavía no llegó el perfil: el porcentaje se pinta como esqueleto en vez de
  /// mostrar un 0 % que después salta.
  final bool cargando;

  final VoidCallback onCambiarFoto;

  /// Guarda la presentación; null la deja en solo lectura.
  final Future<void> Function(String? frase)? onGuardarPresentacion;

  const PerfilTarjetaAgente({
    super.key,
    required this.presentacion,
    required this.activacion,
    required this.onCambiarFoto,
    this.puedeEditar = false,
    this.cargando = false,
    this.onGuardarPresentacion,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final anchoDeDosColumnas = context.bp.hasTwoColumns;

    final identidad = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Foto(
              url: presentacion.fotoUrl,
              nombre: presentacion.nombre,
              editable: puedeEditar,
              onTap: onCambiarFoto,
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presentacion.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: t.color.fg,
                    ),
                  ),
                  SizedBox(height: t.space.xxs),
                  Wrap(
                    spacing: t.space.xs,
                    runSpacing: t.space.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!cargando) InsigniaDeVerificacion(activacion: activacion),
                      if ((presentacion.rol ?? '').isNotEmpty)
                        Text(
                          presentacion.rol!,
                          style: t.text.caption.copyWith(
                            fontWeight: FontWeight.w500,
                            color: t.color.fgMuted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (presentacion.desarrollos.isNotEmpty) ...[
          SizedBox(height: t.space.md),
          _Desarrollos(nombres: presentacion.desarrollos),
        ],
      ],
    );

    final activacionPanel = PanelDeActivacion(
      activacion: activacion,
      cargando: cargando,
    );

    return SCard(
      padding: EdgeInsets.all(t.space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (anchoDeDosColumnas)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: identidad),
                SizedBox(width: t.space.lg),
                SizedBox(width: 220, child: activacionPanel),
              ],
            )
          else ...[
            identidad,
            SizedBox(height: t.space.md),
            activacionPanel,
          ],
          if (puedeEditar && onGuardarPresentacion != null ||
              (presentacion.frase ?? '').isNotEmpty) ...[
            SizedBox(height: t.space.md),
            Divider(height: 1, color: t.color.borderSoft),
            SizedBox(height: t.space.sm),
            EditorDePresentacion(
              frase: presentacion.frase,
              onGuardar: puedeEditar ? onGuardarPresentacion : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// Insignia "Verificado" / "No verificado" según la activación al 100 %.
class InsigniaDeVerificacion extends StatelessWidget {
  final Activacion activacion;

  const InsigniaDeVerificacion({super.key, required this.activacion});

  @override
  Widget build(BuildContext context) {
    if (activacion.verificado) {
      return const SBadge(
        label: 'Verificado',
        tone: SBadgeTone.positive,
        icon: Icons.check_circle_outline,
        size: SBadgeSize.sm,
      );
    }
    return const SBadge(
      label: 'No verificado',
      tone: SBadgeTone.negative,
      icon: Icons.error_outline,
      size: SBadgeSize.sm,
    );
  }
}

/// Panel de Activación: porcentaje, barra de avance y qué lo compone.
class PanelDeActivacion extends StatelessWidget {
  final Activacion activacion;
  final bool cargando;

  const PanelDeActivacion({
    super.key,
    required this.activacion,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVACIÓN',
              style: t.text.overline.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: t.color.fgSubtle,
              ),
            ),
            if (cargando)
              const SSkeleton(width: 34, height: 14)
            else
              Text(
                '${activacion.porcentaje}%',
                style: t.text.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: t.color.primaryHover,
                ),
              ),
          ],
        ),
        SizedBox(height: t.space.xs),
        SProgressBar(
          percent: activacion.porcentaje.toDouble(),
          thickness: SProgressBarThickness.thick,
          semanticsLabel: 'Avance de tu activación',
        ),
        SizedBox(height: t.space.xs),
        Text(
          'Se calcula sobre documentos validados y etapas completadas.',
          style: t.text.overline.copyWith(
            color: t.color.fgSubtle,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Foto de perfil con la insignia de cámara cuando se puede cambiar.
class _Foto extends StatelessWidget {
  final String? url;
  final String nombre;
  final bool editable;
  final VoidCallback onTap;

  const _Foto({
    required this.url,
    required this.nombre,
    required this.editable,
    required this.onTap,
  });

  static const double _diametro = 64;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final hayFoto = (url ?? '').isNotEmpty;

    final imagen = hayFoto
        ? ClipOval(
            child: SizedBox(
              width: _diametro,
              height: _diametro,
              child: SozuNetworkImage(
                url: url,
                placeholderIcon: Icons.person_outline,
              ),
            ),
          )
        : SAvatar(initials: initials(nombre), size: _diametro);

    final contenido = SizedBox(
      width: _diametro,
      height: _diametro,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: imagen),
          if (editable)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: tone.border),
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 13,
                  color: tone.fgMuted,
                ),
              ),
            ),
        ],
      ),
    );

    if (!editable) return contenido;
    return SPressable(
      onTap: onTap,
      semanticLabel: 'Cambiar foto de perfil',
      tooltip: 'Cambiar foto de perfil',
      borderRadius: BorderRadius.circular(_diametro),
      child: contenido,
    );
  }
}

/// Chips de los desarrollos asignados. Se muestran los primeros tres; el resto
/// se despliega con "+N" para que la tarjeta no crezca sin control en un agente
/// con veinte proyectos.
class _Desarrollos extends StatefulWidget {
  final List<String> nombres;

  const _Desarrollos({required this.nombres});

  @override
  State<_Desarrollos> createState() => _DesarrollosState();
}

class _DesarrollosState extends State<_Desarrollos> {
  static const int _visiblesPorDefecto = 3;
  bool _todos = false;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final total = widget.nombres.length;
    final visibles = _todos
        ? widget.nombres
        : widget.nombres.take(_visiblesPorDefecto).toList();
    final ocultos = total - visibles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DESARROLLOS ASIGNADOS',
          style: t.text.overline.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: t.color.fgSubtle,
          ),
        ),
        SizedBox(height: t.space.xs),
        Wrap(
          spacing: t.space.xs,
          runSpacing: t.space.xs,
          children: [
            for (final nombre in visibles)
              SBadge(
                label: nombre,
                tone: SBadgeTone.neutral,
                size: SBadgeSize.sm,
              ),
            if (ocultos > 0 || _todos)
              SChoiceChip(
                label: _todos ? 'Ver menos' : '+$ocultos',
                selected: false,
                size: SChoiceChipSize.sm,
                onSelected: (_) => setState(() => _todos = !_todos),
              ),
          ],
        ),
      ],
    );
  }
}

/// Presentación del agente: se lee entre comillas y se edita en el mismo lugar.
class EditorDePresentacion extends StatefulWidget {
  final String? frase;

  /// null la deja en solo lectura.
  final Future<void> Function(String? frase)? onGuardar;

  const EditorDePresentacion({super.key, this.frase, this.onGuardar});

  @override
  State<EditorDePresentacion> createState() => _EditorDePresentacionState();
}

class _EditorDePresentacionState extends State<EditorDePresentacion> {
  final _ctrl = TextEditingController();
  bool _editando = false;
  bool _guardando = false;
  int _largo = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _abrir() {
    _ctrl.text = widget.frase ?? '';
    setState(() {
      _largo = _ctrl.text.length;
      _editando = true;
    });
  }

  Future<void> _guardar() async {
    final onGuardar = widget.onGuardar;
    if (onGuardar == null) return;
    setState(() => _guardando = true);
    try {
      final texto = _ctrl.text.trim();
      await onGuardar(texto.isEmpty ? null : texto);
      if (mounted) setState(() => _editando = false);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final hayFrase = (widget.frase ?? '').trim().isNotEmpty;

    if (!_editando) {
      if (!hayFrase) {
        // Sin permiso y sin frase no hay nada que mostrar: el bloque se colapsa.
        if (widget.onGuardar == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: SButton(
            label: 'Agregar presentación',
            icon: Icons.add,
            onPressed: _abrir,
            variant: SButtonVariant.secondary,
            size: SButtonSize.sm,
            fullWidth: false,
          ),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '"${widget.frase!.trim()}"',
              style: t.text.caption.copyWith(
                fontStyle: FontStyle.italic,
                color: tone.fgMuted,
                height: 1.5,
              ),
            ),
          ),
          if (widget.onGuardar != null) ...[
            SizedBox(width: t.space.xs),
            SButton(
              label: 'Editar',
              icon: Icons.edit_outlined,
              onPressed: _abrir,
              variant: SButtonVariant.ghost,
              size: SButtonSize.sm,
              fullWidth: false,
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Así te presentas ante tus clientes. Aparece cuando compartes una '
          'propiedad con un prospecto.',
          style: t.text.overline.copyWith(color: tone.fgSubtle, height: 1.5),
        ),
        SizedBox(height: t.space.xs),
        STextField(
          controller: _ctrl,
          hint: 'Escribe tu presentación…',
          maxLines: 4,
          maxLength: PresentacionAgente.maximoFrase,
          size: STextFieldSize.md,
          autofocus: true,
          enabled: !_guardando,
          helper:
              'Habla de tu experiencia. Evita promesas de rendimiento o '
              'plusvalía.',
          onChanged: (v) => setState(() => _largo = v.length),
        ),
        SizedBox(height: t.space.xxs),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$_largo/${PresentacionAgente.maximoFrase}',
            style: t.text.overline.copyWith(color: tone.fgSubtle),
          ),
        ),
        SizedBox(height: t.space.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SButton(
              label: 'Cancelar',
              onPressed: _guardando
                  ? null
                  : () => setState(() => _editando = false),
              variant: SButtonVariant.secondary,
              size: SButtonSize.sm,
              fullWidth: false,
            ),
            SizedBox(width: t.space.xs),
            SButton(
              label: 'Guardar',
              onPressed: _guardar,
              loading: _guardando,
              loadingLabel: 'Guardando…',
              size: SButtonSize.sm,
              fullWidth: false,
            ),
          ],
        ),
      ],
    );
  }
}
