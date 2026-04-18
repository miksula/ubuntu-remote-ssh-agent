# Ubuntu VPS Setup Guide

This repository contains practical instructions for setting up a real Ubuntu
(LTS) for self-hosting - with VPS provider such as DigitalOcean or Hetzner.

There is also Copilot-oriented instructions for setting up Supabase self-hosted.

- `.github/` folder contains Copilot-oriented instructions
- `scripts/` folder contains executable automation and install scripts
- `configs/` has example server configurations

## 1. Create The Server In Hetzner Cloud

In the Hetzner Cloud console add your SSH public key during server creation if
possible.

### SSH How-to

Generate the SSH key (asks for filename, like `my_hetzner_key`)

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Wait for server to be created and the IPv4 address to be assigned (like
`65.21.123.45`).

Then connect via terminal

```bash
ssh -i ~/.ssh/my_hetzner_key root@65.21.123.45
```

Simplify with SSH Config (recommended)

Add an entry to ~/.ssh/config so you can connect with a short alias

```bash
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

This repository includes an example Caddy configuration at
[configs/Caddyfile.example](configs/Caddyfile.example). Copy and adapt that file
to `/etc/caddy/Caddyfile` and update the site names and backend addresses to
match your services and domains.

Quick setup

```bash
# copy example to system location
sudo cp configs/Caddyfile.example /etc/caddy/Caddyfile
sudo chown root:root /etc/caddy/Caddyfile

# validate config
sudo caddy validate --config /etc/caddy/Caddyfile

# reload Caddy to apply changes
sudo systemctl reload caddy

# follow logs
sudo journalctl -u caddy -f
```

## 4. Install Supabase

This repository includes an interactive helper script to generate a secure
Supabase `.env` and a skill (`supabase-self-hosting`) that can guide operators.

The skill is based on official documentation
https://supabase.com/docs/guides/self-hosting/docker and can completed manually,
too.

Run the script (interactive, recommended base-env mode):

```bash
scripts/generate_supabase_env.sh --base-env supabase-project/.env --output supabase-project/.env
cd supabase-project
sh ./utils/generate-keys.sh
```

Run non-interactively (uses defaults where available):

```bash
scripts/generate_supabase_env.sh --non-interactive --base-env supabase-project/.env --output supabase-project/.env
cd supabase-project
sh ./utils/generate-keys.sh
```

Calling the `supabase-self-hosting` skill from VS Code Chat

- Open the VS Code Copilot / Chat pane.
- Ask the assistant to `use the supabase-self-hosting skill` or type a natural
  request such as:

```text
Use the supabase-self-hosting skill to configure my Supabase instance
```

- The skill will prompt for operator inputs (it will _not_ echo secrets):
  - `SUPABASE_PUBLIC_URL` (must start with `https://`)
  - `POSTGRES_PASSWORD` (you can provide or request generation)
  - `DASHBOARD_USERNAME` / `DASHBOARD_PASSWORD` (or request generation)
  - whether to use host-managed Caddy (this setup requires it)

- When interacting, answer prompts clearly and provide the full HTTPS domain
  when asked. If you prefer the script, tell the skill you have already
  generated the `.env` and provide its path.

Security notes

- The skill and script never print secrets to the chat or stdout; generated
  secrets are written only to the `.env` file and the file is created with
  `chmod 600`.
- Do not commit the generated `.env` to git. Add it to `.gitignore` or store
  secrets in a secrets manager.

Notes

- **DNS**: Ensure your domain names point to the server IP before enabling.
  TLS—Caddy will obtain certificates automatically for reachable hostnames.
- **Health check**: The example includes a simple health endpoint at
  `handle /up` that responds `OK`. Use `curl` to verify:
  `curl -I https://your-domain.example/up`.
- **Reverse proxy paths**: The example routes `/api/*` to a separate backend.
  Adjust these paths and backend ports to match your apps.
- **Logs**: The example writes access logs to `/var/log/caddy/test-access.log`
  (see the `log` block). You can also use `journalctl -u caddy` for systemd
  logs.
- **Local development**: For local testing, replace production hostnames in the
  Caddyfile with `localhost` and the ports your dev servers use.

### 5. Use VS Code Remote - SSH For Full Agent Visibility

If you want GitHub Copilot to work directly against the remote server, install
the `Remote - SSH` VS Code extension.

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
