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
