import { setCors, handlePreflight } from './_cors.js';

export const config = { api: { bodyParser: true } };

export default async function handler(req, res) {
  if (handlePreflight(req, res)) return;
  setCors(req, res);

  try {
    // Build Basic auth header from client_id + client_secret
    const clientId = req.body?.client_id || '';
    const clientSecret = process.env.XERO_CLIENT_SECRET || '';
    const basicAuth = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');

    const headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': `Basic ${basicAuth}`,
    };

    // Reconstruct body as URL-encoded, excluding client_id (sent via Basic auth)
    let body = undefined;
    if (req.method === 'POST') {
      const params = typeof req.body === 'object' ? { ...req.body } : {};
      delete params.client_id; // already in Basic auth header
      body = new URLSearchParams(params).toString();
    }

    const response = await fetch('https://identity.xero.com/connect/token', {
      method: req.method,
      headers,
      body,
    });

    const responseBody = await response.text();
    res.setHeader('Content-Type', response.headers.get('Content-Type') || 'application/json');
    res.status(response.status).send(responseBody);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
}
