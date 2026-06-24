// Gemma 4 Proxy Worker - permanent URL that forwards to dynamic tunnel
// On restart, update via: npx wrangler secret put TUNNEL_URL --name gemma4-proxy

export default {
  async fetch(request, env) {
    const target = env.TUNNEL_URL || "http://localhost:8080";
    const url = new URL(request.url);
    const targetUrl = new URL(target);

    url.host = targetUrl.host;
    url.protocol = targetUrl.protocol;
    url.port = targetUrl.port;

    const proxyUrl = url.toString();
    const proxyRequest = new Request(proxyUrl, request);
    proxyRequest.headers.set("Host", targetUrl.host);
    proxyRequest.headers.set("X-Forwarded-Host", request.headers.get("Host") || "");

    return fetch(proxyRequest);
  }
};
