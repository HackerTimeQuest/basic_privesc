#!/usr/bin/env bash
# setup.sh — Provision the lab environment
# Supports one back-end: opentofu/azure (default).
#   ./setup.sh                # opentofu apply (Azure)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"
PROVIDER="${1:-opentofu}"
DEFAULT_LOCATIONS=(northeurope westeurope eastus centralus eastus2 southcentralus uksouth francecentral southeastasia japaneast australiaeast)
VM_SIZES=(Standard_B2ats_v2 Standard_B2ts_v2 Standard_B2s Standard_D2s_v3)

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

banner() {
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════╗"
  echo "║  HackerTime — Basic Privilege Esc    ║"
  echo "║  Provisioning backend: $PROVIDER     ║"
  echo "╚══════════════════════════════════════╝"
  echo -e "${RESET}"
}

sku_available() {
  local size="$1"
  local location="$2"

  az vm list-skus --location "$location" --size "$size" \
    --query "[?length(restrictions)==\`0\`].name" -o tsv | grep -qx "$size"
}

select_location_and_size() {
  local selected_location=""
  local selected_size=""

  for size in "${VM_SIZES[@]}"; do
    for loc in "${DEFAULT_LOCATIONS[@]}"; do
      echo -e "${CYAN}[•] Checking ${size} in ${loc}...${RESET}"
      if sku_available "$size" "$loc"; then
        selected_size="$size"
        selected_location="$loc"
        break 2
      fi
    done
  done

  if [ -z "$selected_location" ]; then
    return 1
  fi

  SELECTED_SIZE="$selected_size"
  SELECTED_LOCATION="$selected_location"
  return 0
}

setup_opentofu() {
  echo -e "${YELLOW}[•] Checking for OpenTofu${RESET}"
  if command -v otf &>/dev/null; then
    TF_CMD=otf
  elif command -v terraform &>/dev/null; then
    TF_CMD=terraform
  else
    echo "ERROR: OpenTofu CLI not found. Install from https://opentofu.org/" >&2
    exit 1
  fi

  echo -e "${YELLOW}[•] Checking Azure CLI login${RESET}"
  if ! az account show &>/dev/null; then
    echo "ERROR: Not logged into Azure.  Run 'az login' first." >&2
    exit 1
  fi

  echo -e "${YELLOW}[•] Determining an available Azure region and VM size…${RESET}"

  if ! select_location_and_size; then
    echo "ERROR: No Azure region found with available VM sizes: ${VM_SIZES[*]}." >&2
    exit 1
  fi

  echo -e "${GREEN}[✓] Selected ${SELECTED_SIZE} in ${SELECTED_LOCATION}${RESET}"

  echo -e "${YELLOW}[•] Detecting your public IP for SSH firewall…${RESET}"
  MY_IP=$(curl -s https://checkip.amazonaws.com | tr -d ' \n')
  if [ -z "$MY_IP" ]; then
    echo -e "${YELLOW}[!] Could not auto-detect IP; allowing from anywhere.${RESET}"
    MY_IP="0.0.0.0/0"
  else
    echo -e "${GREEN}[✓] Restricting SSH access to ${MY_IP}/32${RESET}"
    MY_IP="${MY_IP}/32"
  fi

  echo -e "${YELLOW}[•] Initializing and applying OpenTofu…${RESET}"
  cd "$LAB_DIR/infrastructure/terraform"
  "$TF_CMD" init
  "$TF_CMD" apply -auto-approve -var="location=${SELECTED_LOCATION}" -var="vm_size=${SELECTED_SIZE}" -var="allowed_ssh_cidr=${MY_IP}"

  PUBLIC_IP=$("$TF_CMD" output -raw public_ip_address)
  echo -e "${GREEN}[✓] VM is running on Azure.${RESET}"
  echo ""

  echo -e "${YELLOW}[•] Waiting for SSH and configuring guest firewall…${RESET}"
  for i in {1..30}; do
    if timeout 2 ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no appuser@"$PUBLIC_IP" exit 2>/dev/null; then
      echo -e "${GREEN}[✓] SSH is responsive${RESET}"
      if command -v sshpass &>/dev/null; then
        sshpass -p "wareh0use!" ssh -o StrictHostKeyChecking=no appuser@"$PUBLIC_IP" "sudo ufw delete allow 22/tcp 2>/dev/null; sudo ufw allow from ${MY_IP%/32} to any port 22; echo 'Guest firewall updated.'" >/dev/null 2>&1
        echo -e "${GREEN}[✓] Guest firewall configured${RESET}"
      fi
      break
    fi
    [ $i -lt 30 ] && sleep 2
  done

  echo ""
  echo "  SSH in with:"
  echo -e "  ${CYAN}ssh appuser@$PUBLIC_IP${RESET}   (password: wareh0use!)"
  echo ""
  echo "  Security:"
  echo "  - Azure NSG:  restricted to ${MY_IP}"
  echo "  - Guest UFW: restricted to ${MY_IP}"
  echo ""
}

banner
case "$PROVIDER" in
  opentofu|azure) setup_opentofu ;;
  *)
    echo "ERROR: Unknown provider '$PROVIDER'" >&2
    echo "Usage: $0 [opentofu|azure]" >&2
esac

echo -e "${GREEN}Lab is ready.  Read lab.md for the scenario.${RESET}"
