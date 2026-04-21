# Ubuntu VPS Setup Guide

This repository contains practical instructions for setting up a real Ubuntu
(LTS) server for self-hosting with VPS provider such as DigitalOcean or Hetzner.

There is also a Copilot-oriented skill for setting up self-hosted Supabase.

- `.github/` Copilot-oriented instructions
- `scripts/` Automation and install scripts
- `configs/` Example configurations

## 1. Create The Server In Hetzner Cloud

In the Hetzner Cloud console add your SSH public key during server creation if
possible.

### SSH How-to

Generate the SSH key (asks for filename, e.g. `my_hetzner_key`)

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Wait for server to be created and the IPv4 address to be assigned (address
`65.21.123.45` used as an example here).

Then connect via terminal

```bash
ssh -i ~/.ssh/my_hetzner_key root@65.21.123.45
```

Simplify with SSH Config (recommended)

Add an entry to ~/.ssh/config so you can connect with a short alias

```
Host hetzner-1
    HostName 65.21.123.45
    User root
    IdentityFile ~/.ssh/my_hetzner_key
```

Now connect with

```bash
ssh hetzner-1
```

## 2. Run initialization script

Run the initializations script at [scripts/bootstrap.sh](scripts/bootstrap.sh)
to setup the dev box.

Copy the file, or paste this script block:

```bash
#!/usr/bin/env bash
# Minimal Ubuntu VPS bootstrap — dev/testing
# Run as root: bash bootstrap.sh

set -euo pipefail

### System update
export DEBIAN_FRONTEND=noninteractive
apt-get update -q && apt-get upgrade -yq
apt-get install -yq \
  curl wget git unzip ufw fail2ban \
  htop tmux vim \
  build-essential ca-certificates gnupg

### Create a non-root sudo user
NEW_USER="admin"
useradd -m -s /bin/bash "$NEW_USER"
usermod -aG sudo "$NEW_USER"
mkdir -p /home/$NEW_USER/.ssh
cp ~/.ssh/authorized_keys /home/$NEW_USER/.ssh/ 2>/dev/null || true
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
chmod 700 /home/$NEW_USER/.ssh
chmod 600 /home/$NEW_USER/.ssh/authorized_keys 2>/dev/null || true

### Firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 8000/tcp
ufw allow 8080/tcp
ufw allow 5432/tcp
ufw allow 6543/tcp
ufw allow 443/tcp
ufw --force enable

### fail2ban (brute-force protection)
systemctl enable --now fail2ban

### Automatic security updates
apt-get install -yq unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

### Caddy (reverse proxy)
apt-get install -yq debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update -q
apt-get install -yq caddy

systemctl enable --now caddy

### Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker "$NEW_USER"

### Node.js LTS via nvm (per-user)
sudo -u "$NEW_USER" bash -c '
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  source "$NVM_DIR/nvm.sh"
  nvm install --lts
'

### Python + pip
apt-get install -yq python3 python3-pip python3-venv

### Set timezone + locale
timedatectl set-timezone UTC
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

### Done
echo ""
echo "Bootstrap complete. You can log in as: ssh $NEW_USER@YOUR_SERVER_IP"
echo "Then open ports as needed: ufw allow PORT/tcp"
```

## 3. Configure Caddy Server

This repository includes multiple example Caddy configurations. Pick the one
that matches your use case and copy it to `/etc/caddy/Caddyfile`.

- Supabase reverse proxy (API gateway -> `127.0.0.1:8000`):
  [configs/Caddyfile.example](configs/Caddyfile.example)
- Static files / file server:
  [configs/Caddyfile.static-files.example](configs/Caddyfile.static-files.example)
- SPA assets + `/api/*` proxy to Node.js (`127.0.0.1:3000`):
  [configs/Caddyfile.spa-api.example](configs/Caddyfile.spa-api.example)

Quick setup

```bash
# choose one example to copy:
# Supabase
sudo cp configs/Caddyfile.example /etc/caddy/Caddyfile

# Static file server
# sudo cp configs/Caddyfile.static-files.example /etc/caddy/Caddyfile

# SPA + Node.js API proxy
# sudo cp configs/Caddyfile.spa-api.example /etc/caddy/Caddyfile

sudo chown root:root /etc/caddy/Caddyfile

# validate config
sudo caddy validate --config /etc/caddy/Caddyfile

# reload Caddy to apply changes
sudo systemctl reload caddy

# follow logs
sudo journalctl -u caddy -f
```

Notes for the included examples:

- Static files example serves content from `/var/www/site` (set
  `root * /var/www/site` to your directory).
- SPA + Node example serves SPA assets from `/var/www/site` and proxies only
  `/api/*` to `127.0.0.1:3000`.
- Supabase example assumes Supabase gateway is reachable on `127.0.0.1:8000`.

## 4. Install Supabase

This repository supports three Supabase setup paths:

- Manual setup
- Scripted setup with `scripts/setup_supabase_project.sh`
- Agent-assisted setup with the `supabase-self-hosting` skill

Both paths use the same host-managed Caddy reverse proxy from step 3.

### Manual setup

```bash
git clone --depth 1 https://github.com/supabase/supabase
mkdir -p supabase-project
cp -r supabase/docker/* supabase-project/
cp supabase/docker/.env.example supabase-project/.env

scripts/generate_supabase_env.sh --base-env supabase-project/.env --output supabase-project/.env
cd supabase-project
sh ./utils/generate-keys.sh

docker compose pull
docker compose up -d
docker compose ps
```

### Scripted setup

```bash
scripts/setup_supabase_project.sh
```

### Agent-assisted setup

- Open the VS Code Copilot
- Use VS Code "Remote - SSH" / Clone this repo into VPS host
- Ask the assistant to `use the supabase-self-hosting skill`.
- The skill will collect the required operator inputs, patch
  `supabase-project/.env`, run `./utils/generate-keys.sh`, and start the stack.
- The skill assumes host-managed Caddy is already installed and running from
  `scripts/bootstrap.sh`.

### Validation

- DNS: make sure your domain points to the server IP before enabling TLS.
- Health: verify the proxy with `curl -I https://your-domain.example/up`.
- Logs: use `sudo journalctl -u caddy -f` for the reverse proxy and
  `docker compose logs <service>` for Supabase services.
- Local development: replace production hostnames in `configs/Caddyfile.example`
  with `localhost` and your local ports.

### 5. Use VS Code Remote - SSH For Full Agent Visibility

For GitHub Copilot to work directly against the remote server, install the
`Remote - SSH` VS Code extension.

Why this matters:

- VS Code opens the remote filesystem directly
- the integrated terminal runs on the server itself
- GitHub Copilot can inspect files, configs, and command output on the remote
  host
- the agent can perform the setup against the real machine instead of only
  editing local documentation

Typical workflow:

1. Install the `Remote - SSH` extension in VS Code.
2. Use `Remote-SSH: Connect to Host...`.
3. Connect to `root@your-server-ip` or your administrative user.
4. Open the server workspace, target directory, or root in the remote session.
5. Open GitHub Copilot Chat in that remote VS Code window.

### 6. Remote files for Copilot (important)

For GitHub Copilot (and Copilot Chat) to inspect this repository while you are
connected with VS Code Remote - SSH, the project files, like .github/ must
physically exist on the remote host and you must open that folder in the remote
session.

In practice this means cloning or copying the repo to a sensible location on the
server (for example `/home/<user>/` or `/workspace/`) and then opening that
folder in the Remote - SSH window so extensions run against the remote
filesystem.

Minimal recommended steps to prepare the remote workspace (run on the server or
in the remote VS Code terminal):

```bash
# clone repo into the remote user's home
git clone https://github.com/miksula/ubuntu-remote-ssh-agent.git ~/ubuntu-remote-ssh-agent
cd ~/ubuntu-remote-ssh-agent

# quick verify
ls -la
```
