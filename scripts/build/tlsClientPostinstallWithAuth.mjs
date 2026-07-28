// tls-client-node's own postinstall script (node_modules/tls-client-node/scripts/postinstall.js)
// calls api.github.com unauthenticated (60 req/hr per IP). Shared GitHub Actions
// runner IPs exhaust that fast (#7802-style failures). tls-client-node has no
// built-in way to send an auth token, so we wrap it here: monkey-patch global
// fetch to attach GITHUB_TOKEN only for api.github.com requests, then run the
// upstream script unmodified.
const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;

if (token) {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (url, init = {}) => {
    const href = typeof url === "string" ? url : url.href;
    if (href.startsWith("https://api.github.com/")) {
      init = { ...init, headers: { ...init.headers, Authorization: `Bearer ${token}` } };
    }
    return originalFetch(url, init);
  };
}

await import("../../node_modules/tls-client-node/scripts/postinstall.js");
