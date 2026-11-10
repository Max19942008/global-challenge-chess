#!/usr/bin/env bash
# Deploys (or updates) the game server on a fresh Linux VPS over SSH:
# Docker, the repo, secrets, then server + Redis + Postgres + Caddy (HTTPS).
#
#   apps/server/deploy.sh ubuntu@1.2.3.4                 # no domain: https://1.2.3.4.sslip.io
#   apps/server/deploy.sh ubuntu@1.2.3.4 chess.example.uz
#   SSH_KEY=~/Downloads/mykey.pem apps/server/deploy.sh ec2-user@1.2.3.4
#
# Running it again pulls the latest main and rebuilds. Secrets in apps/server/.env on the
# server are created once and kept (changing TOKEN_SECRET would log every player out).
set -euo pipefail

TARGET=${1:?usage: deploy.sh user@host [domain]}
HOST=${TARGET#*@}
DOMAIN=${2:-$HOST.sslip.io}
REPO=${REPO:-https://github.com/Max19942008/global-challenge-chess.git}
DIR=/opt/global-challenge-chess
SSH=(ssh -o StrictHostKeyChecking=accept-new ${SSH_KEY:+-i "$SSH_KEY"} "$TARGET")

echo "==> $TARGET, domain $DOMAIN"
"${SSH[@]}" sudo DOMAIN="$DOMAIN" REPO="$REPO" DIR="$DIR" bash -s <<'REMOTE'
set -euo pipefail

if ! command -v docker >/dev/null; then
  echo "==> installing Docker"
  if command -v apt-get >/dev/null; then
    curl -fsSL https://get.docker.com | sh
  else # Amazon Linux / RHEL family
    dnf install -y docker git
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-$(uname -m)" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  fi
  systemctl enable --now docker
fi
command -v git >/dev/null || (apt-get install -y git 2>/dev/null || dnf install -y git)

# Small instances: a swap file keeps the npm build and Postgres from running out of memory.
if [ "$(free -m | awk '/Mem:/ {print $2}')" -lt 2000 ] && ! swapon --show | grep -q .; then
  echo "==> adding 2 GB swap"
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

if [ -d "$DIR/.git" ]; then
  echo "==> updating code"
  git -C "$DIR" fetch -q origin main && git -C "$DIR" reset -q --hard origin/main
else
  echo "==> cloning $REPO"
  git clone -q "$REPO" "$DIR"
fi

ENV="$DIR/apps/server/.env"
if [ ! -f "$ENV" ]; then
  echo "==> creating secrets"
  umask 077
  printf 'TOKEN_SECRET=%s\nPOSTGRES_PASSWORD=%s\n' "$(openssl rand -hex 32)" "$(openssl rand -hex 16)" > "$ENV"
fi
# The domain may change later (e.g. from sslip.io to a real one); secrets stay.
sed -i '/^DOMAIN=/d' "$ENV" && echo "DOMAIN=$DOMAIN" >> "$ENV"

echo "==> building and starting"
cd "$DIR"
docker compose -f apps/server/docker-compose.yml up -d --build --remove-orphans
docker image prune -f >/dev/null

for i in $(seq 1 30); do
  curl -fsS http://127.0.0.1:8080/health >/dev/null 2>&1 && break
  sleep 2
done
curl -fsS http://127.0.0.1:8080/health && echo
REMOTE

echo "==> checking https://$DOMAIN/health (the first certificate can take a minute)"
for i in $(seq 1 30); do
  if curl -fsS "https://$DOMAIN/health"; then
    echo
    echo "Done. App build:  flutter build appbundle --release --dart-define=SERVER_URL=wss://$DOMAIN"
    exit 0
  fi
  sleep 4
done
echo "HTTPS is not answering yet. Check that ports 80 and 443 are open (AWS: security group / Lightsail firewall)." >&2
exit 1
