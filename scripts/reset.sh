#!/usr/bin/env bash
# reset.sh — Revert the lab to its initial clean state
#   ./reset.sh                # opentofu taint & reapply (Azure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"
PROVIDER="${1:-opentofu}"

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${RED}⚠  This will destroy your current progress.${RESET}"
read -p "Continue? [y/N] " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

case "$PROVIDER" in
  opentofu|azure)
    echo -e "${YELLOW}[•] Checking for OpenTofu${RESET}"
    if command -v otf &>/dev/null; then
      TF_CMD=otf
    elif command -v terraform &>/dev/null; then
      TF_CMD=terraform
    else
      echo "ERROR: OpenTofu CLI not found. Install from https://opentofu.org/" >&2
      exit 1
    fi

    echo -e "${YELLOW}[•] Tainting VM for redeployment …${RESET}"
    cd "$LAB_DIR/infrastructure/terraform"
    "$TF_CMD" taint azurerm_linux_virtual_machine.target
    echo -e "${YELLOW}[•] Reapplying OpenTofu …${RESET}"
    "$TF_CMD" apply -auto-approve
    echo -e "${GREEN}[✓] VM rebuilt on Azure.${RESET}"
    ;;
  *)
    echo "ERROR: Unknown provider '$PROVIDER'" >&2
    echo "Usage: $0 [opentofu|azure]" >&2
    exit 1
    ;;
esac

echo ""
echo "Lab is back to its initial state.  Reconnect via SSH."
