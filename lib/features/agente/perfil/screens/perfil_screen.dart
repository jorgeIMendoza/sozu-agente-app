import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_aviso.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_fila_seccion.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hero_expediente.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja_foto.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_hoja_password.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_preferencias.dart';
import 'package:sozu_agente_app/features/agente/perfil/components/perfil_tarjeta_agente.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/mensajes_del_perfil.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/telemetria_del_perfil.dart';
import 'package:sozu_agente_app/features/agente/providers/agente_providers.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_agente_app/shared/api_error.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';
import 'package:sozu_agente_app/ui/ui.dart';

/// Perfil del agente: quién es ante sus prospectos, cuánto le falta para estar
/// activo y desde dónde completa cada pieza.
///
/// Las secciones son rutas propias (`/perfil/cuenta`, `/perfil/expediente`…) y no
/// vistas internas como en el portal web: en el app el botón físico de "atrás"
/// tiene que funcionar, y con una sola ruta cerraría la pantalla completa.
class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  @override
  void initState() {
    super.initState();
    // Los dos eventos que manda la web al montar: la vista en la bitácora y el
    // `page_view` del tablero de CTA. Sin await: la telemetría no lanza.
    final telemetria = ref.read(telemetriaPortProvider);
    unawaited(telemetria.registrarVista(TelemetriaPerfil.ruta));
    unawaited(
      telemetria.registrarCta(
        pagina: TelemetriaPerfil.pagina,
        elementoId: TelemetriaPerfil.pageView,
        tipo: TelemetriaPerfil.tipoPagina,
      ),
    );
  }

  /// Manda un CTA con los identificadores de la web. Los emite la PANTALLA: las
  /// filas no conocen identificadores de tablero.
  ///
  /// En `metadata` solo la llave del paso; nada de nombre, correo, RFC ni CURP.
  void _cta(
    String elementoId, {
    String? etiqueta,
    Map<String, Object?> metadata = const {},
  }) {
    unawaited(
      ref
          .read(telemetriaPortProvider)
          .registrarCta(
            pagina: TelemetriaPerfil.pagina,
            elementoId: elementoId,
            etiqueta: etiqueta,
            metadata: metadata,
          ),
    );
  }

  /// Vuelve a pedir el perfil y la sesión: el porcentaje de activación y el
  /// encabezado del portal salen de la sesión, así que refrescar solo el perfil
  /// deja las dos cifras discrepando.
  Future<void> _refrescar() async {
    ref.invalidate(sesionProvider);
    await refrescarPerfilDelAgente(ref);
  }

  void _aviso(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: Duration(seconds: error ? 7 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final asyncPerfil = ref.watch(perfilAgenteProvider);
    final impersonando = ref.watch(impersonationProvider).active;

    // Los permisos salen de la sesión, que ya está en memoria: la pantalla se
    // pinta deshabilitada y luego se habilita, nunca al revés.
    final permisos = ref.watch(permisosVistaProvider(VistaAgente.perfil));

    // Mientras el perfil carga, la activación de la sesión ya trae el porcentaje:
    // así el panel no aparece en 0 % para después saltar al valor real.
    final onboarding = ref.watch(onboardingProvider);
    final encabezado = ref.watch(sesionProvider).valueOrNull?.header;

    final perfil = asyncPerfil.valueOrNull;
    final cargando = asyncPerfil.isLoading && perfil == null;

    final presentacion =
        perfil?.presentacion ??
        PresentacionAgente(
          nombre: encabezado?.nombre ?? 'Agente',
          fotoUrl: encabezado?.fotoPerfilUrl,
          frase: encabezado?.frasePerfil,
          rol: encabezado?.rol,
        );
    final activacion =
        perfil?.activacion ?? Activacion(porcentaje: onboarding.porcentaje);

    Future<void> cambiarFoto() async {
      final resultado = await mostrarHojaDeFoto(
        context,
        nombre: presentacion.nombre,
        fotoUrl: presentacion.fotoUrl,
      );
      if (resultado == null) return;
      ref.invalidate(perfilAgenteProvider);
      // El encabezado del portal también muestra la foto: se recarga la sesión.
      ref.invalidate(sesionProvider);
      _aviso(resultado);
    }

    Future<void> guardarPresentacion(String? frase) async {
      try {
        await ref.read(perfilAgentePortProvider).guardarPresentacion(frase);
        ref.invalidate(perfilAgenteProvider);
        ref.invalidate(sesionProvider);
        _aviso('Presentación guardada');
      } on ApiError catch (e) {
        _aviso(mensajeDeError(e), error: true);
      } catch (_) {
        _aviso('No se pudo guardar la presentación.', error: true);
      }
    }

    Future<void> cerrarSesion() async {
      final ok = await showSConfirm(
        context,
        titulo: 'Cerrar sesión',
        mensaje: '¿Seguro que quieres salir?',
        etiquetaAceptar: 'Cerrar sesión',
        tono: SConfirmTone.warning,
      );
      if (ok != true) return;
      // Con biometría habilitada solo bloquea (la huella re-entra sin
      // contraseña); sin biometría es un cierre de sesión real.
      await ref.read(authProvider).lockOrSignOut();
      ref.read(impersonationProvider).clear();
      invalidateAllData(ref);
      ref.invalidate(perfilAgenteProvider);
      if (context.mounted) context.go('/login');
    }

    /// Navega a una etapa de la activación dejando el mismo evento que la web.
    void irAEtapa(String stepId, String etiqueta, String ruta) {
      _cta(
        TelemetriaPerfil.etapaOnboarding,
        etiqueta: etiqueta,
        metadata: {'step_id': stepId},
      );
      context.push(ruta);
    }

    // ── Estado de cada sección ────────────────────────────────────────────
    final secciones = activacion.secciones;
    final notaFiscal = ref.watch(
      notaSoloLecturaProvider(CampoRestringido.fiscal),
    );
    final notaBanco = ref.watch(
      notaSoloLecturaProvider(CampoRestringido.banco),
    );

    final filas = <Widget>[
      if (perfil?.cuentaSozu != null)
        PerfilFilaSeccion(
          titulo: 'Datos de tu cuenta',
          descripcion: 'Rol, esquema de comisión, equipo y fecha de alta',
          soloLectura: true,
          onTap: () {
            _cta(TelemetriaPerfil.seccionDatosCuenta);
            context.push('/perfil/cuenta');
          },
        ),
      PerfilFilaSeccion(
        titulo: 'Documentos',
        descripcion: 'Sube y consulta todos tus documentos',
        estado: secciones.documentos,
        onTap: () {
          _cta(TelemetriaPerfil.seccionDocumentos);
          context.push('/perfil/expediente');
        },
      ),
      PerfilFilaSeccion(
        titulo: 'Identidad',
        descripcion: 'Datos personales, domicilio e identificación',
        estado: activacion.paso('basic')?.estado,
        onTap: () => irAEtapa('basic', 'Identidad', '/perfil/identidad'),
      ),
      PerfilFilaSeccion(
        titulo: 'Información fiscal',
        descripcion: notaFiscal != null
            ? 'La administra tu inmobiliaria · solo consulta'
            : 'RFC, régimen fiscal y constancia',
        estado: activacion.paso('fiscal')?.estado,
        soloLectura: notaFiscal != null,
        onTap: () => irAEtapa('fiscal', 'Información fiscal', '/perfil/fiscal'),
      ),
      PerfilFilaSeccion(
        titulo: 'Cuenta bancaria',
        descripcion: notaBanco != null
            ? 'La administra tu inmobiliaria · solo consulta'
            : 'Banco, CLABE y titular',
        estado: activacion.paso('bank-accounts')?.estado,
        soloLectura: notaBanco != null,
        onTap: () =>
            irAEtapa('bank-accounts', 'Cuenta bancaria', '/perfil/banco'),
      ),
      PerfilFilaSeccion(
        titulo: 'Capacitación',
        // La web dice "Agenda y completa tu capacitación", pero en el app la
        // cita todavía no se agenda: prometerlo aquí manda al agente a buscar
        // un botón que no existe.
        descripcion: 'Tu avance y tus citas agendadas',
        estado: activacion.paso('training')?.estado,
        onTap: () =>
            irAEtapa('training', 'Capacitación', '/perfil/capacitacion'),
      ),
      // Impersonando NO se ofrece: cambiaría la contraseña del agente que se
      // está viendo, no la de quien opera.
      if (!impersonando && (perfil?.puedeEditar ?? false))
        PerfilFilaSeccion(
          titulo: 'Seguridad',
          descripcion: 'Acceso y contraseña',
          onTap: () => mostrarHojaDePassword(context),
        ),
    ];

    // El aviso de cobros solo aplica al agente que administra sus propios datos
    // de cobro: al dependiente su inmobiliaria le paga y no hay nada que hacer.
    final faltanDatosDeCobro =
        perfil != null &&
        ref.watch(administraDatosDeCobroProvider) &&
        !activacion.puedeRecibirComisiones;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      // El scroll envuelve al limitador de ancho, NO al revés: al revés la
      // rueda del ratón solo mueve la columna central y en los laterales la
      // página no responde (ver AdminScrollArea).
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            t.space.md,
            t.space.sm,
            t.space.md,
            t.space.xxl,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PerfilTarjetaAgente(
                      presentacion: presentacion,
                      activacion: activacion,
                      cargando: cargando,
                      puedeEditar: perfil?.puedeEditar ?? false,
                      onCambiarFoto: cambiarFoto,
                      onGuardarPresentacion:
                          (perfil?.puedeEditar ?? false) && permisos.actualizar
                          ? guardarPresentacion
                          : null,
                    ),
                    if (faltanDatosDeCobro) ...[
                      SizedBox(height: t.space.sm),
                      PerfilAvisoCobros(
                        onCompletar: permisos.actualizar
                            ? () => context.push('/perfil/fiscal')
                            : null,
                      ),
                    ],
                    SizedBox(height: t.space.lg),
                    if (cargando)
                      const SSkeleton(height: 180)
                    else
                      PerfilHeroExpediente(
                        resumen: secciones,
                        onGestionarDocumentos: () {
                          _cta(TelemetriaPerfil.seccionDocumentos);
                          context.push('/perfil/expediente');
                        },
                      ),
                    SizedBox(height: t.space.lg),
                    const SSectionLabel(text: 'Secciones de tu perfil'),
                    SizedBox(height: t.space.xs),
                    for (var i = 0; i < filas.length; i++) ...[
                      if (i > 0) SizedBox(height: t.space.xs),
                      filas[i],
                    ],
                    if (asyncPerfil.hasError) ...[
                      SizedBox(height: t.space.md),
                      SErrorState(
                        title: tituloDeErrorDeCarga(asyncPerfil.error!),
                        message: mensajeDeErrorDeCarga(asyncPerfil.error!),
                        onRetry: () => ref.invalidate(perfilAgenteProvider),
                      ),
                    ],
                    SizedBox(height: t.space.lg),
                    const PerfilPreferencias(),
                    SizedBox(height: t.space.lg),
                    SButton(
                      label: 'Cerrar sesión',
                      icon: Icons.logout,
                      onPressed: cerrarSesion,
                      variant: SButtonVariant.danger,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
