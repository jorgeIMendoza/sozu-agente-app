import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/prospectos_reglas.dart';
import 'package:sozu_agente_app/shared/api_error.dart';

Prospecto _prospecto({
  required int id,
  required String nombre,
  String? email,
  String? telefono,
  bool esCliente = false,
  int unidades = 0,
  List<DesarrolloDeProspecto> desarrollos = const [],
}) => Prospecto(
  idPersona: id,
  nombre: nombre,
  email: email,
  telefono: telefono,
  esCliente: esCliente,
  totalUnidades: unidades,
  desarrollos: desarrollos,
);

DesarrolloDeProspecto _desarrollo({
  int idRelacion = 1,
  int? id,
  String nombre = 'Margot',
  int? estado,
}) => DesarrolloDeProspecto(
  idRelacion: idRelacion,
  idDesarrollo: id,
  desarrollo: nombre,
  idEstadoLead: estado,
);

void main() {
  final ana = _prospecto(
    id: 1,
    nombre: 'Ana Torres',
    email: 'ana@correo.com',
    telefono: '5512345678',
    esCliente: true,
    unidades: 2,
    desarrollos: [_desarrollo(idRelacion: 101, id: 7, estado: 2)],
  );
  final bruno = _prospecto(
    id: 2,
    nombre: 'Bruno Díaz',
    email: 'bruno@correo.com',
    telefono: '5598765432',
    desarrollos: [
      _desarrollo(idRelacion: 102, id: 9, nombre: 'Torre Sur', estado: 1),
    ],
  );
  final cartera = [ana, bruno];

  group('filtros de la cartera', () {
    test('el texto busca en nombre, correo, teléfono y desarrollo', () {
      expect(filtrarProspectos(cartera, busqueda: 'bruno'), [bruno]);
      expect(filtrarProspectos(cartera, busqueda: 'ANA@correo'), [ana]);
      expect(filtrarProspectos(cartera, busqueda: '5598'), [bruno]);
      // "torre" a secas también casaría con "Ana Torres": el texto busca en
      // varios campos a la vez y eso es lo que se quiere.
      expect(filtrarProspectos(cartera, busqueda: 'torre sur'), [bruno]);
      expect(filtrarProspectos(cartera, busqueda: 'torre'), cartera);
      expect(filtrarProspectos(cartera, busqueda: '  '), cartera);
      expect(filtrarProspectos(cartera, busqueda: 'nadie'), isEmpty);
    });

    test('estado y desarrollo aciertan si CUALQUIER interés cumple', () {
      expect(filtrarProspectos(cartera, idEstadoLead: 1), [bruno]);
      expect(filtrarProspectos(cartera, idDesarrollo: 7), [ana]);
      expect(
        filtrarProspectos(cartera, idEstadoLead: 2, idDesarrollo: 9),
        isEmpty,
      );
    });

    test('los desarrollos del filtro salen de la cartera, sin repetir', () {
      final lista = desarrollosDeLaCartera([...cartera, ana]);
      expect(lista.map((d) => d.nombre), ['Margot', 'Torre Sur']);
    });

    test('un lead sin desarrollo es filtrable, no invisible', () {
      final huerfano = _prospecto(
        id: 3,
        nombre: 'Caro Lima',
        desarrollos: [
          _desarrollo(idRelacion: 103, nombre: 'Sin desarrollo', estado: 1),
        ],
      );
      final conHuerfano = [...cartera, huerfano];

      // El filtro lo ofrece con su propio centinela...
      final lista = desarrollosDeLaCartera(conHuerfano);
      expect(lista.map((d) => d.id), contains(idSinDesarrollo));
      expect(
        lista.firstWhere((d) => d.id == idSinDesarrollo).nombre,
        'Sin desarrollo',
      );

      // ...y elegirlo deja SOLO a los que no cuelgan de un proyecto.
      expect(filtrarProspectos(conHuerfano, idDesarrollo: idSinDesarrollo), [
        huerfano,
      ]);
      // Un id real sigue sin traerlo.
      expect(filtrarProspectos(conHuerfano, idDesarrollo: 7), [ana]);
    });
  });

  group('conteo del encabezado', () {
    test('cuenta sobre lo filtrado, no sobre la cartera completa', () {
      final totales = TotalesCartera.de([ana]);
      expect(totales.prospectos, 1);
      expect(totales.unidades, 2);
      expect(totales.conCompra, 1);
      expect(totales.resumen, '1 prospecto · 2 unidades · 1 con compra');
    });

    test('singulariza unidad y prospecto', () {
      final totales = TotalesCartera.de([
        _prospecto(id: 3, nombre: 'Solo', unidades: 1),
      ]);
      expect(totales.resumen, '1 prospecto · 1 unidad · 0 con compra');
    });
  });

  group('etapas del pipeline', () {
    test('traduce las claves conocidas', () {
      expect(etiquetaEtapa('apartado_pagado'), 'Apartado pagado');
      expect(etiquetaEtapa('ganado'), 'Cierre ganado');
    });

    test('humaniza una clave que ya no está en el catálogo', () {
      expect(etiquetaEtapa('etapa_nueva'), 'Etapa nueva');
      expect(etiquetaEtapa(''), 'Sin etapa');
    });
  });

  group('texto editable de una nota', () {
    test('quita el nombre de los archivos para no guardarlo dos veces', () {
      const adjuntos = [
        AdjuntoNota(nombre: 'plano.pdf', url: 'https://x/a.pdf'),
        AdjuntoNota(nombre: 'foto', url: 'https://x/b.png', esImagen: true),
      ];
      final texto = textoEditableDeNota(
        'Pidió cotización \u{1F4CE} plano.pdf',
        adjuntos,
      );
      expect(texto, 'Pidió cotización');
    });

    test('una nota sin archivos se devuelve tal cual', () {
      expect(
        textoEditableDeNota('Llamar el lunes', const []),
        'Llamar el lunes',
      );
    });
  });

  group('validación de la ficha', () {
    test('correo y teléfono son obligatorios y con formato', () {
      expect(errorEmail(''), isNotNull);
      expect(errorEmail('ana@'), isNotNull);
      expect(errorEmail('ana@correo.com'), isNull);
      expect(errorTelefono('551234'), isNotNull);
      expect(errorTelefono('5512345678'), isNull);
    });

    test('RFC y CURP son opcionales pero se validan si vienen', () {
      expect(errorRfc(''), isNull);
      expect(errorRfc('MAL'), isNotNull);
      expect(errorRfc('toan850101h2a'), isNull);
      expect(errorCurp(''), isNull);
      expect(errorCurp('TOAN850101HDFRRN09'), isNull);
      expect(errorCurp('TOAN850101'), isNotNull);
    });
  });

  group('mensajes de error', () {
    test('cada código del servidor tiene un mensaje con siguiente paso', () {
      for (final codigo in const [
        'not_owner',
        'email_duplicado',
        'rfc_duplicado',
        'curp_duplicado',
        'telefono_invalido',
        'proyecto_duplicado',
        'proyecto_no_permitido',
        'notas_no_disponibles',
        'archivo_demasiado_grande',
      ]) {
        final mensaje = mensajeDeErrorProspecto(ApiError(400, codigo));
        expect(mensaje, isNotEmpty, reason: codigo);
        expect(
          mensaje,
          isNot(contains('operación')),
          reason: '$codigo cayó en el mensaje genérico',
        );
      }
    });

    test('un código desconocido cae en el mensaje por defecto', () {
      expect(
        mensajeDeErrorProspecto(ApiError(500, 'algo_raro'), porDefecto: 'Ups'),
        'Ups',
      );
      expect(mensajeDeErrorProspecto(null), isNotEmpty);
    });
  });
}
