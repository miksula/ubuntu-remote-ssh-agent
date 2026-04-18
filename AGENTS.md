## Order For Agents

- Read `.github/copilot-instructions.md` first.
- Read the relevant `SKILL.md` under `.github/skills/` for the task.
- You can use `scripts/generate_supabase_env.sh` to create `.env` if user wants
  to setup Supabase
- For Supabase configure host Caddy by copying `configs/Caddyfile.example` to
  `/etc/caddy/Caddyfile` and reloading Caddy.
- If issues occur, collect `docker compose ps`,
  `docker compose logs --tail 500 <service>`, and `docker inspect <container>`
  before escalating.
