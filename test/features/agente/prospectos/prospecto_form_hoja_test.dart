import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sozu_agente_app/features/agente/prospectos/components/prospecto_form_hoja.dart';
import 'package:sozu_agente_app/features/agente/prospectos/providers/prospectos_providers.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/prospectos_reglas.dart';
import 'package:sozu_agente_app/ui/ui.dart';

import '../agente_test_support.dart';
import 'fake_prospectos_port.dart';

/// El alta de prospecto de verdad: que la búsqueda de duplicados se dispare
/// cuando toca (y no antes), que el aviso diga de quién es el prospecto y que
/// nada de esto impida guardar.
void main() {
  /// Un duplicado como el que devuelve el servidor: la misma persona en un
  /// desarrollo con otro dueño.
  Map<String, dynamic> duplicado({
    String motivo = 'correo_y_telefono',
    List<int> registrados = const [7],
  }) => {
    'coincidencias': [
      {
        'id_persona': 3112,
        'nombre': 'Janeth Velazquez Wirth',
        'motivo': motivo,
        'es_cliente': false,
        'proyectos_registrados': registrados,
        'leads': [
          {
            'id_proyecto': 7,
            'proyecto': 'Margot',
            'dueno': 'Nombre del Agente',
            'es_mio': false,
            'estatus': 'Contactado',
          },
        ],
        'sin_leads': false,
      },
    ],
  };

  /// Campo por su texto de ayuda: los índices de la hoja cambian en cuanto se
  /// agrega un campo, el hint no.
  Finder campo(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
  );

  Future<void> abrirAlta(WidgetTester tester, FakeProspectosPort port) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [prospectosPortProvider.overrideWithValue(port)],
        ),
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => editarProspecto(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  /// Deja pasar el debounce y la respuesta.
  Future<void> esperarDebounce(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('un teléfono corto no dispara la búsqueda; 10 dígitos sí', (
    tester,
  ) async {
    final port = FakeProspectosPort();
    await abrirAlta(tester, port);

    await tester.enterText(campo('5512345678'), '55123');
    await esperarDebounce(tester);
    expect(port.log, isNot(contains('buscarExistente')));

    await tester.enterText(campo('5512345678'), '5512345678');
    await esperarDebounce(tester);
    expect(port.log, contains('buscarExistente'));
    expect(port.duplicadosBuscados.single.telefono, '5512345678');
    // Sin correo válido no se manda correo: el servidor no lo necesita.
    expect(port.duplicadosBuscados.single.email, isNull);
  });

  testWidgets('el aviso dice el motivo, el desarrollo y el dueño ajeno', (
    tester,
  ) async {
    final port = FakeProspectosPort()..respuestaDeDuplicados = duplicado();
    await abrirAlta(tester, port);

    await tester.enterText(
      campo('juan.perez@correo.com'),
      'janeth@dominio.com',
    );
    await esperarDebounce(tester);

    expect(find.text(encabezadoDeDuplicados(1)), findsOne);
    expect(find.text('Janeth Velazquez Wirth'), findsOne);
    expect(find.text('Porque coinciden el correo y el teléfono'), findsOne);
    expect(find.text('· Nombre del Agente'), findsOne);
    expect(find.text('· Contactado'), findsOne);
    expect(find.text(cierreDeDuplicados), findsOne);
    expect(find.text(duplicadosNoDisponibles), findsNothing);
  });

  testWidgets('un lead propio se marca como tuyo', (tester) async {
    final port = FakeProspectosPort()
      ..respuestaDeDuplicados = {
        'coincidencias': [
          {
            'id_persona': 11,
            'nombre': 'Ana Torres',
            'motivo': 'correo',
            'proyectos_registrados': [7],
            'leads': [
              {
                'id_proyecto': 7,
                'proyecto': 'Margot',
                'dueno': 'Yo',
                'es_mio': true,
                'estatus': 'Conectado',
              },
            ],
          },
        ],
      };
    await abrirAlta(tester, port);

    await tester.enterText(campo('juan.perez@correo.com'), 'ana@correo.com');
    await esperarDebounce(tester);

    expect(find.text('Tuyo'), findsOne);
    expect(find.text('Ya es tu prospecto en Margot.'), findsOne);
  });

  testWidgets('los desarrollos ya registrados salen deshabilitados', (
    tester,
  ) async {
    final port = FakeProspectosPort()..respuestaDeDuplicados = duplicado();
    await abrirAlta(tester, port);

    await tester.enterText(
      campo('juan.perez@correo.com'),
      'janeth@dominio.com',
    );
    await esperarDebounce(tester);

    final chip = tester.widget<SChoiceChip>(
      find.widgetWithText(SChoiceChip, 'Margot · Ya registrado'),
    );
    expect(chip.enabled, isFalse);

    // Y deja de ofrecerse en el selector: el servidor lo rechazaría.
    final selector = tester.widget<SSelectField<int>>(
      find.byType(SSelectField<int>),
    );
    expect(selector.opciones.map((o) => o.label), ['Torre Sur']);
  });

  testWidgets('una coincidencia solo por teléfono no bloquea desarrollos', (
    tester,
  ) async {
    final port = FakeProspectosPort()
      ..respuestaDeDuplicados = duplicado(motivo: 'telefono');
    await abrirAlta(tester, port);

    await tester.enterText(campo('5512345678'), '5512345678');
    await esperarDebounce(tester);

    // El teléfono repetido puede ser de un familiar: se avisa, pero no se
    // deshabilita nada.
    expect(find.text('Janeth Velazquez Wirth'), findsOne);
    expect(find.text('Margot · Ya registrado'), findsNothing);
    final selector = tester.widget<SSelectField<int>>(
      find.byType(SSelectField<int>),
    );
    expect(selector.opciones.map((o) => o.label), ['Margot', 'Torre Sur']);
  });

  testWidgets('aviso_no_disponible avisa discreto y NO bloquea el guardado', (
    tester,
  ) async {
    final port = FakeProspectosPort()
      ..respuestaDeDuplicados = {
        'coincidencias': [],
        'aviso_no_disponible': true,
      };
    await abrirAlta(tester, port);

    await tester.enterText(campo('Juan Pérez García'), 'Janeth Velazquez');
    await tester.enterText(
      campo('juan.perez@correo.com'),
      'janeth@dominio.com',
    );
    await tester.enterText(campo('5512345678'), '3221112233');
    await esperarDebounce(tester);

    expect(find.text(duplicadosNoDisponibles), findsOne);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Margot').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(port.log, contains('crear:janeth@dominio.com:7'));
  });
}
