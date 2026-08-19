import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_agente_app/features/agente/perfil/adapters/perfil_agente_adapter.dart';
import 'package:sozu_agente_app/features/agente/perfil/ports/perfil_agente_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';
import 'package:sozu_agente_app/shared/providers/shared_providers.dart';

/// Campos del perfil que la inmobiliaria puede administrar en lugar del agente.
/// Son las claves que usa la sesión en `restricciones.read_only`.
abstract final class CampoRestringido {
  static const fiscal = 'fiscal';
  static const banco = 'banco';
  static const constancia = 'csf';
  static const carta = 'carta';
}

/// Puerto del perfil del agente. Se reconstruye al cambiar la sesión o el agente
/// impersonado, y eso invalida en cascada los providers de datos: sin esto un
/// admin vería el perfil del agente anterior.
final perfilAgentePortProvider = Provider<PerfilAgentePort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return PerfilAgenteAdapter(impersonate: imp.active ? imp.personaId : null);
});

/// Perfil completo del agente. Un endpoint, un provider: el refresco es
/// `ref.invalidate(perfilAgenteProvider)`.
final perfilAgenteProvider = FutureProvider<PerfilAgente>(
  (ref) => ref.watch(perfilAgentePortProvider).cargar(),
);

/// Catálogos del domicilio. La familia es el estado elegido: sin él no llegan
/// municipios (la tabla completa son miles de filas).
final catalogosDeDomicilioProvider =
    FutureProvider.family<CatalogosDeDomicilio, int?>(
      (ref, idEstado) => ref
          .watch(perfilAgentePortProvider)
          .catalogosDeDomicilio(idEstado: idEstado),
    );

/// Por qué un campo del perfil está en solo lectura, o null si el agente sí lo
/// administra.
///
/// Se resuelve PRIMERO contra la sesión, que ya está en memoria cuando la
/// pantalla se pinta: así los campos del agente dependiente salen grises **con
/// su explicación desde el primer frame**. Un campo gris sin nota se reporta como
/// bug, y peor todavía es pintarlo editable y volverlo gris medio segundo
/// después, cuando el usuario ya empezó a escribir.
final notaSoloLecturaProvider = Provider.family<String?, String>((ref, campo) {
  final deLaSesion = ref.watch(restriccionesProvider).nota(campo);
  if (deLaSesion != null && deLaSesion.isNotEmpty) return deLaSesion;

  // Respaldo: el propio perfil también dice si fiscal va en solo lectura, por si
  // la sesión se sirvió antes de que el agente quedara ligado a la inmobiliaria.
  final perfil = ref.watch(perfilAgenteProvider).valueOrNull;
  if (perfil == null) return null;
  final aplica = switch (campo) {
    CampoRestringido.fiscal ||
    CampoRestringido.banco => perfil.fiscal.soloLectura,
    CampoRestringido.constancia => perfil.expediente.constanciaSoloLectura,
    _ => false,
  };
  if (!aplica) return null;
  return perfil.fiscal.nota ??
      (perfil.inmobiliaria != null
          ? 'La administra ${perfil.inmobiliaria}'
          : 'La administra tu inmobiliaria');
});

/// ¿El agente administra sus datos fiscales y su cuenta de dispersión?
final administraDatosDeCobroProvider = Provider<bool>((ref) {
  return ref.watch(notaSoloLecturaProvider(CampoRestringido.fiscal)) == null;
});

/// Estado de la firma de la Carta de comercialización, sincronizado contra el
/// proveedor de firma.
///
/// Va aparte de [perfilAgenteProvider] a propósito: la lectura del perfil NO
/// sale a la red con el proveedor (sería un viaje extra en cada entrada al
/// portal), así que el estado vivo solo se conoce pidiéndolo, y se pide cuando el
/// agente abre su expediente o vuelve de firmar.
final firmaDeCartaProvider = FutureProvider<FirmaDeCarta>(
  (ref) => ref.watch(perfilAgentePortProvider).consultarFirmaDeCarta(),
);

/// Pull-to-refresh de las pantallas del Perfil: vuelve a pedir el perfil (y la
/// firma de la carta, que vive fuera de él) y espera a que llegue.
///
/// El error NO se propaga: cada pantalla ya lo pinta con su `SErrorState`, y
/// dejarlo salir aquí solo deja el indicador de arrastre girando.
Future<void> refrescarPerfilDelAgente(WidgetRef ref) async {
  ref.invalidate(perfilAgenteProvider);
  ref.invalidate(firmaDeCartaProvider);
  try {
    await ref.read(perfilAgenteProvider.future);
  } catch (_) {
    // Ya lo reporta la pantalla.
  }
}
