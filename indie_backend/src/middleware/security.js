/** Baseline response headers for a JSON API that carries private data. */
function securityHeaders(_req, res, next) {
  res.set({
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'no-referrer',
    'Cache-Control': 'no-store', // never let a proxy or browser cache someone's messages
  });
  next();
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, _req, res, _next) {
  if (err && err.type === 'entity.parse.failed') return res.status(400).json({ error: 'Malformed JSON body' });
  if (err && err.type === 'entity.too.large') return res.status(413).json({ error: 'Request body too large' });
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
}

/** Returns an error string when `value` exceeds `max` characters, else null. */
function tooLong(value, max, label) {
  return value !== undefined && value !== null && String(value).length > max ? `${label} is too long (max ${max} characters)` : null;
}

module.exports = { securityHeaders, errorHandler, tooLong };
