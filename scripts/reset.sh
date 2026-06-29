#!/usr/bin/env bash
# reset.sh — Revert the lab to its initial clean state
#   ./reset.sh                # terraform taint & reapply (Azure)
#   ./reset.sh vagrant        # vagrant reload --provision
#   ./reset.sh docker         # replays the Docker provisioning

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"
PROVIDER="${1:-terraform}"

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
  terraform|azure)
    echo -e "${YELLOW}[•] Tainting VM for redeployment …${RESET}"
    cd "$LAB_DIR/infrastructure/terraform"
    terraform taint azurerm_linux_virtual_machine.target
    echo -e "${YELLOW}[•] Reapplying Terraform …${RESET}"
    terraform apply -auto-approve
    echo -e "${GREEN}[✓] VM rebuilt on Azure.${RESET}"
    ;;
  docker)
    echo -e "${YELLOW}[•] Tearing down old container …${RESET}"
    docker compose down -v 2>/dev/null || true
    echo -e "${YELLOW}[•] Recreating container …${RESET}"
    docker compose build --no-cache target 2>/dev/null
    docker compose up -d target
    echo -e "${GREEN}[✓] Clean container started.${RESET}"
    ;;
  vagrant)
    echo -e "${YELLOW}[•] Destroying and re-provisioning VM …${RESET}"
    vagrant destroy -f
    vagrant up --provision
    echo -e "${GREEN}[✓] VM re-provisioned.${RESET}"
    ;;
  *)
    echo "ERROR: Unknown provider '$PROVIDER'" >&2
    echo "Usage: $0 [terraform|vagrant|docker]" >&2
    exit 1
    ;;
esac

echo ""
echo "Lab is back to its initial state.  Reconnect via SSH."
