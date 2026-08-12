import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/data/models.dart';
import 'package:sozu_agente_app/features/admin/adapters/admin_adapter.dart';
import 'package:sozu_agente_app/features/admin/ports/admin_port.dart';

/// Puerto de admin. El default es el adaptador real, la única composición
/// que existe en producción; los tests lo sobreescriben con un doble
/// (`overrideWithValue`), así que main.dart no necesita wiring propio.
final adminPortProvider = Provider<AdminPort>((ref) => AdminAdapter());

/// Agentes impersonables para el selector "Ver como agente". La lista llega
/// completa y el filtrado (rol + búsqueda) es local: son decenas de agentes,
/// no los miles de clientes del otro portal.
final adminAgentesProvider = FutureProvider<AdminAgentes>(
  (ref) => ref.watch(adminPortProvider).agentes(),
);
