## Order For Agents

- Read `.github/copilot-instructions.md` first.
- Read the relevant `SKILL.md` under `.github/skills/` for the task.
- You can use `scripts/setup_supabase_project.sh` to clone Supabase, scaffold
  `supabase-project`, patch `.env`, and run `./utils/generate-keys.sh`.
- You can also use `scripts/generate_supabase_env.sh` to create `.env` if user
  wants to setup Supabase manually.
- For ongoing VPS upkeep (Ubuntu LTS + Supabase behind host-managed Caddy), use the
  `server-maintenance` skill (`.github/skills/server-maintenance/SKILL.md`) to have the
  operator read server/container/proxy state, get ranked update recommendations, and
  follow a safe step-by-step checklist without executing changes.
- For Supabase configure host Caddy by copying `configs/Caddyfile.example` to
  `/etc/caddy/Caddyfile` and reloading Caddy.
- If issues occur, collect `docker compose ps`,
  `docker compose logs --tail 500 <service>`, and `docker inspect <container>`
  before escalating.
