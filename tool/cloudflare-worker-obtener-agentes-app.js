/**
 * Cloudflare Worker: obtener-agentes-app.sozu.com
 *
 * Redirector de descarga de la app de AGENTES. Detecta el sistema operativo por
 * el User-Agent y manda a la tienda correcta. Es el destino que codifica el QR
 * del login (`assets/images/sozu-qr-web.png`) y el respaldo del aviso de
 * actualización cuando `app_agente_config` no trae la URL de tienda.
 *
 * Gemelo de `app-sozu-clientes` (obtener-clientes-app.sozu.com). Se mantiene
 * como archivo en el repo, y no solo pegado en el dashboard, para que el destino
 * de ese QR quede versionado: si alguien cambia el package o el id de App Store,
 * este archivo es donde se ve.
 *
 * ── Cómo se publica ─────────────────────────────────────────────────────────
 *   1. Cloudflare → Workers & Pages → Create application → Worker.
 *      Nombre: `app-sozu-agentes` (el de clientes se llama `app-sozu-clientes`).
 *   2. Pegar este archivo como código del worker y desplegar.
 *   3. Settings → Domains & Routes → Add → Custom domain:
 *      `obtener-agentes-app.sozu.com`. Cloudflare crea el registro DNS solo,
 *      porque la zona sozu.com ya vive ahí.
 *
 * O con wrangler, desde esta carpeta:
 *   npx wrangler deploy tool/cloudflare-worker-obtener-agentes-app.js \
 *     --name app-sozu-agentes --compatibility-date 2026-08-11
 *   (y luego el custom domain desde el dashboard)
 *
 * ── Pendiente al publicar en las tiendas ────────────────────────────────────
 * `IOS_APP_ID` queda en null hasta que exista el registro en App Store Connect:
 * el id numérico sale de la URL de la ficha (apps.apple.com/…/id<NUMERO>).
 * Mientras sea null, un iPhone cae en FALLBACK en vez de mandar a una ficha que
 * no existe — un 404 de App Store se lee como "la app no salió".
 */

/** Package de la app en Google Play (= `sozu.applicationId` de gradle.properties). */
const ANDROID_PACKAGE = 'com.sozu.agentes_app';

/** Id numérico de la app en App Store Connect. null = todavía no publicada. */
const IOS_APP_ID = null;

/** A dónde va quien no es móvil, o iOS sin ficha todavía. */
const FALLBACK = 'https://agentes.sozu.com';

const PLAY_URL = `https://play.google.com/store/apps/details?id=${ANDROID_PACKAGE}`;
const APPSTORE_URL = IOS_APP_ID
  ? `https://apps.apple.com/mx/app/id${IOS_APP_ID}`
  : FALLBACK;

export default {
  async fetch(request) {
    const ua = (request.headers.get('user-agent') || '').toLowerCase();

    // iPad moderno se anuncia como Macintosh: sin el chequeo de touch, un iPad
    // acabaría en el fallback web en vez de en App Store.
    const esIOS = /iphone|ipod|ipad/.test(ua) ||
      (/macintosh/.test(ua) && /mobile/.test(ua));
    const esAndroid = /android/.test(ua);

    const destino = esIOS ? APPSTORE_URL : esAndroid ? PLAY_URL : FALLBACK;

    // 302 y no 301: el destino cambia cuando la app se publica en App Store, y
    // un 301 se queda cacheado en el teléfono del agente para siempre.
    return Response.redirect(destino, 302);
  },
};
