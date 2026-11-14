# munyati.co website (Phase 7)

Static, no build step. Arabic first (RTL) with an English page.

| URL | File | Notes |
|---|---|---|
| `/` | `index.html` | Landing for brides |
| `/providers` | `providers.html` | For providers: plans, trial, how booking works |
| `/terms`, `/privacy`, `/about`, `/faq`, `/provider-terms` (+ `/en/…`) | `legal.html` | Text comes live from `cms_pages` (edit in the dashboard) |
| `/support`, `/delete-account` | | Required by App Store review |
| `/p/:id`, `/s/:id`, `/store/:id`, `/c/:id`, `/b/:id`, `/plans` | `open.html` | Opens the app (universal links), else shows "Get the app" |
| `/.well-known/apple-app-site-association` | | Universal links for `co.munyati.app` |

## Before deploying
1. `config.js`: Supabase URL + **anon** key, later the App Store URL and WhatsApp number.
2. `.well-known/apple-app-site-association`: replace `TEAMID` with your Apple Team ID.

## Hosting (Cloudflare Workers, static assets)
Worker `munyati-website` in Munyati's Cloudflare account (`0c80992cee84e730d01943c5cd956dad`, the same
account as the dashboard). Moved from Vercel on 2026-11-14. Preview URL:
https://munyati-website.munyati-dashboard.workers.dev; production: https://munyati.co (custom domains
`munyati.co` + `www.munyati.co`, Cloudflare → Workers & Pages → munyati-website → Settings → Domains).

- Files are served as they are; `/providers` serves `providers.html` (and `/providers.html` 307s to it).
- `worker.js` runs only when no file matches and does what `vercel.json` used to: `/terms`, `/privacy`,
  `/about`, `/faq`, `/provider-terms` (+ `/en/…`) → `legal.html`; `/p|s|store|c|b/:id` and `/plans` → `open.html`.
- `_headers`: AASA and `assetlinks.json` as `application/json`, plus security headers.
- `.assetsignore` keeps config files (`wrangler.jsonc`, `worker.js`, this README…) from being served.
  Add any new non-public file there.
- **Auto-deploy:** pushes to `main` touching `website/` run `.github/workflows/deploy-website.yml`
  (secret `CLOUDFLARE_API_TOKEN`, variable `CLOUDFLARE_ACCOUNT_ID`; shared with the dashboard).
- **Manual / local:** in this folder, `npx wrangler@4.162.0 dev` to test, `npx wrangler@4.162.0 whoami`
  (must show the Munyati account) then `npx wrangler@4.162.0 deploy`.

Check universal links after deploying: `https://munyati.co/.well-known/apple-app-site-association`
must return JSON with status 200 and no redirect.
