// Runs only for paths with no matching file. Mirrors the old vercel.json rewrites:
// legal pages are one template (legal.html reads location.pathname), and app links
// (/p/:id, /s/:id, /store/:id, /c/:id, /b/:id, /plans) land on open.html.
const SECURITY_HEADERS = {
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "X-Frame-Options": "DENY",
};

function target(pathname) {
  const p = pathname.replace(/\/+$/, "");
  if (/^\/(en\/)?(terms|privacy|about|faq|provider-terms)$/.test(p)) return "/legal";
  if (/^\/(p|s|store|c|b)\/[^/]+$/.test(p) || p === "/plans") return "/open";
  return null;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const to = target(url.pathname);
    if (!to) return env.ASSETS.fetch(request);
    url.pathname = to;
    const asset = await env.ASSETS.fetch(new Request(url, request));
    const response = new Response(asset.body, asset);
    for (const [k, v] of Object.entries(SECURITY_HEADERS)) response.headers.set(k, v);
    return response;
  },
};
