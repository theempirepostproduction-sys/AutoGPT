// Shared CORS helper for all Xero proxy routes

const ALLOWED_ORIGINS = [
  'https://hq.fourthe.com.au',
  'http://localhost:3000',
  'http://localhost:8080',
  'http://127.0.0.1:3000',
];

export function getCorsHeaders(origin) {
  const allowed = ALLOWED_ORIGINS.find(o => origin && origin.startsWith(o)) || ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, xero-tenant-id, Accept',
    'Access-Control-Max-Age': '86400',
  };
}

export function setCors(req, res) {
  const cors = getCorsHeaders(req.headers.origin);
  Object.entries(cors).forEach(([k, v]) => res.setHeader(k, v));
}

export function handlePreflight(req, res) {
  if (req.method === 'OPTIONS') {
    setCors(req, res);
    res.status(204).end();
    return true;
  }
  return false;
}
