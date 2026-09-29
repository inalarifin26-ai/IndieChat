require('dotenv').config();
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

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.json({ ok: true, service: 'indie-backend', time: new Date().toISOString() }));

app.use('/auth', authRoutes);
app.use('/contacts', contactsRoutes);
app.use('/agents', agentsRoutes);
app.use('/workflows', workflowsRoutes);
app.use('/consent', consentRoutes);
app.use('/vault', vaultRoutes);
app.use('/audit', auditRoutes);
app.use('/orchestrator', orchestratorRoutes);

app.use((req, res) => res.status(404).json({ error: 'Not found' }));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`Indie backend listening on http://localhost:${PORT}`);
});
