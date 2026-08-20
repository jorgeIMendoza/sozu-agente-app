import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/prospectos/ports/prospectos_port.dart';
import 'package:sozu_agente_app/features/agente/prospectos/services/prospectos_reglas.dart';

/// Contrato de `buscar_existente`, la búsqueda que evita dar de alta dos veces
/// a la misma persona (pasó en producción con las personas 3058 y 3112).
///
/// Se fija el MAPEO con las claves crudas del servidor y las reglas que deciden
/// cuándo se pregunta y qué se le dice al agente.
void main() {
  Map<String, dynamic> respuesta({
    String motivo = 'correo',
    List<int> registrados = const [17],
    List<Map<String, dynamic>> leads = const [
      {
        'id_proyecto': 17,
        'proyecto': 'BELLARA',
        'dueno': 'Nombre del Agente',
        'es_mio': false,
        'estatus': 'Contactado',
      },
    ],
    bool esCliente = false,
  }) => {
    'coincidencias': [
      {
        'id_persona': 3112,
        'nombre': 'Janeth Velazquez Wirth',
        'motivo': motivo,
        'es_cliente': esCliente,
        'proyectos_registrados': registrados,
        'leads': leads,
        'sin_leads': leads.isEmpty,
      },
    ],
  };

  group('mapeo de la respuesta', () {
    test('los tres valores de motivo llegan como enum', () {
      MotivoCoincidencia motivoDe(String clave) =>
          CoincidenciasDeProspecto.fromJson(
            respuesta(motivo: clave),
          ).coincidencias.single.motivo;

      expect(motivoDe('correo'), MotivoCoincidencia.correo);
      expect(motivoDe('telefono'), MotivoCoincidencia.telefono);
      expect(motivoDe('correo_y_telefono'), MotivoCoincidencia.correoYTelefono);
    });

    test('una clave de motivo desconocida cae en teléfono, no revienta', () {
      final c = CoincidenciasDeProspecto.fromJson(respuesta(motivo: 'rfc'));
      expect(c.coincidencias.single.motivo, MotivoCoincidencia.telefono);
    });

    test('la coincidencia trae persona, desarrollos y leads', () {
      final c = CoincidenciasDeProspecto.fromJson(
        respuesta(motivo: 'correo_y_telefono'),
      ).coincidencias.single;

      expect(c.idPersona, 3112);
      expect(c.nombre, 'Janeth Velazquez Wirth');
      expect(c.desarrollosRegistrados, [17]);
      expect(c.sinLeads, isFalse);

      final lead = c.leads.single;
      expect(lead.idDesarrollo, 17);
      expect(lead.desarrollo, 'BELLARA');
      expect(lead.dueno, 'Nombre del Agente');
      expect(lead.esMio, isFalse);
      expect(lead.estado, 'Contactado');
    });

    test('sin leads visibles queda marcado y sin desarrollos', () {
      final c = CoincidenciasDeProspecto.fromJson(
        respuesta(registrados: const [], leads: const []),
      ).coincidencias.single;

      expect(c.sinLeads, isTrue);
      expect(c.leads, isEmpty);
      expect(c.desarrollosRegistrados, isEmpty);
    });

    test('aviso_no_disponible llega sin coincidencias y sin excepción', () {
      final c = CoincidenciasDeProspecto.fromJson({
        'coincidencias': [],
        'aviso_no_disponible': true,
      });

      expect(c.noDisponible, isTrue);
      expect(c.hayCoincidencias, isFalse);
    });

    test('una respuesta vacía no promete nada ni avisa', () {
      final c = CoincidenciasDeProspecto.fromJson({'coincidencias': []});
      expect(c.noDisponible, isFalse);
      expect(c.hayCoincidencias, isFalse);
    });
  });

  group('cuándo se pregunta', () {
    test('un teléfono de menos de 10 dígitos no es criterio', () {
      expect(ultimos10('55123'), '');
      expect(hayCriterioDeDuplicados(email: '', telefono: '55123'), isFalse);
      expect(hayCriterioDeDuplicados(email: 'ana@', telefono: '5512'), isFalse);
    });

    test('10 dígitos útiles sí, con lada, espacios y guiones', () {
      expect(ultimos10('+52 322 111 2233'), '3221112233');
      expect(hayCriterioDeDuplicados(telefono: '+52 322 111 2233'), isTrue);
    });

    test('un correo con formato válido basta, aunque no haya teléfono', () {
      expect(hayCriterioDeDuplicados(email: 'ana@correo.com'), isTrue);
    });
  });

  group('qué se le dice al agente', () {
    test('el motivo va en palabras', () {
      expect(motivoEnPalabras(MotivoCoincidencia.correo), 'coincide el correo');
      expect(
        motivoEnPalabras(MotivoCoincidencia.telefono),
        'coincide el teléfono',
      );
      expect(
        motivoEnPalabras(MotivoCoincidencia.correoYTelefono),
        'coinciden el correo y el teléfono',
      );
    });

    test('un lead ajeno nombra al dueño', () {
      final c = CoincidenciasDeProspecto.fromJson(
        respuesta(),
      ).coincidencias.single;
      expect(
        describirCoincidencia(c),
        'Ya está registrado y tiene dueño: BELLARA · Nombre del Agente.',
      );
    });

    test('sin nombre del dueño se dice "otro asesor", no un renglón cojo', () {
      final c = CoincidenciasDeProspecto.fromJson(
        respuesta(
          leads: const [
            {'id_proyecto': 17, 'proyecto': 'BELLARA', 'es_mio': false},
          ],
        ),
      ).coincidencias.single;
      expect(describirCoincidencia(c), contains('otro asesor'));
    });

    test('si todos los leads son míos lo dice así', () {
      final c = CoincidenciasDeProspecto.fromJson(
        respuesta(
          leads: const [
            {'id_proyecto': 17, 'proyecto': 'BELLARA', 'es_mio': true},
          ],
        ),
      ).coincidencias.single;
      expect(describirCoincidencia(c), 'Ya es tu prospecto en BELLARA.');
    });

    test('sin leads visibles se duda en voz alta en vez de afirmar', () {
      final c = CoincidenciasDeProspecto.fromJson(
        respuesta(registrados: const [], leads: const []),
      ).coincidencias.single;
      expect(describirCoincidencia(c), contains('otro asesor'));
      expect(describirCoincidencia(c), contains('Confírmalo'));
    });

    test('quien ya compró se anuncia como cliente', () {
      final c = CoincidenciasDeProspecto.fromJson(
        respuesta(registrados: const [], leads: const [], esCliente: true),
      ).coincidencias.single;
      expect(describirCoincidencia(c), 'Esta persona ya es cliente de SOZU.');
    });

    test('el encabezado cuenta en singular y en plural', () {
      expect(encabezadoDeDuplicados(1), contains('un registro'));
      expect(encabezadoDeDuplicados(3), contains('3 registros'));
    });
  });
}
