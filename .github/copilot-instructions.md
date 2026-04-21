<!-- Copilot / Agent instructions for this repository -->

# Copilot / Agent Instructions

Purpose

- Provide concise, actionable guidance for Copilot/Chat agents working with this repository.
- Explain how to invoke the bundled skills, run helper scripts, and follow security rules around secrets.

Where things live

- Skills: `.github/skills/` — each skill is a folder containing a `SKILL.md` used by agent-run workflows.
- Examples and config: `configs/` (includes `Caddyfile.example`).
- Scripts: `scripts/` — automation helpers such as `bootstrap.sh` and `generate_supabase_env.sh`.

Quick actions for agents

- For a repeatable Supabase install flow, use `scripts/setup_supabase_project.sh` to clone upstream `supabase`, scaffold `supabase-project`, patch `.env`, and run `./utils/generate-keys.sh`.
- If the operator only needs env generation, run `scripts/generate_supabase_env.sh --base-env supabase-project/.env --output supabase-project/.env` and then `cd supabase-project && sh ./utils/generate-keys.sh`. See README for details.
- To instruct the operator about Caddy: the repository uses a host-managed Caddy (`systemd`) by default; do NOT recommend starting a containerized Caddy overlay on the same host.

How to invoke the `supabase-self-hosting` skill (operator-facing)

1. Open VS Code Copilot / Chat pane.
2. Ask the assistant to `use the supabase-self-hosting skill` or say a natural request like:

```
Use the supabase-self-hosting skill to configure my Supabase instance
```

3. The skill will ask for operator inputs (domain, Postgres password or generate, dashboard credentials, etc.).
   - Always treat secrets as sensitive: do not print them in chat, logs, or commit them.
   - The helper script `scripts/setup_supabase_project.sh` is available for the full Supabase project scaffold. The skill may also call/ask the operator to run `scripts/generate_supabase_env.sh`, followed by `./utils/generate-keys.sh` for the upstream auth/internal keys.

Operator interaction guidance for agents

- Ask one prompt at a time; do not batch multiple secret requests in a single message.
- Validate non-secret fields (e.g., `SUPABASE_PUBLIC_URL` must start with `https://`).
- If operator requests generation, run generation locally and tell the operator where the file was written (do NOT display secrets).
- Ask the operator to confirm before writing `.env` or starting services.

Secrets & safety

- Never echo secrets (API keys, passwords, JWT secrets) in chat or logs.
- Generated secrets should be written to files with restrictive permissions (`chmod 600`) and recommended to be stored in a secrets manager.
- Recommend adding generated `.env` to `.gitignore`.

Running and testing services (advice to operator)

- After creating `supabase-project/.env`:

```bash
cd supabase-project
docker compose pull
docker compose up -d
docker compose ps
```

- Use `docker compose logs <service>` and the troubleshooting playbook in `.github/skills/supabase-self-hosting/SKILL.md` if things fail.

Contributing / updating skills

- To update a skill, edit the `SKILL.md` under `.github/skills/<skill-name>/SKILL.md`.
- If changes are generated programmatically, ensure the frontmatter `name:` and `triggers:` remain accurate.

Notes for maintainers

- The repo bootstrap installs a system `caddy` service. The skill explicitly expects host-managed Caddy; avoid launching containerized proxy overlays unless the operator intentionally disables the system Caddy.
- Keep `configs/Caddyfile.example` in sync with `SKILL.md` instructions.

If in doubt

- Ask the repository owner or open an issue in the repo describing the desired agent behavior and the exact inputs you need.
