---
name: supabase-self-hosting
description: Practical guide for installing, configuring, and operating self-hosted Supabase using the official Docker Compose setup (quick start, secrets, reverse proxy/HTTPS, common operations, troubleshooting).
---

# Supabase — Self-Hosting (Docker)

Short: Steps, configuration snippets, and quick-reference commands to run Supabase with Docker Compose on a VPS or local machine.

When to use

- You want a fully self-hosted Supabase stack (Studio, Auth, Postgres, Realtime, Storage, Functions) using the official Docker Compose setup.

Typical triggers

- install Supabase
- self-host Supabase
- deploy Supabase with Docker
- configure self-hosted Supabase on Ubuntu

Prerequisites

- A Linux server (VPS) or Docker Desktop
- Docker Engine + Docker Compose
- Git, and basic Linux + networking familiarity
- Open ports: 80, 443, 8000 (API), 5432 (Postgres), 6543 (pooled Postgres), and any other service ports your setup exposes

Operator inputs (questions to ask before proceeding)

Before making changes or starting services, ask the operator the following and validate answers where possible. Treat secret values as sensitive — do not echo them in logs or store them in version control.

- **External domain (required):** `SUPABASE_PUBLIC_URL` — Ask: "What is the external HTTPS base URL for Supabase? (e.g. https://supabase.example.com)". Validate starts with `https://`.
- **API external URL (optional):** `API_EXTERNAL_URL` — Ask: "Is `API_EXTERNAL_URL` the same as `SUPABASE_PUBLIC_URL`? If not, provide the full URL." Default to the public URL.
- **Site URL (optional):** `SITE_URL` — Ask: "What is the site redirect URL (e.g. https://app.example.com)?" Default to `SUPABASE_PUBLIC_URL` if not provided.
- **DNS / domain validation (required):** Confirm the external domain is pointed at this host and that ports 80/443 are reachable. This must be checked before TLS issuance or starting Supabase.
 - **Host Caddy is required:** The `scripts/bootstrap.sh` in this workspace installs and enables a system `caddy` service. Ask: "Do you want to use the host-managed Caddy service to terminate TLS and reverse-proxy to Supabase? (yes)" — this skill only supports the host-managed Caddy flow (do not use containerized Caddy/Nginx proxy overlays).
- **Postgres password (required):** `POSTGRES_PASSWORD` — Prompt for a secure value or offer to generate it locally.
- **JWT secret and API keys (required):** `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY` — Ask whether to provide existing keys or let upstream `./utils/generate-keys.sh` generate them. Warn that `SERVICE_ROLE_KEY` must never be exposed publicly.
- **Dashboard credentials (required):** `DASHBOARD_USERNAME` and `DASHBOARD_PASSWORD` — Prompt and validate `DASHBOARD_PASSWORD` contains at least one letter.
- **MinIO / Storage secrets (optional):** `MINIO_ROOT_PASSWORD`, `S3_PROTOCOL_ACCESS_KEY_ID`, `S3_PROTOCOL_ACCESS_KEY_SECRET` — Ask if Storage will use MinIO or external S3 and collect credentials accordingly.
- **Email / Logflare tokens (optional):** `SMTP_*`, `LOGFLARE_*` — Offer to collect or leave blank for later configuration.

Interactive flow

1. Ask for `SUPABASE_PUBLIC_URL` and verify DNS by recommending the operator run a DNS check (or do it for them if given the domain). Ensure the domain resolves to this host and ports 80/443 are reachable before attempting TLS issuance. Make it clear that DNS and reverse-proxy/TLS are prerequisites outside the helper script.
2. Ask whether to generate the non-overlapping secrets automatically or accept operator-provided values. If generation is chosen, run secure generation commands and present only the storage location (never print secrets to logs).
 3. Create or verify `supabase-project` using `scripts/setup_supabase_project.sh` where possible. Note that this helper bootstraps the Supabase project and does not configure external DNS, Caddy, or TLS.
 4. Run upstream `./utils/generate-keys.sh` so the six overlapping auth/internal keys come from Supabase's source of truth.
 5. Patch/override `supabase-project/.env` using `scripts/generate_supabase_env.sh --base-env supabase-project/.env --output supabase-project/.env` (so operator-provided non-overlapping inputs are set last).
 6. Summarize the collected configuration (listing non-secret fields and which values were generated) and ask for confirmation before starting services.
 7. Configure the host-managed Caddy service by placing your site config in `/etc/caddy/Caddyfile` (or edit `configs/Caddyfile.example`) and reload Caddy.
    - Do NOT attempt to start a containerized Caddy/Nginx proxy overlay on the same host (for example: do not run `docker compose -f docker-compose.yml -f docker-compose.nginx.yml up -d`).
    - The host Caddy should reverse-proxy to the local Supabase gateway on `127.0.0.1:8000`.

Example confirmation prompt text the skill should use:

  "I will provision `supabase-project` using `scripts/setup_supabase_project.sh`, run `./utils/generate-keys.sh` for the auth/internal keys, then patch `supabase-project/.env` with `scripts/generate_supabase_env.sh --base-env supabase-project/.env --output supabase-project/.env` (non-overlapping inputs last), and then start Supabase using `docker compose up -d`. I will also remind you that DNS, host-managed Caddy, and TLS are required separately and are not configured by the helper script. Proceed? (yes/no)"

If the operator answers `no`, abort and provide instructions for manual review and next steps.

Quick start (minimal)

```bash
# Preferred: use the repository helper script to scaffold the Supabase project
# Note: this bootstraps the local Supabase project only; DNS/Caddy/TLS are still required separately.
scripts/setup_supabase_project.sh

# Then start the stack
cd supabase-project
docker compose pull
docker compose up -d
# check services
docker compose ps
```

Generate and manage secrets

- Never use placeholder values from `.env.example` in production.
- You can use `scripts/setup_supabase_project.sh` to clone upstream source, build `supabase-project`, generate auth/internal keys, and then patch `.env` (non-overlapping inputs).
- You can also run the included generator directly to produce only the non-overlapping operator inputs:

```bash
scripts/generate_supabase_env.sh --base-env supabase-project/.env --output supabase-project/.env
cd supabase-project
sh ./utils/generate-keys.sh
# review .env after it runs and replace/commit carefully (do NOT commit secrets)
```

Important env vars (examples)

- `POSTGRES_PASSWORD` — DB passwords (generated by `scripts/generate_supabase_env.sh` or operator-provided)
- `DASHBOARD_USERNAME`, `DASHBOARD_PASSWORD` — dashboard access (generated by `scripts/generate_supabase_env.sh` or operator-provided)
- `MINIO_ROOT_PASSWORD` — storage root password (generated by `scripts/generate_supabase_env.sh` or operator-provided)
- `SUPABASE_PUBLIC_URL`, `API_EXTERNAL_URL`, `SITE_URL` — set to your HTTPS domain (handled by `scripts/generate_supabase_env.sh`)
- `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, `SECRET_KEY_BASE`, `VAULT_ENC_KEY`, `PG_META_CRYPTO_KEY` — generated by upstream `./utils/generate-keys.sh`

Reverse proxy & HTTPS (recommended)

This setup assumes you will use the host-managed Caddy service (systemd) installed by `scripts/bootstrap.sh` to terminate TLS and reverse-proxy to the Supabase API gateway on `127.0.0.1:8000`.

Configure host Caddy by editing `/etc/caddy/Caddyfile` or adapting `configs/Caddyfile.example`. Example minimal site block:

```
your-domain.example.com {
  encode zstd gzip
  reverse_proxy 127.0.0.1:8000
}
```

Validate and reload Caddy:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
sudo journalctl -u caddy -f
```

After configuring host Caddy, update `.env`:
  - `SUPABASE_PUBLIC_URL=https://your-domain`
  - `API_EXTERNAL_URL=https://your-domain`
  - `SITE_URL=https://your-domain`

Verify TLS: `curl -I https://your-domain/auth/v1/` should return a `401` when reachable.

Ports and access

- API gateway: `:8000` (Kong) — public via reverse proxy
- Postgres: `:5432` (session port), pooled transactional port `:6543` via Supavisor
- Functions: `http://your-domain:8000/functions/v1/<name>`
- Storage: routed by API gateway (or directly to container for large file transfers)

Starting, stopping, updating

```bash
# start
docker compose up -d
# stop
docker compose down
# update images then restart
docker compose pull
docker compose down
docker compose up -d
```

Backups & uninstall (data-destructive)

- To uninstall and remove volumes (destroys DB/storage):

```bash
docker compose down -v
rm -rf volumes/db/data
rm -rf volumes/storage
```

Troubleshooting tips

- If a container isn't `Up`/healthy: inspect logs
  - `docker compose logs <service>`
- Health check: `curl -I https://your-domain/up` (if present in your proxy config)
- Realtime (WebSockets) issues: ensure reverse proxy supports Upgrade/Connection headers (Caddy handles this automatically)
- TLS failures: check ports 80/443, DNS records, and proxy logs
- Change DB password: `sh ./utils/db-passwd.sh` then `docker compose up -d --force-recreate`

Troubleshooting Playbook

Below are quick, repeatable checks and fixes for common container/service issues.

- **Container exits / Crashloop**: gather recent logs and restart the service.

```bash
docker compose ps
docker compose logs --tail 200 <service>
docker compose restart <service>
docker compose up -d --force-recreate <service>
```

- **Database init / DB errors**: inspect `db` logs, verify env and volume permissions.

```bash
docker compose logs --tail 200 db
ls -la volumes/db
# check POSTGRES_PASSWORD in .env and that the initial migration scripts ran
```

- **Auth / PostgREST errors (401/403/500)**: confirm `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, and `SUPABASE_PUBLIC_URL` are set correctly in `.env` and that Kong is routing correctly.

```bash
docker compose logs --tail 200 api kong
# verify .env values (do NOT echo secrets to public logs)
```

- **Kong / Gateway 502 / 504**: check Kong logs and the upstream service (e.g., `studio`, `rest`, `realtime`).

```bash
docker compose logs --tail 200 kong
docker compose logs --tail 200 <upstream-service>
```

- **Realtime / WebSocket failures**: ensure your reverse proxy supports WebSocket upgrades and check Realtime logs.

```bash
docker compose logs --tail 200 realtime
# If using nginx, ensure `proxy_set_header Upgrade` and `proxy_set_header Connection` are present
```

- **Functions returning 500 or not found**: inspect `functions` logs, verify function file path and restart functions worker.

```bash
docker compose logs --tail 200 functions
docker compose restart functions --no-deps
```

- **Storage upload / permission issues**: check Storage and MinIO logs, confirm `MINIO_ROOT_PASSWORD` and S3 keys are set.

```bash
docker compose logs --tail 200 storage
docker compose logs --tail 200 minio
df -h
```

- **Image pull failures / network problems**: run `docker compose pull` to surface errors and check network/DNS.

```bash
docker compose pull
```

- **Out of disk space**: clean up unused images/volumes and grow disk if needed.

```bash
docker system prune --volumes --force
df -h
```

- **Quick container debug (exec)**: run a shell inside a container to inspect runtime files.

```bash
docker compose exec <service> /bin/sh
# or for postgres: docker compose exec db psql -U postgres -d postgres
```

If these steps don't resolve the issue, collect:
- `docker compose ps` output
- `docker compose logs --tail 500` for affected services
- `docker inspect <container>` for runtime metadata

Attach those outputs when asking for help and specify which services are failing and any recent config changes.

Functions (edge)

- Default example lives at `volumes/functions/hello/index.ts`
- Add functions under `volumes/functions/<name>/index.ts` and restart functions service:

```bash
docker compose restart functions --no-deps
```

- Inside functions, use `SUPABASE_URL` (internal) and `SUPABASE_PUBLIC_URL` (external) appropriately.

Storage

- Storage is S3-compatible and stores metadata in Postgres.
- Use the storage API (see reference) to create buckets, upload, generate presigned URLs, and manage objects.

Useful commands (quick reference)

- `docker compose ps` — list containers
- `docker compose logs <service>` — view logs
- `docker compose up -d` — start
- `docker compose down -v` — stop and remove volumes (destructive)
- `sh ./utils/generate-keys.sh` — generate keys
- `sh ./utils/db-passwd.sh` — rotate DB password

When to escalate / pointers

- For high-availability and production-scale deployments, consider splitting services onto multiple hosts, using managed Postgres, and scaling Realtime/Storage independently.

References

- Official guide: https://supabase.com/docs/guides/self-hosting/docker
- Reverse proxy & HTTPS: https://supabase.com/docs/guides/self-hosting/self-hosted-proxy-https
- Auth keys & secret guidance: https://supabase.com/docs/guides/self-hosting/self-hosted-auth-keys
- Functions: https://supabase.com/docs/guides/self-hosting/self-hosted-functions
- Storage reference: https://supabase.com/docs/reference/self-hosting-storage/introduction

If you want, I can also:
- Produce a short `docker-compose` overlay sample for `Caddy` or `Nginx` (only if you are NOT using the host-managed Caddy from this repo)
- Create a ready-to-run `.env` template that excludes secrets but documents required fields
- Add troubleshooting playbook entries for common container errors
