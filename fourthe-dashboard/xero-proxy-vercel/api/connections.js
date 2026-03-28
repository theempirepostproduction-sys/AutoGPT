import { setCors, handlePreflight } from './_cors.js';

export default async function handler(req, res) {
  if (handlePreflight(req, res)) return;
  setCors(req, res);

  try {
    const headers = {};
    if (req.headers.authorization) headers['Authorization'] = req.headers.authorization;
    if (req.headers.accept) headers['Accept'] = req.headers.accept;

    const response = await fetch('https://api.xero.com/connections', {
      method: req.method,
      headers,
    });

    const responseBody = await response.text();
    res.setHeader('Content-Type', response.headers.get('Content-Type') || 'application/json');
    res.status(response.status).send(responseBody);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
}
