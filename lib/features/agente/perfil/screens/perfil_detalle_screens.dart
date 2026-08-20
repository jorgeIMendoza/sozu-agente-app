import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/core/format.dart';
import 'package:sozu_agente_app/core/open_media.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/cuenta_de_dispersion_tarjeta.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_aviso.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_bloque_datos.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja_cuenta_bancaria.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja_fiscal.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja_identidad.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_subvista.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/mensajes_del_perfil.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Anuncia el resultado de una operación del perfil.
void _aviso(BuildContext context, String mensaje, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      duration: Duration(seconds: error ? 7 : 3),
    ),
  );
}

// ─── Identidad ──────────────────────────────────────────────────────────────

/// Identidad del agente: datos personales y domicilio particular.
///
/// Es la única sección del perfil que el agente captura completa a mano; la
/// fiscal viene de su Constancia y la de su cuenta la administra SOZU.
class PerfilPersonalScreen extends ConsumerWidget {
  const PerfilPersonalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPerfil = ref.watch(perfilAgenteProvider);
    final permisos = ref.watch(permisosVistaProvider(VistaAgente.perfil));

    return PerfilSubvista(
      titulo: 'Identidad',
      onRefrescar: () => refrescarPerfilDelAgente(ref),
      children: [
        asyncPerfil.when(
          loading: () => const PerfilSubvistaCargando(),
          error: (e, _) => SErrorState(
            title: tituloDeErrorDeCarga(e),
            message: mensajeDeErrorDeCarga(e),
            onRetry: () => ref.invalidate(perfilAgenteProvider),
          ),
          data: (perfil) {
            final i = perfil.identidad;
            final puedeEditar = permisos.actualizar && perfil.puedeEditar;
            final paso = perfil.activacion.paso('basic');

            Future<void> editar() async {
              final guardo = await mostrarHojaDeIdentidad(
                context,
                identidad: i,
              );
              if (guardo != true) return;
              ref.invalidate(perfilAgenteProvider);
              // El nombre del agente vive también en el encabezado del portal.
              ref.invalidate(sesionProvider);
              if (context.mounted) _aviso(context, 'Información actualizada');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Qué le falta exactamente para cerrar el paso. Sin esto el
                // agente ve "En proceso" y no sabe qué campo abrir.
                if (paso != null && paso.faltantes.isNotEmpty) ...[
                  _Faltantes(faltantes: paso.faltantes),
                  SizedBox(height: context.s.space.md),
                ],
                PerfilBloqueDatos(
                  titulo: 'Información personal',
                  accion: puedeEditar
                      ? SButton(
                          label: 'Editar',
                          icon: Icons.edit_outlined,
                          onPressed: editar,
                          variant: SButtonVariant.ghost,
                          size: SButtonSize.sm,
                          fullWidth: false,
                        )
                      : null,
                  filas: [
                    PerfilDato(
                      etiqueta: 'Correo · solo lectura',
                      valor: i.email,
                    ),
                    PerfilDato(etiqueta: 'Teléfono', valor: i.telefono),
                    PerfilDato(
                      etiqueta: 'Nombre completo',
                      valor: i.nombreLegal,
                    ),
                    PerfilDato(etiqueta: 'CURP', valor: i.curp),
                    PerfilDato(
                      etiqueta: 'Fecha de nacimiento',
                      valor: i.fechaNacimiento == null
                          ? null
                          : formatDate(i.fechaNacimiento),
                    ),
                    PerfilDato(etiqueta: 'Sexo', valor: i.sexoLegible),
                    PerfilDato(
                      etiqueta: 'Domicilio particular',
                      valor: i.domicilio.resumen,
                      ultima: true,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Lista de lo que le falta al agente para cerrar un paso de su activación.
class _Faltantes extends StatelessWidget {
  final List<String> faltantes;

  const _Faltantes({required this.faltantes});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pending_actions_outlined,
                size: 17,
                color: t.color.warningFg,
              ),
              SizedBox(width: t.space.xs),
              Text(
                'Te falta capturar',
                style: t.text.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: t.color.warningFg,
                ),
              ),
            ],
          ),
          SizedBox(height: t.space.xs),
          Wrap(
            spacing: t.space.xs,
            runSpacing: t.space.xs,
            children: [
              for (final f in faltantes)
                SBadge(label: f, tone: SBadgeTone.pending, size: SBadgeSize.sm),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Información fiscal ─────────────────────────────────────────────────────

/// Información fiscal del agente.
///
/// Se cierra por dos caminos que no compiten: el capturador
/// ([mostrarHojaDeFiscal], que escribe con `guardar_fiscal`) y la Constancia,
/// que el servidor lee y de la que extrae los mismos datos. El agente
/// dependiente no ve ninguno de los dos: esos datos los lleva su inmobiliaria.
class PerfilFiscalScreen extends ConsumerStatefulWidget {
  const PerfilFiscalScreen({super.key});

  @override
  ConsumerState<PerfilFiscalScreen> createState() => _PerfilFiscalScreenState();
}

class _PerfilFiscalScreenState extends ConsumerState<PerfilFiscalScreen> {
  bool _guardandoCfdi = false;

  Future<void> _guardarUsoCfdi(String? codigo) async {
    setState(() => _guardandoCfdi = true);
    try {
      await ref.read(perfilAgentePortProvider).guardarUsoCfdi(codigo);
      ref.invalidate(perfilAgenteProvider);
      if (mounted) _aviso(context, 'Uso del CFDI actualizado');
    } on ApiError catch (e) {
      if (mounted) _aviso(context, mensajeDeError(e), error: true);
    } catch (_) {
      if (mounted) {
        _aviso(context, 'No se pudo guardar el uso del CFDI.', error: true);
      }
    } finally {
      if (mounted) setState(() => _guardandoCfdi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final asyncPerfil = ref.watch(perfilAgenteProvider);
    final permisos = ref.watch(permisosVistaProvider(VistaAgente.perfil));
    // Se resuelve ANTES de que llegue el perfil: los campos del agente
    // dependiente salen en solo lectura con su nota desde el primer frame.
    final nota = ref.watch(notaSoloLecturaProvider(CampoRestringido.fiscal));
    final identidad = ref.watch(identidadAgenteProvider);

    return PerfilSubvista(
      titulo: 'Información fiscal',
      onRefrescar: () => refrescarPerfilDelAgente(ref),
      children: [
        if (nota != null) ...[
          PerfilAvisoSoloLectura.una(
            nota: nota,
            inmobiliaria: identidad?.inmobiliariaNombre,
          ),
          SizedBox(height: t.space.md),
        ],
        asyncPerfil.when(
          loading: () => const PerfilSubvistaCargando(),
          error: (e, _) => SErrorState(
            title: tituloDeErrorDeCarga(e),
            message: mensajeDeErrorDeCarga(e),
            onRetry: () => ref.invalidate(perfilAgenteProvider),
          ),
          data: (perfil) {
            final f = perfil.fiscal;
            final soloLectura = nota != null || f.soloLectura;
            final puedeEditarCfdi =
                permisos.actualizar && !soloLectura && perfil.puedeEditar;
            final constancia = perfil.expediente.documento('csf');

            Future<void> editarFiscal() async {
              final guardo = await mostrarHojaDeFiscal(
                context,
                fiscal: f,
                catalogos: perfil.catalogos,
                domicilioParticular: perfil.identidad.domicilio,
              );
              if (guardo != true) return;
              // El avance vive en DOS lados: el perfil y el onboarding de la
              // sesión, que es el que decide si ya puede ver sus comisiones.
              // Sin los dos, el agente cierra su paso fiscal y el aviso sigue
              // diciéndole que le falta.
              ref.invalidate(perfilAgenteProvider);
              ref.invalidate(sesionProvider);
              if (context.mounted) {
                _aviso(context, 'Información fiscal actualizada');
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PerfilBloqueDatos(
                  titulo: 'Uso del CFDI',
                  filas: const [],
                  encabezado: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SSelectField<String>(
                        hint: 'Selecciona…',
                        value: f.usoCfdi,
                        opciones: [
                          for (final u in perfil.catalogos.usosCfdi)
                            (value: u.valor, label: u.etiqueta),
                        ],
                        onChanged: puedeEditarCfdi && !_guardandoCfdi
                            ? _guardarUsoCfdi
                            : null,
                      ),
                      if (_guardandoCfdi) ...[
                        SizedBox(height: t.space.xs),
                        Text(
                          'Guardando…',
                          style: t.text.overline.copyWith(
                            color: t.color.fgSubtle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  pie: soloLectura
                      ? 'Tu inmobiliaria emite los CFDI de comisiones a SOZU '
                            'con estos datos fiscales.'
                      : 'Como emites CFDI de comisiones a SOZU, tu RFC, '
                            'régimen y CP fiscal deben coincidir con el SAT '
                            '(CFDI 4.0).',
                ),
                SizedBox(height: t.space.md),
                PerfilBloqueDatos(
                  titulo: 'Información fiscal',
                  // Oculto (no deshabilitado) cuando la lleva la inmobiliaria:
                  // el backend responde `forbidden_field` y ofrecer el botón
                  // solo lleva al agente a un error que no puede resolver.
                  accion: puedeEditarCfdi
                      ? SButton(
                          label: 'Editar',
                          icon: Icons.edit_outlined,
                          onPressed: editarFiscal,
                          variant: SButtonVariant.ghost,
                          size: SButtonSize.sm,
                          fullWidth: false,
                        )
                      : null,
                  filas: [
                    PerfilDato(
                      etiqueta: 'Razón social / Nombre',
                      valor: f.nombreLegal,
                    ),
                    PerfilDato(etiqueta: 'RFC', valor: f.rfc),
                    PerfilDato(
                      etiqueta: 'Régimen fiscal',
                      valor: f.regimenLegible,
                    ),
                    PerfilDato(
                      etiqueta: 'Uso del CFDI',
                      valor: f.usoCfdiLegible,
                    ),
                    PerfilDato(
                      etiqueta: 'Calle y número',
                      valor: [
                        f.domicilio.calle,
                        f.domicilio.numExt,
                      ].where((v) => (v ?? '').isNotEmpty).join(' '),
                    ),
                    PerfilDato(etiqueta: 'Colonia', valor: f.domicilio.colonia),
                    PerfilDato(
                      etiqueta: 'Código postal',
                      valor: f.domicilio.codigoPostal,
                      ultima: true,
                    ),
                  ],
                ),
                SizedBox(height: t.space.md),
                // El único camino para escribir estos datos.
                if (!soloLectura)
                  SCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                              color: t.color.primary,
                            ),
                            SizedBox(width: t.space.xs),
                            Expanded(
                              child: Text(
                                'Tu Constancia respalda estos datos',
                                style: t.text.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: t.color.fg,
                                ),
                              ),
                            ),
                            if (constancia != null)
                              SBadge(
                                label: constancia.estado.etiqueta,
                                tone:
                                    constancia.estado ==
                                        EstadoDocumento.validado
                                    ? SBadgeTone.positive
                                    : SBadgeTone.pending,
                                size: SBadgeSize.sm,
                              ),
                          ],
                        ),
                        SizedBox(height: t.space.xs),
                        Text(
                          'Al entregar el PDF original del SAT lo leemos por '
                          'ti: si está vigente, tu Constancia queda validada y '
                          'de ahí salen tu RFC, tu régimen y tu domicilio '
                          'fiscal. Así lo que facturas coincide con lo que '
                          'tiene el SAT.',
                          style: t.text.caption.copyWith(
                            color: t.color.fgMuted,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: t.space.sm),
                        SButton(
                          label: constancia?.tieneArchivo == true
                              ? 'Actualizar mi Constancia'
                              : 'Entregar mi Constancia',
                          icon: Icons.upload_outlined,
                          onPressed: () => context.push('/perfil/expediente'),
                          variant: SButtonVariant.secondary,
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─── Cuentas de dispersión ──────────────────────────────────────────────────

/// Cuentas a las que SOZU le dispersa las comisiones al agente.
class PerfilCuentasScreen extends ConsumerWidget {
  const PerfilCuentasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final asyncPerfil = ref.watch(perfilAgenteProvider);
    final permisos = ref.watch(permisosVistaProvider(VistaAgente.perfil));
    final nota = ref.watch(notaSoloLecturaProvider(CampoRestringido.banco));
    final identidad = ref.watch(identidadAgenteProvider);
    final perfil = asyncPerfil.valueOrNull;

    final puedeEditar =
        nota == null && permisos.actualizar && (perfil?.puedeEditar ?? false);

    Future<void> alta() async {
      final guardo = await mostrarHojaDeCuentaBancaria(
        context,
        bancos: perfil?.catalogos.bancos ?? const [],
        nombreDelAgente: perfil?.identidad.nombreLegal,
      );
      if (guardo != true) return;
      ref.invalidate(perfilAgenteProvider);
      if (context.mounted) {
        _aviso(
          context,
          'Cuenta registrada. Queda pendiente de activación hasta que la '
          'validemos.',
        );
      }
    }

    Future<void> editar(CuentaDeDispersion cuenta) async {
      final guardo = await mostrarHojaDeCuentaBancaria(
        context,
        bancos: perfil?.catalogos.bancos ?? const [],
        cuenta: cuenta,
        nombreDelAgente: perfil?.identidad.nombreLegal,
      );
      if (guardo != true) return;
      ref.invalidate(perfilAgenteProvider);
      if (context.mounted) _aviso(context, 'Cuenta bancaria actualizada.');
    }

    Future<void> borrar(CuentaDeDispersion cuenta) async {
      final ok = await showSConfirm(
        context,
        titulo: '¿Eliminar esta cuenta?',
        mensaje:
            'Dejaremos de considerar ${cuenta.banco} '
            '${cuenta.numeroEnmascarado} para dispersarte.',
        puntos: const [
          'Podrás registrar otra cuando quieras.',
          'Si es la única, no podremos pagarte hasta que registres otra.',
        ],
        etiquetaAceptar: 'Eliminar cuenta',
        tono: SConfirmTone.warning,
      );
      if (ok != true) return;
      try {
        await ref
            .read(perfilAgentePortProvider)
            .borrarCuentaBancaria(cuenta.id);
        ref.invalidate(perfilAgenteProvider);
        if (context.mounted) _aviso(context, 'Cuenta bancaria eliminada.');
      } on ApiError catch (e) {
        if (context.mounted) _aviso(context, mensajeDeError(e), error: true);
      } catch (_) {
        if (context.mounted) {
          _aviso(context, 'No se pudo eliminar la cuenta.', error: true);
        }
      }
    }

    return PerfilSubvista(
      titulo: 'Cuenta bancaria',
      onRefrescar: () => refrescarPerfilDelAgente(ref),
      accion: puedeEditar
          ? SButton(
              label: 'Agregar',
              icon: Icons.add,
              onPressed: alta,
              size: SButtonSize.sm,
              fullWidth: false,
            )
          : null,
      children: [
        if (nota != null) ...[
          PerfilAvisoSoloLectura.una(
            nota: nota,
            inmobiliaria: identidad?.inmobiliariaNombre,
          ),
          SizedBox(height: t.space.md),
        ],
        asyncPerfil.when(
          loading: () => const PerfilSubvistaCargando(),
          error: (e, _) => SErrorState(
            title: tituloDeErrorDeCarga(e),
            message: mensajeDeErrorDeCarga(e),
            onRetry: () => ref.invalidate(perfilAgenteProvider),
          ),
          data: (datos) {
            if (datos.cuentas.isEmpty) {
              return SEmptyState.card(
                icon: Icons.account_balance_outlined,
                title: nota != null
                    ? 'Tu inmobiliaria recibe las comisiones y define cómo te '
                          'paga: aquí no se registran cuentas.'
                    : 'Aún no tienes cuentas registradas.',
                message: nota != null
                    ? null
                    : 'Registra la cuenta a la que quieres que te dispersemos '
                          'tus comisiones.',
                action: puedeEditar
                    ? SButton(
                        label: 'Registrar cuenta',
                        icon: Icons.add,
                        onPressed: alta,
                        fullWidth: false,
                      )
                    : null,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final cuenta in datos.cuentas) ...[
                  CuentaDeDispersionTarjeta(
                    cuenta: cuenta,
                    onEditar: cuenta.editable && puedeEditar
                        ? () => editar(cuenta)
                        : null,
                    // Una cuenta ya validada es la que recibe el dinero: solo
                    // SOZU la da de baja, y el backend lo rechaza igual.
                    onBorrar: cuenta.editable && puedeEditar && !cuenta.validada
                        ? () => borrar(cuenta)
                        : null,
                    onVerEvidencia: (cuenta.evidenciaUrl ?? '').isEmpty
                        ? null
                        : () => openMedia(
                            context,
                            cuenta.evidenciaUrl,
                            titulo: 'Carátula · ${cuenta.banco}',
                          ),
                  ),
                  SizedBox(height: t.space.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
