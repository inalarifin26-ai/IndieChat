const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const contactsRoutes = require('./routes/contacts');
const agentsRoutes = require('./routes/agents');
const workflowsRoutes = require('./routes/workflows');
const consentRoutes = require('./routes/consent');
const vaultRoutes = require('./routes/vault');
const auditRoutes = require('./routes/audit');
const orchestratorRoutes = require('./routes/orchestrator');
const connectorsRoutes = require('./routes/connectors');
const groupsRoutes = require('./routes/groups');
const searchRoutes = require('./routes/search');

const { securityHeaders, errorHandler } = require('./middleware/security');

/** CORS_ORIGINS="https://a.example,https://b.example" restricts browsers; unset = open (native apps don't use CORS). */
function corsOptions() {
  const allowed = (process.env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean);
  return allowed.length ? { origin: (origin, cb) => cb(null, !origin || allowed.includes(origin)) } : {};
}

const app = express();
app.disable('x-powered-by');
// Behind a reverse proxy set TRUST_PROXY (e.g. "1" or "true") so rate limits see the real client IP.
if (process.env.TRUST_PROXY) app.set('trust proxy', process.env.TRUST_PROXY === 'true' ? true : Number.isNaN(Number(process.env.TRUST_PROXY)) ? process.env.TRUST_PROXY : Number(process.env.TRUST_PROXY));
app.use(cors(corsOptions()));
app.use(securityHeaders);
app.use(express.json({ limit: '256kb' }));

app.get('/health', (_req, res) => res.json({ ok: true, service: 'indie-backend', time: new Date().toISOString() }));

app.use('/auth', authRoutes);
app.use('/contacts', contactsRoutes);
app.use('/agents', agentsRoutes);
app.use('/workflows', workflowsRoutes);
app.use('/consent', consentRoutes);
app.use('/vault', vaultRoutes);
app.use('/audit', auditRoutes);
app.use('/orchestrator', orchestratorRoutes);
app.use('/connectors', connectorsRoutes);
app.use('/groups', groupsRoutes);
app.use('/search', searchRoutes);

app.use((req, res) => res.status(404).json({ error: 'Not found' }));

app.use(errorHandler);

module.exports = app;
