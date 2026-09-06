# Roadmap to a paid product

Decision log (2026-09): **open-core** — this repo stays the MIT-licensed core;
proprietary commercial code (cloud features, licensing server) will live in a
separate private repository. Brand: **Burnrate**. Repo: public.

Deferred by choice for now — in dependency order:

## 1. Apple Developer account (in progress, owner)

- [ ] Enroll as an organization (needs D-U-N-S number if a company entity
      exists; otherwise enroll as individual and migrate later — migration
      requires Support contact, do it before selling).
- [ ] Put the team ID into `project.yml` → `DEVELOPMENT_TEAM` (currently an
      empty placeholder; `make build`/`make test` work without it).
- [ ] Create the "Developer ID Application" certificate, export the .p12.

## 2. Release pipeline enablement

- [ ] Set repo **variable** `RELEASES_ENABLED=true` and `APPLE_TEAM_ID`.
- [ ] Set repo **secrets** (full list + instructions in
      `.github/workflows/release.yml`): cert p12, notary credentials, Sparkle
      EdDSA key pair.
- [ ] `xcrun sparkle-generate-keys`; put the public key in `project.yml`
      (`SUPublicEDKey`) and flip `SUEnableAutomaticChecks`/`SUAutomaticallyUpdate`
      back to true.
- [ ] Point `SUFeedURL` at the real feed host; set `DOWNLOAD_PREFIX`.
- [ ] First tagged release (`v1.4.1`) verifies archive → notarize → staple →
      spctl → appcast end-to-end on CI.

## 3. Commercial layer (later, separate private repo)

- [ ] Pick a merchant of record (Paddle / Lemon Squeezy / FastSpring) — they
      handle global VAT/sales tax and issue license keys; a plain Stripe
      account means registering for VAT in every market you sell to.
- [ ] In-app entitlement check: license key entry + signed-receipt validation,
      offline-tolerant (the notch must keep working on a plane).
- [ ] Decide the free/pro split (candidate: all local readings free; cloud
      features — history, alerts, team dashboards — paid).
- [ ] Legal docs before first sale: EULA, Terms of Service, Privacy Policy,
      and a DMCA contact. Add a Settings → Acknowledgements screen listing the
      MIT notices (upstream + Sparkle).

## 4. Trademark & brand

- [ ] Formal trademark search for "Burnrate" (USPTO TESS, EUIPO, UKIPO) before
      spending on marketing; register if clear.
- [ ] Buy the domain; replace `.invalid` placeholders in `project.yml`,
      Makefile `DOWNLOAD_PREFIX`, and `release.yml`.
- [ ] Replace the inherited app icon set (`AppIcon`, `MenuBarIcon`) with
      original art — the current ones are the upstream author's.

## 5. Code health (tracked from the fork audit)

- [ ] Pin or validate the Antigravity language-server certificate in
      `LocalhostTrust.swift` instead of trusting any loopback certificate.
- [ ] Vendor logo assets (grok's official mark etc.): replace with neutral
      glyphs or get permission before any public marketing uses them.
- [ ] Remove or restore a producer for the orphaned `UsageBlock` plumbing
      (Codex "blocked until" banner, dead since the usage-endpoint switch).
- [ ] Vendor-ToS review of the undocumented endpoints the providers ride on
      (chatgpt wham/usage, grok gRPC-web, GLM monitor) — acceptable at
      hobby scale, needs a deliberate decision before charging money.
- [ ] Add a CLA (or DCO + assignment) for future contributions so ownership
      never fragments again.
