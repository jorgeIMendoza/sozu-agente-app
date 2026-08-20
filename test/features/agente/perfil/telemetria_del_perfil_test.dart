import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_agente_app/features/agente/perfil/services/telemetria_del_perfil.dart';

/// Contrato con el tablero de CTA: estos identificadores son los que emite
/// `AgentPerfil.tsx`. Si alguno cambia aquí, el mismo botón se cuenta en dos
/// series y ninguna de las dos es el total, así que quedan fijados.
void main() {
  test('los identificadores son los del portal web', () {
    expect(TelemetriaPerfil.ruta, '/admin/agent/perfil');
    expect(TelemetriaPerfil.pagina, 'agent_perfil');
    expect(TelemetriaPerfil.pageView, 'page_view');
    expect(TelemetriaPerfil.tipoPagina, 'page');
    expect(TelemetriaPerfil.seccionDatosCuenta, 'btn_seccion_datos_cuenta');
    expect(TelemetriaPerfil.seccionDocumentos, 'btn_seccion_documentos');
    expect(TelemetriaPerfil.etapaOnboarding, 'btn_etapa_onboarding');
  });
}
