# SOZU · Portal del Agente

App Flutter multiplataforma (web, Android, iOS) donde el cliente de SOZU
consulta sus propiedades, pagos, estado de cuenta, documentos y perfil. Un
super administrador puede entrar en modo "Ver como" para navegar el portal con
los datos de un cliente.

Backend: Edge Functions de Supabase. Este repo es **solo frontend**.

## Reglas del proyecto

Seguridad, no negociable:

- Solo ANON KEY publica y el JWT del usuario. Nunca `service_role` ni
  credenciales de base de datos en el codigo.
- Cero queries a tablas. Todo dato sensible viaja por Edge Function.
- No se registra PII en logs (RFC, CURP, CLABE, montos).
- Sesion y tokens en `flutter_secure_storage`, nunca en SharedPreferences.

Codigo:

- Identificadores en ingles. En espanol solo los textos que ve el usuario y las
  claves del JSON del backend (esas las traduce el adaptador).
- El backend se consume por puertos. Ninguna pantalla importa el SDK.
- Estilos por token (`context.s`). Prohibidos `Color(0x...)`, `fontSize: 14`,
  `circular(16)` y `EdgeInsets.all(14)` en pantallas.
- Imports siempre `package:sozu_agente_app/...`.
- dartdoc conciso: 1-3 lineas por miembro.
- Prohibido el guion largo. Solo `-`; como separador visible, `·`.

Proceso:

- Rama de trabajo: `dev-eddy`. De ahi salen los PR hacia `dev`.
- SQL y deploys de Edge Functions no se ejecutan desde aqui: se entrega un `.md`
  en `Ejecuciones_manuales/` y se aplica por el canal autorizado.

## Arquitectura

Puertos y adaptadores (hexagonal) sobre features por actor:

```text
lib/
  shared/          contrato y utilidades transversales
                   api_error.dart · ports/ · adapters/ · providers/
  features/
    auth/          acceso, biometria, cambio de contrasena
    admin/         selector de cliente ("Ver como") y avisos
    client/        el portal, por area de menu
                   home/ properties/ products/ documents/ profile/
                   layouts/  el shell de 5 tabs
  data/models.dart DTOs del backend (sin dependencias)
  ui/              design system: tokens, tema y 16 primitivas
  core/            formato, storage, descargas, version
  router.dart      rutas y guards de sesion
```

Cada feature (u hoja de `client`) tiene la misma forma:

| Carpeta | Que va ahi |
| --- | --- |
| `ports/` | el contrato: `abstract interface class` |
| `adapters/` | la implementacion; el unico sitio que sabe del backend |
| `providers/` | estado y datos para la UI |
| `screens/` | pantallas: solo composicion, sin logica |
| `components/` | piezas reutilizables (2+ pantallas) |
| `layouts/` | estructura: decide tema, scroll y breakpoints |
| `services/` | logica sin UI, solo si la feature la tiene |

Un puerto solo importa `models.dart` y `api_error.dart`: ni Flutter, ni Riverpod,
ni el SDK del backend. Es verificable con grep y el CI lo respeta.

Por que asi: el nombre de una clase no menciona al proveedor (`AuthAdapter`, no
`SupabaseAuthAdapter`), asi que cambiar de backend es reescribir los adaptadores
sin tocar pantallas ni tests. Y los tests usan dobles de los puertos, sin red.

Detalle en `docs/adr/` y en el README de cada feature.

## Correr la app

```bash
./tool/dev.sh                # web en http://localhost:5000 (hot reload)
./tool/dev.sh <device-id>    # telefono por cable (hot reload)
./tool/web.sh                # web en RELEASE, para medir rendimiento
./tool/apk.sh                # APK release, se copia a Descargas de Windows
./tool/check.sh              # formato + analyze + tests
```

Requiere `assets/env` (gitignored): copiar de `.env.example` y llenar
`SUPABASE_URL` y `SUPABASE_ANON_KEY`.

**Para juzgar rendimiento nunca se usa `dev.sh`**: corre en debug, que en web
compila sin optimizar y es varias veces mas lento que produccion. Medir con
`./tool/web.sh`, `PROFILE=1 ./tool/dev.sh` o un APK release.

Flujo diario, USB y diagnostico: `tool/README.md`.

## Puesta en marcha (lo que NO se puede hacer desde el repo)

Este repo nace de `sozu-cliente-app`, así que hereda su CI ya cableado. Lo que
falta vive en consolas externas y hay que hacerlo a mano:

| Qué | Dónde | Sin esto |
| --- | --- | --- |
| Site de hosting `sozu-agente-app` | Firebase console → Hosting | el deploy web falla |
| App Android del bundle `com.sozu.agentes_app` y app iOS `com.sozu.sozuAgenteApp` | Firebase console → Configuración | **el build de Android falla**: el `google-services.json` del repo todavía es el de la app de clientes y el plugin de Google Services aborta con "No matching client found for package name" |
| Reemplazar `android/app/google-services.json` y `lib/firebase_options.dart` | salida de `flutterfire configure` | push notifications registran en la app equivocada |
| Secrets del repo: `FIREBASE_SERVICE_ACCOUNT_SOZU_CLIENTE_PRD`, `FIREBASE_GCP_DEV`, `DOCS_REPO_TOKEN`, `ANTHROPIC_API_KEY` | GitHub → Settings → Secrets | los workflows fallan (mismos valores que en `sozu-cliente-app`) |
| Secrets de Edge Functions: `PORTAL_WEB_URL`, `MIFIEL_ENVIRONMENT`, opcional `AGENTE_ROL_IDS` | Supabase (dashboard en prod, `.env` del stack en el VPS de dev) | los links digitales apuntan al host equivocado y la firma Mifiel cancela documentos creados desde la web |
| App en Play Console y en App Store Connect | consolas de tienda | los pipelines de publicación no tienen a dónde subir |
| Redirect URL `https://agentes.sozu.com/auth/confirmacion-email` | Supabase Auth → URL Configuration | el enlace de recuperar contraseña no canjea el token |
| Aplicar la migración `20260810020000_portal_agentes_app_infra.sql` | repo `sozu-supabase-migrations` | push y version gate degradan a vacío (no rompen, pero no funcionan) |

**Limitación conocida del acceso:** el "olvidé mi contraseña" self-service exige
`roles.requiere_confirmacion_email = true`, y el rol 9 (Agente Interno) lo tiene
en `false`. Un agente interno **no** puede recuperar su contraseña solo; se la
repone un administrador. El rol 3 (Agente Inmobiliario) sí puede.

## Estado

- Infraestructura heredada de `sozu-cliente-app`: design system `lib/ui/`,
  arquitectura hexagonal, CI de 11 pipelines, auth completa (biometría,
  recuperación y cambio de contraseña, confirmación de correo, inactividad,
  version gate).
- Acceso propio: gate por rol 3 (Agente Inmobiliario) y 9 (Agente Interno) en
  `features/auth/services/portal_access.dart`, espejo de `authAgente()` en
  `sozu-edge-functions`.
- Datos: 11 Edge Functions `agente-*`. Cero queries a tablas desde el app.
- Deuda heredada: `PortalColors` e `isPortalMode` (el tema legacy y el
  interruptor móvil/web) siguen en pantallas portadas. Anotada en
  `docs/adr/ESTADO.md`.

## Documentacion

| Archivo | Para que |
| --- | --- |
| `CLAUDE.md` | reglas operativas y convenciones, en detalle |
| `docs/adr/0001-arquitectura-modular.md` | por que features y design system |
| `docs/adr/0002-puertos-y-adaptadores.md` | por que hexagonal + inventario |
| `docs/adr/ESTADO.md` | que falta y en que orden |
| `lib/features/*/README.md` | reglas y funcionamiento de cada feature |
| `tool/README.md` | correr la app en web y en fisico |
