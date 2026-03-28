import { setCors, handlePreflight } from '../_cors.js';

export const config = { api: { bodyParser: true } };

export default async function handler(req, res) {
  if (handlePreflight(req, res)) return;
  setCors(req, res);

  try {
    // Reconstruct the Xero API path from the catch-all segments
    const pathSegments = req.query.path;
    const apiPath = Array.isArray(pathSegments) ? pathSegments.join('/') : pathSegments;
    const queryString = Object.entries(req.query)
      .filter(([k]) => k !== 'path')
      .map(([k, v]) => `${k}=${encodeURIComponent(v)}`)
      .join('&');
    const targetUrl = `https://api.xero.com/api.xro/2.0/${apiPath}${queryString ? '?' + queryString : ''}`;

    const headers = {};
    if (req.headers['content-type']) headers['Content-Type'] = req.headers['content-type'];
    if (req.headers.authorization) headers['Authorization'] = req.headers.authorization;
    if (req.headers['xero-tenant-id']) headers['xero-tenant-id'] = req.headers['xero-tenant-id'];
    if (req.headers.accept) headers['Accept'] = req.headers.accept;

    const fetchOpts = { method: req.method, headers };
    if (req.method === 'POST' || req.method === 'PUT') {
      fetchOpts.body = typeof req.body === 'object' ? JSON.stringify(req.body) : req.body;
    }

    const response = await fetch(targetUrl, fetchOpts);
    const responseBody = await response.text();
    res.setHeader('Content-Type', response.headers.get('Content-Type') || 'application/json');
    res.status(response.status).send(responseBody);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
}
