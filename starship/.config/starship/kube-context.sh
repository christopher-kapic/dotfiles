#!/bin/sh
# Print the current kubernetes context name (empty if none). Used by the
# [custom.kube] Starship module. Parses the kubeconfig directly (fast enough to
# run on prompt redraws) and falls back to `kubectl` for multi-file KUBECONFIG.
cfg="${KUBECONFIG:-$HOME/.kube/config}"
case "$cfg" in
  *:*) ;; # multiple files merged: defer to kubectl below
  *)
    if [ -f "$cfg" ]; then
      ctx=$(sed -n 's/^current-context:[[:space:]]*//p' "$cfg" | tail -1 |
            sed "s/[[:space:]]*$//; s/^[\"']//; s/[\"']$//")
      if [ -n "$ctx" ]; then
        printf '%s' "$ctx"
        exit 0
      fi
    fi ;;
esac
command -v kubectl >/dev/null 2>&1 && kubectl config current-context 2>/dev/null
