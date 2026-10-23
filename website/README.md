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

## Deploy (Vercel, free)
`npx vercel` in this folder (or import the repo in vercel.com with root directory `website`),
then add the domains `munyati.co` and `www.munyati.co` and set the DNS records Vercel shows.
`vercel.json` holds the clean URLs, rewrites and the AASA content type.
Check universal links after deploying: `https://munyati.co/.well-known/apple-app-site-association`
must return JSON with status 200 and no redirect.
