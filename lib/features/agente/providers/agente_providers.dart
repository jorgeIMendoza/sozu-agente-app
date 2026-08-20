import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/home/providers/notificaciones_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';

/// Invalida los datos de las hojas del portal (p.ej. al cerrar sesion con
/// candado biometrico, donde la sesion sigue viva y nada se invalida solo).
void invalidateAllData(WidgetRef ref) {
  ref.invalidate(sesionProvider);
  ref.invalidate(notificacionesProvider);
  ref.invalidate(perfilAgenteProvider);
  ref.invalidate(firmaDeCartaProvider);
}
