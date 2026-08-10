import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/perfil/providers/perfil_agente_providers.dart';
import 'package:sozu_agente_app/features/agente/sesion/ports/sesion_port.dart';
import 'package:sozu_agente_app/features/agente/sesion/providers/sesion_providers.dart';

import '../agente_test_support.dart';
import 'fake_perfil_agente_port.dart';

/// El agente DEPENDIENTE de una inmobiliaria no administra su información fiscal
/// ni su cuenta de dispersión: el backend le responde `403 forbidden_field` si lo
/// intenta.
///
/// Estos tests fijan que la pantalla lo sepa ANTES de que el usuario toque nada, y
/// que además tenga la nota que lo explica: un campo gris sin explicación se
/// reporta como bug, y peor todavía es pintarlo editable y volverlo gris medio
/// segundo después, cuando el agente ya empezó a escribir.
void main() {
  SesionAgente sesionDependiente() => const SesionAgente(
    identidad: IdentidadAgente(
      email: 'alex@sozu.com',
      esDependiente: true,
      inmobiliariaNombre: 'Grupo Inmobiliario Norte',
    ),
    restricciones: Restricciones(
      rutasOcultas: [VistaAgente.comisiones],
      soloLectura: {
        'csf': 'La sube Grupo Inmobiliario Norte',
        'fiscal': 'La administra Grupo Inmobiliario Norte',
        'banco': 'La administra Grupo Inmobiliario Norte',
        'carta': 'Solo aplica al agente independiente',
      },
    ),
  );

  SesionAgente sesionIndependiente() => const SesionAgente(
    identidad: IdentidadAgente(email: 'alex@sozu.com'),
  );

  ProviderContainer contenedor({
    required SesionAgente sesion,
    FakePerfilAgentePort? port,
  }) => makeClientContainer(
    overrides: [
      sesionProvider.overrideWith((ref) => Future.value(sesion)),
      if (port != null) perfilAgentePortProvider.overrideWithValue(port),
    ],
  );

  test(
    'fiscal y banco salen en solo lectura CON nota antes de cargar el perfil',
    () async {
      // Sin leer `perfilAgenteProvider`: la única fuente es la sesión, que ya
      // está en memoria cuando la pantalla se pinta.
      final container = contenedor(sesion: sesionDependiente());
      await container.read(sesionProvider.future);

      expect(
        container.read(notaSoloLecturaProvider(CampoRestringido.fiscal)),
        'La administra Grupo Inmobiliario Norte',
      );
      expect(
        container.read(notaSoloLecturaProvider(CampoRestringido.banco)),
        'La administra Grupo Inmobiliario Norte',
      );
      expect(
        container.read(notaSoloLecturaProvider(CampoRestringido.constancia)),
        'La sube Grupo Inmobiliario Norte',
      );
      expect(container.read(administraDatosDeCobroProvider), isFalse);
    },
  );

  test('el agente independiente sí administra fiscal y banco', () async {
    final container = contenedor(sesion: sesionIndependiente());
    await container.read(sesionProvider.future);

    expect(
      container.read(notaSoloLecturaProvider(CampoRestringido.fiscal)),
      isNull,
    );
    expect(
      container.read(notaSoloLecturaProvider(CampoRestringido.banco)),
      isNull,
    );
    expect(container.read(administraDatosDeCobroProvider), isTrue);
  });

  test(
    'sin recorte en la sesión, el propio perfil respalda el solo lectura',
    () async {
      // La sesión pudo servirse antes de que el agente quedara ligado a la
      // inmobiliaria; el perfil trae el dato fresco y no se puede ignorar.
      final port = FakePerfilAgentePort(perfil: perfilDependienteDePrueba());
      final container = contenedor(sesion: sesionIndependiente(), port: port);
      await container.read(sesionProvider.future);
      await container.read(perfilAgenteProvider.future);

      expect(
        container.read(notaSoloLecturaProvider(CampoRestringido.fiscal)),
        'La administra Grupo Inmobiliario Norte',
      );
      expect(
        container.read(notaSoloLecturaProvider(CampoRestringido.constancia)),
        'La administra Grupo Inmobiliario Norte',
      );
      expect(container.read(administraDatosDeCobroProvider), isFalse);
    },
  );

  test('la Constancia del dependiente viene marcada de solo lectura', () async {
    final port = FakePerfilAgentePort(perfil: perfilDependienteDePrueba());
    final container = contenedor(sesion: sesionDependiente(), port: port);
    final perfil = await container.read(perfilAgenteProvider.future);

    expect(perfil.expediente.constanciaSoloLectura, isTrue);
    final csf = perfil.expediente.documento('csf');
    expect(csf?.soloLectura, isTrue);
    expect(csf?.nota, 'La sube Grupo Inmobiliario Norte');

    // La carta solo aplica al independiente: el backend no la manda.
    expect(perfil.expediente.documento('carta'), isNull);
    expect(perfil.puedeEditarBanco, isFalse);
    expect(perfil.puedeEditarFiscal, isFalse);
  });

  test(
    'la activación del dependiente cuenta fiscal y banco como completos',
    () async {
      // Los lleva su inmobiliaria: si contaran como pendientes, el agente no
      // podría llegar nunca al 100 % y el aviso de cobros no lo dejaría en paz.
      final port = FakePerfilAgentePort(perfil: perfilDependienteDePrueba());
      final container = contenedor(sesion: sesionDependiente(), port: port);
      final perfil = await container.read(perfilAgenteProvider.future);

      expect(perfil.activacion.paso('fiscal')?.completo, isTrue);
      expect(perfil.activacion.paso('fiscal')?.soloLectura, isTrue);
      expect(perfil.activacion.paso('bank-accounts')?.completo, isTrue);
      expect(perfil.activacion.puedeRecibirComisiones, isTrue);
    },
  );
}
