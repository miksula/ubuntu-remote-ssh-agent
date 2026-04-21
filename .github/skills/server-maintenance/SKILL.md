---
name: server-maintenance
description: Operator-guided maintenance assistant for Ubuntu LTS VPS running Supabase in Docker behind host-managed Caddy. The skill reads server state, recommends safe updates, and guides the operator step-by-step without executing changes.
---

# Server Maintenance — Ubuntu + Supabase (Operator-Led)

Short: Checks OS/Docker/Caddy/Supabase state, proposes updates, and guides operator execution.

When to use
- Regularly scheduled maintenance (weekly/monthly) for Ubuntu + Docker + Supabase.
- After planned infrastructure changes (DNS/domain changes, Caddy changes, disk expansion).
- Before business-critical events (but still behind a maintenance window).

Scope / Non-goals
- This skill does NOT run updates or restarts on your behalf.
- This skill does NOT manage secrets.
- This skill assumes you follow this repo’s pattern: host-managed Caddy (systemd) and Supabase via `docker compose`.

Prerequisites
- You have SSH access to the VPS.
- Docker Engine + Docker Compose are installed.
- The Supabase stack is running with a compose project directory (commonly `supabase-project/`).
- Host-managed Caddy is installed and enabled.

Operator inputs (ask first)
- **Compose project directory:** What is the path to the Supabase compose project on the VPS? (e.g. `/home/admin/supabase-project`)
- **Maintenance cadence:** Are you doing `security-only` maintenance or `full` maintenance (OS + Docker + Supabase)?
- **Operator confirmation:** What maintenance window should the plan assume? (now / tonight / scheduled)
- **Backups posture:** Do you have a recent working backup (Postgres and storage, if applicable)? (yes/no)
- **Domain routing:** What is the external domain used for Supabase public HTTPS (used for health checks)?

Interactive flow (read state → recommend → guide)
1. **Pre-flight: verify routing and basic health (no changes).**
   - Ask the operator to run and paste the results of:
     - `df -h`
     - `systemctl status caddy --no-pager`
     - `curl -I https://<domain>/auth/v1/`
     - `uname -r`
   - Expected:
     - `curl` should generally return an HTTP status from Supabase (401 is acceptable; 502/timeout indicates proxy/TLS/gateway issues).

2. **OS update state (recommend, do not apply).**
   - Ask the operator to run and paste:
     - `sudo apt update`
     - `apt list --upgradable | head -n 50`
     - Check reboot requirement: `test -f /var/run/reboot-required && echo REBOOT_REQUIRED || echo NO_REBOOT_REQUIRED`
   - The skill should classify OS actions into:
     - Urgent: security updates available, reboot required
     - Recommended: updates available, no reboot required
     - None: system already up to date

3. **Docker + disk hygiene state (recommend, do not apply).**
   - Ask the operator to run and paste:
     - `docker version`
     - `docker ps --format '{{.Names}}\t{{.Status}}'`
     - `docker system df`
     - From compose project: `docker compose ps` (run inside the compose directory)
     - `docker images --format '{{.Repository}}:{{.Tag}}\t{{.ID}}' | head -n 50` (for context)

4. **Caddy + TLS state.**
   - Ask the operator to run and paste:
     - `sudo journalctl -u caddy --since "24 hours ago" --no-pager | tail -n 200`
   - The skill should recommend:
     - Reload/validate after any `.env`/compose changes affecting routes
     - Address TLS renewal failures urgently

5. **Supabase health state (recommend, do not apply).**
   - Ask the operator to run and paste:
     - `docker compose logs --tail 200 api kong realtime storage minio db studio functions 2>/dev/null || true`
     - If services differ, instruct operator to run logs for the relevant ones.
   - The skill should recommend:
     - If containers are unhealthy/crashing: pause restarts until root cause is identified
     - If healthy: proceed to update planning

6. **Update recommendations (ranked).**
   - Based on the gathered state, the skill outputs a plan with three tiers:
     - Urgent: security updates, reboot required, TLS/proxy breakage, unhealthy containers
     - Recommended: Docker/Compose updates, Supabase image refresh, disk cleanup if risk
     - Optional: deeper operational tasks (backup verification drills, log retention policy)

7. **Operator-led change plan (with explicit confirmation gates).**
   - Before the operator takes any risky action, ask for a single explicit confirmation:
     - “Proceed with the update steps in the order listed below? (yes/no)”

   - If the operator answers `yes`, the skill provides copy-pasteable checklists.

   OS updates checklist (operator runs)
   - Run OS security upgrades (preferred: unattended or manual security upgrade flow)
     - Example operator command guidance:
       - `sudo apt update && sudo apt install -y unattended-upgrades`
       - Then apply security updates (operator chooses preferred method)
       - Reboot if required
   - Verification after reboot:
     - `systemctl status caddy --no-pager`
     - `curl -I https://<domain>/auth/v1/`

   Docker/Compose updates checklist (operator runs)
   - Update Docker Engine and/or Compose plugin following your system’s official method.
   - If Docker changes require reboot/service restart, do it before compose operations.
   - Verification:
     - `docker compose ps`

   Supabase updates checklist (operator runs)
   - In the compose directory:
     - `docker compose pull`
     - `docker compose up -d`
     - `docker compose ps`
   - Validation:
     - `curl -I https://<domain>/auth/v1/`
     - `docker compose logs --tail 200 api kong realtime storage minio db studio functions 2>/dev/null || true`

   Caddy checklist (operator runs)
   - If you changed `/etc/caddy/Caddyfile`:
     - `sudo caddy validate --config /etc/caddy/Caddyfile`
     - `sudo systemctl reload caddy`
   - Always verify after Supabase restart:
     - `curl -I https://<domain>/auth/v1/`

8. **Post-maintenance “health report” (operator confirms).**
   - Ask the operator to confirm green checks:
     - `curl -I https://<domain>/auth/v1/` is reachable
     - `docker compose ps` shows expected containers running/healthy (or at least not crashlooping)
     - `systemctl status caddy` shows no errors
     - No rapid increase in recent caddy log errors

Secrets & safety
- Never ask for or request DB passwords, JWT secrets, or service role keys.
- When inspecting `.env`, only ask the operator to confirm whether keys are set (non-empty), not to paste values.
- Recommend `.env` remains private and not committed.

Troubleshooting shortcuts (operator-led)
- If `curl` fails with TLS/proxy errors:
  - check caddy logs (`journalctl -u caddy --since ...`)
  - check upstream availability: `curl -I http://127.0.0.1:8000/auth/v1/` (operator runs)
- If containers are unhealthy after updates:
  - instruct operator to run `docker compose logs --tail 200 <service>` for the failing services.
