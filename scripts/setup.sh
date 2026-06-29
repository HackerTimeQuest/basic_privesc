#!/usr/bin/env bash
# setup.sh — Provision the lab environment
# Supports three back-ends: terraform/azure (default), vagrant, and docker-compose.
#   ./setup.sh                # terraform apply (Azure)
#   ./setup.sh vagrant        # vagrant up
#   ./setup.sh docker         # docker compose up -d

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"
PROVIDER="${1:-terraform}"

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

setup_terraform() {
  echo -e "${YELLOW}[•] Checking for Terraform${RESET}"
  if ! command -v terraform &>/dev/null; then
    echo "ERROR: terraform not found.  Install from https://www.terraform.io/" >&2
    exit 1
  fi

  echo -e "${YELLOW}[•] Checking Azure CLI login${RESET}"
  if ! az account show &>/dev/null; then
    echo "ERROR: Not logged into Azure.  Run 'az login' first." >&2
    exit 1
  fi

  echo -e "${YELLOW}[•] Initializing and applying Terraform …${RESET}"
  cd "$LAB_DIR/infrastructure/terraform"
  terraform init
  terraform apply -auto-approve

  PUBLIC_IP=$(terraform output -raw public_ip_address)
  echo -e "${GREEN}[✓] VM is running on Azure.${RESET}"
  echo ""
  echo "  SSH in with:"
  echo -e "  ${CYAN}ssh -o StrictHostKeyChecking=no azureuser@$PUBLIC_IP${RESET}   (key-based auth)"
  echo ""
}

setup_vagrant() {
  echo -e "${YELLOW}[•] Checking for Vagrant${RESET}"
  if ! command -v vagrant &>/dev/null; then
    echo "ERROR: vagrant not found.  Install from https://www.vagrantup.com/" >&2
    exit 1
  fi

  echo -e "${YELLOW}[•] Starting VM …${RESET}"
  vagrant up --provision

  echo -e "${GREEN}[✓] VM is running.${RESET}"
  echo ""
  echo "  SSH in with:"
  echo -e "  ${CYAN}ssh appuser@192.168.49.10${RESET}   (password: wareh0use!)"
  echo ""
}

setup_docker() {
  echo -e "${YELLOW}[•] Checking for docker compose${RESET}"
  if ! docker compose version &>/dev/null; then
    echo "ERROR: docker compose not found.  Install Docker Desktop first." >&2
    exit 1
  fi

  # Build image and run provisioner inside container
  docker compose build target
  docker compose up -d target

  CONTAINER_ID=$(docker compose ps -q target)
  echo -e "${GREEN}[✓] Container running as ${CONTAINER_ID}${RESET}"
  echo ""
  echo "  SSH in with:"
  echo -e "  ${CYAN}ssh -p 2222 appuser@localhost${RESET}   (password: wareh0use!)"
  echo ""
}

banner
case "$PROVIDER" in
  terraform|azure) setup_terraform ;;
  vagrant)          setup_vagrant   ;;
  docker)           setup_docker    ;;
  *)
    echo "ERROR: Unknown provider '$PROVIDER'" >&2
    echo "Usage: $0 [terraform|vagrant|docker]" >&2
    exit 1
    ;;
esac

echo -e "${GREEN}Lab is ready.  Read lab.md for the scenario.${RESET}"
