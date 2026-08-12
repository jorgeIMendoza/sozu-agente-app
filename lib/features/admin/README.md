# Feature `admin`

Área de super administrador: elegir un agente para ver el portal como él
("Ver como agente") y enviar avisos por push, correo y WhatsApp. Dos
pantallas, fuera del shell del portal.

## Reglas

Qué sí:

- El backend se consume SOLO vía `AdminPort` a través de los providers de
  la feature. Las pantallas no conocen el adaptador.
- La autorización real la da el backend (`roles.apps.administrar` incluye
  `agentes`, vía `authAdminAgentes`); la UI solo pinta y enruta.
- `impersonation_provider` es API pública de la feature: la capa de datos
  del portal lo observa para el contexto "Ver como".
- Scroll de página completa: el contenido no trae scroll propio (listas
  con `shrinkWrap` o `Column`; ver `AdminLayout`).
- dartdoc conciso: 1-3 líneas por miembro.

Qué no:

- Nada de `supabase_flutter` fuera de `adapters/admin_adapter.dart`.
- Nada de vendor en nombres: `AdminAdapter`, no `SupabaseAdminAdapter`.
- Sin llamadas sueltas a edge functions: todo pasa por `AdminPort`.
- Los DTOs (`AdminAgente`, `RolAgente`, `AvisoApp`...) no se mueven aquí:
  viven en `data/models.dart`, el contrato compartido con cero imports.
- Biometría no aplica al admin: entra siempre con correo y contraseña
  (regla implementada en `features/auth`).

## Estructura

```text
ports/       admin_port.dart           contrato (10 métodos)
adapters/    admin_adapter.dart        implementación actual (único con supabase_flutter)
providers/   admin_providers.dart      adminPortProvider + adminAgentesProvider
             impersonation_provider.dart  contexto "Ver como"
screens/     select_agente_screen, announcements_screen
components/  admin_header_bar, agente_filters (AgenteRoleFilter), agente_row
layouts/     admin_layout.dart         AdminLayout + AdminScrollArea
```

## Funcionamiento

- Selector: la lista llega completa de `admin-agentes` y se acota EN EL APP
  por rol (`AgenteRoleFilter`: Agente Inmobiliario 3 / Agente Interno 9) y
  por nombre o correo; los dos filtros se combinan. Al elegir,
  `impersonation_provider` fija el `personaId`, el adaptador manda
  `x-impersonate-id-persona` y los providers del portal recargan con ese
  contexto. El target se limpia al cambiar de usuario o cerrar sesión.
  Filtrar local y no por endpoint es deliberado: son decenas de agentes, no
  los miles de clientes del otro portal.
- Avisos: crear (inmediato o calendarizado, con destino por proyecto,
  modelo, nivel o propiedad), listar y cancelar programados; más la
  animación de la campana del cliente.
- `AdminScrollArea`: el scroll envuelve al limitador de ancho, nunca al
  revés (la rueda debe funcionar en los laterales). Las rutas de admin van
  `sinMarco: true` en el router por lo mismo.

## Cómo agregar funcionalidad

1. Método nuevo de backend: firma en `AdminPort`, implementación en
   `AdminAdapter`, doble en `test/features/admin/fake_admin_port.dart`.
2. Dato para una pantalla: `FutureProvider` en `admin_providers.dart` que
   lea el puerto; mutaciones imperativas con `ref.read(adminPortProvider)`.
3. Pantalla nueva: envolver en `AdminLayout` (o `.fixed` si tiene
   pestañas), encabezado con `AdminHeaderBar`, ruta `sinMarco: true`.
4. Catálogo con datos raros (p. ej. entradas que no son proyectos): el
   problema es de datos, se corrige en backend; no filtrar por nombre en
   el cliente.
