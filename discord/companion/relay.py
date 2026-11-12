"""Send Chillan events to the hidden raw Discord channel (the bot does the rest)."""
import json
import time
import urllib.error
import urllib.request

PREFIX = "CHILLAN1 "


def post(webhook_url, payload_json, timeout=10):
    """Post one event. Returns True when Discord accepted it. Retries once on rate limits."""
    body = json.dumps({"content": PREFIX + payload_json, "username": "Chillan relay",
                       "allowed_mentions": {"parse": []}}).encode("utf-8")
    for _ in range(4):
        req = urllib.request.Request(webhook_url + ("&" if "?" in webhook_url else "?") + "wait=true",
                                     data=body, method="POST",
                                     headers={"Content-Type": "application/json", "User-Agent": "ChillanCompanion/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return 200 <= r.status < 300
        except urllib.error.HTTPError as e:
            if e.code == 429:
                try:
                    wait = float(json.loads(e.read().decode()).get("retry_after", 1))
                except Exception:
                    wait = 1.0
                time.sleep(min(wait, 10) + 0.1)
                continue
            return False
        except Exception:
            time.sleep(1)
    return False
