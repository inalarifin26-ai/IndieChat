# Indie — Independent Intelligence

A personal agentic messaging platform: human contacts and autonomous AI
agents live side by side in one messenger, with visual workflow automation,
a consent/approval engine, and a private Personal Vault. Built from the
product spec in `docs/`.

> Personal by default. Consent by design. Autonomous within authority.
> Private by architecture. User-owned workflows. Explicit sharing of results.

## What's in this repo

```
indie_app/       Flutter mobile client (Messages · Agents · Workflows · Vault · More)
indie_backend/   Node.js + SQLite backend (auth, Consent/Permission Engine,
                 Execution Engine with live SSE workflow execution, Personal Vault)
docs/            The original product/engineering spec this was built from
```

Each package has its own README with full setup instructions:

- **[indie_backend/README.md](indie_backend/README.md)** — start here; the
  app has nothing to talk to without it running.
- **[indie_app/README.md](indie_app/README.md)** — Flutter client setup,
  including how to point it at the backend from an emulator/simulator/device.

## Quick start

```bash
# Terminal 1 — backend
cd indie_backend
npm install
cp .env.example .env
npm start                     # http://localhost:4000

# Terminal 2 — Flutter app (after `flutter create` scaffolding — see its README)
cd indie_app
flutter pub get
dart run flutter_launcher_icons
flutter run --dart-define=API_BASE_URL=http://localhost:4000   # iOS simulator
```

## Status

This is a working MVP, not a finished product. Both READMEs are explicit
about what's real versus simulated (auth, consent, the execution engine and
the Vault are real and tested end-to-end; the AI agents' "thinking" is still
scripted, and there are no real external connectors yet). Read the "What's
real vs. simulated" table in each package's README before treating anything
here as production-ready.

## License

MIT — see [LICENSE](LICENSE). Replace or remove before any public release if
you'd prefer different terms.
