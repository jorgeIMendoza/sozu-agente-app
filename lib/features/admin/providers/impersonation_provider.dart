import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_agente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_agente_app/features/auth/providers/auth_provider.dart';

/// Agente impersonado por un administrador de la app de agentes (solo web).
/// Estado in-memory: al recargar la página el guard regresa al selector.
/// Se limpia al cerrar sesión o cambiar de usuario para evitar que un target
/// residual afecte a otra sesión en la misma pestaña.
class ImpersonationController extends ChangeNotifier {
  StreamSubscription<AuthSession?>? _sub;
  String? _userId;

  int? personaId;
  String? nombre;
  String? email;

  bool get active => personaId != null;

  ImpersonationController(AuthPort port) {
    _userId = port.currentSession?.userId;
    _sub = port.sessionChanges.listen((session) {
      final nextId = session?.userId;
      if (nextId != _userId) {
        _userId = nextId;
        if (active) clear();
      }
    });
  }

  void select(int id, String name, String? email) {
    personaId = id;
    nombre = name;
    this.email = email;
    notifyListeners();
  }

  void clear() {
    personaId = null;
    nombre = null;
    email = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final impersonationProvider = ChangeNotifierProvider<ImpersonationController>((
  ref,
) {
  return ImpersonationController(ref.watch(authPortProvider));
});
