#!/usr/bin/env bash
# Pull the latest bot code and restart it.
set -euo pipefail
git -C /opt/chillan pull --ff-only
/opt/chillan/.venv/bin/pip install -q -r /opt/chillan/discord/bot/requirements.txt
systemctl restart chillan-bot
systemctl --no-pager status chillan-bot | head -6
