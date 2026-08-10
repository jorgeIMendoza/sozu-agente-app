import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/agente/perfil/expediente/providers/expediente_providers.dart';
import 'package:sozu_agente_app/features/agente/home/providers/home_providers.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/profile_providers.dart';
import 'package:sozu_agente_app/features/agente/inventario/providers/properties_providers.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';

/// Invalida los datos de las hojas del portal (p.ej. al cerrar sesion con
/// candado biometrico, donde la sesion sigue viva y nada se invalida solo).
void invalidateAllData(WidgetRef ref) {
  ref.invalidate(sesionProvider);
  ref.invalidate(menuProvider);
  ref.invalidate(summaryProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(paymentsProvider);
  ref.invalidate(propertiesProvider);
  ref.invalidate(propertyDetailProvider);
  ref.invalidate(accountStatementProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(identityFileProvider);
}
