// Cloudflare Worker: Xero CORS Proxy for FOURTHE Command Centre
// Deploy to Cloudflare Workers at: https://fourthe-xero-proxy.workers.dev
//
// This worker proxies requests to Xero's API endpoints because Xero
// does not support browser CORS for token exchange or API calls.

const ALLOWED_ORIGINS = [
  'https://hq.fourthe.com.au',
  'http://localhost:3000',
  'http://localhost:8080',
  'http://127.0.0.1:3000',
];

function corsHeaders(request) {
  const origin = request.headers.get('Origin') || '';
  const allowedOrigin = ALLOWED_ORIGINS.find(o => origin.startsWith(o)) || ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, xero-tenant-id, Accept',
    'Access-Control-Max-Age': '86400',
  };
}

export default {
  async fetch(request, env) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    const url = new URL(request.url);
    const path = url.pathname;
    let targetUrl;

    if (path === '/token') {
      // Token exchange / refresh
      targetUrl = 'https://identity.xero.com/connect/token';
    } else if (path === '/connections') {
      // Get tenant connections
      targetUrl = 'https://api.xero.com/connections';
    } else if (path.startsWith('/api/')) {
      // Xero API calls - strip /api prefix
      targetUrl = 'https://api.xero.com/api.xro/2.0' + path.substring(4) + url.search;
    } else {
      return new Response(JSON.stringify({ error: 'Unknown endpoint' }), {
        status: 404,
        headers: { ...corsHeaders(request), 'Content-Type': 'application/json' },
      });
    }

    // Forward the request
    const headers = new Headers();
    // Copy relevant headers
    for (const [key, value] of request.headers.entries()) {
      if (['content-type', 'authorization', 'xero-tenant-id', 'accept'].includes(key.toLowerCase())) {
        headers.set(key, value);
      }
    }

    const fetchOpts = {
      method: request.method,
      headers,
    };

    // Forward body for POST/PUT
    if (request.method === 'POST' || request.method === 'PUT') {
      fetchOpts.body = await request.text();
    }

    try {
      const response = await fetch(targetUrl, fetchOpts);
      const responseBody = await response.text();

      return new Response(responseBody, {
        status: response.status,
        headers: {
          ...corsHeaders(request),
          'Content-Type': response.headers.get('Content-Type') || 'application/json',
        },
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 502,
        headers: { ...corsHeaders(request), 'Content-Type': 'application/json' },
      });
    }
  },
};
