// Serves the Hugo build (./public) as Workers static assets. wrangler.jsonc
// sets run_worker_first, so every request passes through here. This does what
// the nginx config did before the move to Cloudflare:
// Markdown content negotiation, cache and Vary headers, and www → apex.

// Markdown for agents: a client that asks for text/markdown (and doesn't rule
// it out with q=0) gets the page's index.md instead of index.html.
const WANTS_MARKDOWN = /text\/markdown(?!\s*;\s*q\s*=\s*0(\.0*)?\s*(,|$))/i;

// Headers added to every response. Empty here; tommyeriksen.dk sets HSTS/CSP.
const SECURITY_HEADERS = {};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.hostname.startsWith("www.")) {
      url.hostname = url.hostname.slice(4);
      return Response.redirect(url.toString(), 301);
    }

    let response = null;
    if (WANTS_MARKDOWN.test(request.headers.get("Accept") || "")) {
      response = await markdown(request, url, env);
    }
    response ??= await env.ASSETS.fetch(request);
    return withHeaders(response);
  },
};

// The Markdown copy of the page at url (/about/ → /about/index.md), or null
// when there is none, so the request falls back to the HTML or the asset.
async function markdown(request, url, env) {
  const mdUrl = new URL(url);
  mdUrl.pathname = url.pathname.replace(/\/?$/, "/index.md");
  const response = await env.ASSETS.fetch(new Request(mdUrl, request));
  return response.ok || response.status === 304 ? response : null;
}

function withHeaders(original) {
  const response = new Response(original.body, original);
  const headers = response.headers;

  // Serve Markdown inline as UTF-8 text instead of as a download.
  const type = headers.get("Content-Type") || "";
  if (/^text\/markdown/i.test(type) && !/charset=/i.test(type)) {
    headers.set("Content-Type", "text/markdown; charset=utf-8");
  }

  // The same URL has an HTML and a Markdown representation. Cloudflare's
  // cache ignores Vary: Accept, so pages (HTML and Markdown) stay out of
  // shared caches; assets stay cacheable.
  headers.append("Vary", "Accept");
  if (/^text\/(html|markdown)/i.test(headers.get("Content-Type") || "")) {
    headers.set("Cache-Control", "private, no-cache");
  }

  for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
    headers.set(name, value);
  }
  return response;
}
