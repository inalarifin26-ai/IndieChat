/**
 * Small in-memory fixed-window rate limiter (no dependency). Good for a
 * single-process deployment; behind several instances, swap the Map for a
 * shared store (Redis) — the middleware contract stays the same.
 *
 * Disabled automatically inside `node --test` runs (NODE_TEST_CONTEXT is set
 * by the test runner) unless RATE_LIMIT_FORCE=1, so ordinary test files that
 * register dozens of users are not throttled. A limiter created with an
 * explicit `enabled` option ignores that heuristic.
 */
const insideTestRun = () => !!process.env.NODE_TEST_CONTEXT && process.env.RATE_LIMIT_FORCE !== '1';

function createLimiter({ windowMs, max, keyFn, message = 'Too many attempts. Please try again later.', skipSuccessful = false, enabled }) {
  const hits = new Map(); // key -> { count, resetAt }
  const sweep = setInterval(() => {
    const now = Date.now();
    for (const [k, v] of hits) if (v.resetAt <= now) hits.delete(k);
  }, Math.min(windowMs, 60_000));
  sweep.unref();

  const middleware = (req, res, next) => {
    const on = enabled !== undefined ? enabled : !insideTestRun();
    if (!on) return next();
    const key = keyFn(req);
    const now = Date.now();
    let entry = hits.get(key);
    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + windowMs };
      hits.set(key, entry);
    }
    if (entry.count >= max) {
      const retry = Math.max(1, Math.ceil((entry.resetAt - now) / 1000));
      res.set('Retry-After', String(retry));
      return res.status(429).json({ error: message, retryAfterSeconds: retry });
    }
    entry.count++;
    // Successful requests (e.g. a correct login) should not eat the allowance of failed ones.
    if (skipSuccessful) res.on('finish', () => { if (res.statusCode < 400 && entry.count > 0) entry.count--; });
    next();
  };
  middleware.reset = () => hits.clear();
  return middleware;
}

const clientKey = (req, extra = '') => `${req.ip || 'unknown'}|${String(extra).toLowerCase().slice(0, 64)}`;

module.exports = { createLimiter, clientKey };
