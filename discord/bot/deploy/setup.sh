#!/usr/bin/env bash
# One-time setup of the Chillan bot on a fresh Ubuntu server (e.g. Oracle Cloud's free VM).
# Run:  curl -fsSL https://raw.githubusercontent.com/soupcaek/chillan/main/discord/bot/deploy/setup.sh | sudo bash
set -euo pipefail
APP=/opt/chillan
ENV=/etc/chillan-bot.env

apt-get update -y
apt-get install -y git python3 python3-venv

if [ -d "$APP/.git" ]; then
  git -C "$APP" pull --ff-only
else
  git clone --depth 1 https://github.com/soupcaek/chillan.git "$APP"
fi
python3 -m venv "$APP/.venv"
"$APP/.venv/bin/pip" install --upgrade pip
"$APP/.venv/bin/pip" install -r "$APP/discord/bot/requirements.txt"

id -u chillan >/dev/null 2>&1 || useradd --system --home "$APP" --shell /usr/sbin/nologin chillan
mkdir -p /var/lib/chillan
chown chillan:chillan /var/lib/chillan

if [ ! -f "$ENV" ]; then
  echo
  echo "A few values from Discord (see the setup guide):"
  read -rp "Bot token: " TOKEN </dev/tty
  read -rp "Server (guild) ID: " GUILD </dev/tty
  read -rp "Raw channel ID: " RAW </dev/tty
  read -rp "Feed channel ID: " FEED </dev/tty
  cat > "$ENV" <<CONF
DISCORD_TOKEN=$TOKEN
GUILD_ID=$GUILD
RAW_CHANNEL_ID=$RAW
FEED_CHANNEL_ID=$FEED
MAX_EVENT_AGE_HOURS=12
DB_PATH=/var/lib/chillan/chillan.db
CONF
  chmod 600 "$ENV"
fi

cat > /etc/systemd/system/chillan-bot.service <<UNIT
[Unit]
Description=Chillan? Discord bot
After=network-online.target
Wants=network-online.target

[Service]
User=chillan
EnvironmentFile=$ENV
WorkingDirectory=$APP/discord/bot
ExecStart=$APP/.venv/bin/python bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now chillan-bot
sleep 3
systemctl --no-pager status chillan-bot | head -12
echo
echo "Done. Logs: sudo journalctl -u chillan-bot -f    Update later: sudo bash $APP/discord/bot/deploy/update.sh"
