#!/bin/sh
# Print the default Azure subscription name (empty if none / not logged in).
# Used by the [custom.azure] Starship module. Reads azureProfile.json directly
# instead of calling `az` so it is fast enough to run on prompt redraws.
python3 - <<'PY'
import json, os
base = os.environ.get("AZURE_CONFIG_DIR") or os.path.expanduser("~/.azure")
path = os.path.join(base, "azureProfile.json")
try:
    with open(path, encoding="utf-8-sig") as f:
        data = json.load(f)
    name = next(
        (s["name"] for s in data.get("subscriptions", []) if s.get("isDefault")),
        "",
    )
    if name:
        print(name)
except Exception:
    pass
PY
